#!/usr/bin/env node
/**
 * ct Channel Server
 *
 * MCP channel server that bridges ct workspace peer sessions.
 * Protocol:
 *   - stdio: MCP connection to Claude Code (spawned as subprocess)
 *   - HTTP :CT_CHANNEL_PORT: receives /message POSTs from peers, serves /health
 *   - Outbound: fetch() to http://127.0.0.1:<peer_port>/message
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import http from "node:http";

const CT_AGENT = process.env.CT_AGENT || "unknown";
const CT_PROJECT = process.env.CT_PROJECT || "unknown";
const CT_CHANNEL_PORT = parseInt(process.env.CT_CHANNEL_PORT || "8788", 10);
const CT_PEERS = JSON.parse(process.env.CT_PEERS || "{}");
const SERVER_NAME = `ct-${CT_PROJECT}-${CT_AGENT}`;
const AGENTS = ["pericles", "spartacus", "maximus", "argus"];

const mcp = new Server(
  { name: SERVER_NAME, version: "0.1.0" },
  {
    capabilities: {
      experimental: { "claude/channel": {} },
      tools: {},
    },
    instructions: `You are running in a ct multi-session workspace. You can send messages to peer sessions using the send_to tool. Peers: ${AGENTS.join(", ")}.`,
  }
);

mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "send_to",
      description: "Send a message to another ct session.",
      inputSchema: {
        type: "object",
        properties: {
          target: {
            type: "string",
            enum: AGENTS,
            description: "Recipient agent.",
          },
          text: {
            type: "string",
            description: "Message body (plain text or markdown)",
          },
          urgent: {
            type: "boolean",
            description: "If true, interrupt target immediately (optional)",
          },
        },
        required: ["target", "text"],
      },
    },
  ],
}));

mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name === "send_to") {
    const { target, text, urgent } = req.params.arguments;

    const targetPort = CT_PEERS[target];
    if (!targetPort) {
      return {
        content: [
          {
            type: "text",
            text: `Unknown target: ${target}. Available peers: ${Object.keys(CT_PEERS).join(", ")}`,
          },
        ],
      };
    }

    try {
      const resp = await fetch(`http://127.0.0.1:${targetPort}/message`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ from: CT_AGENT, text, urgent: urgent ?? false }),
        signal: AbortSignal.timeout(5000),
      });
      if (!resp.ok) {
        throw new Error(`peer returned HTTP ${resp.status}`);
      }
      console.error(
        `[${SERVER_NAME}] Message sent to ${target}:${targetPort}, ${text.length} chars`
      );
      return { content: [{ type: "text", text: `sent to ${target}` }] };
    } catch (e) {
      const msg = e.cause?.message ?? e.message;
      console.error(`[${SERVER_NAME}] Failed to send to ${target}: ${msg}`);
      return {
        content: [
          { type: "text", text: `Send failed (${target} unreachable): ${msg}` },
        ],
      };
    }
  }

  throw new Error(`Unknown tool: ${req.params.name}`);
});

await mcp.connect(new StdioServerTransport());
console.error(
  `[${SERVER_NAME}] MCP connected, starting HTTP server on :${CT_CHANNEL_PORT}`
);

const httpServer = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${CT_CHANNEL_PORT}`);

  if (url.pathname === "/health" && req.method === "GET") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", server: SERVER_NAME }));
    return;
  }

  if (url.pathname === "/message" && req.method === "POST") {
    try {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      const body = JSON.parse(Buffer.concat(chunks).toString());

      if (!body.text) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "No text provided" }));
        return;
      }

      const content = `<channel source="ct" from="${body.from}" ts="${new Date().toISOString()}">\n${body.text}\n</channel>`;

      await mcp.notification({
        method: "notifications/claude/channel",
        params: { content, meta: { from: body.from } },
      });

      console.error(
        `[${SERVER_NAME}] Message pushed: from=${body.from}, ${content.length} chars`
      );

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ ok: true }));
      return;
    } catch (e) {
      console.error(`[${SERVER_NAME}] Error processing message: ${e.message}`);
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: e.message }));
      return;
    }
  }

  res.writeHead(200);
  res.end("ct Channel Server");
});

httpServer.listen(CT_CHANNEL_PORT, "127.0.0.1", () => {
  console.error(
    `[${SERVER_NAME}] HTTP server listening on http://127.0.0.1:${CT_CHANNEL_PORT}`
  );
});
