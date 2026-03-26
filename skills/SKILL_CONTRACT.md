# Skill Contract Format

This document defines the standard format for Ekoa OS skills. Both local (Qwen) and external (Claude) agents follow this format for deterministic skill execution.

## Skill Types

### 1. Standard Skills
Simple tool wrappers (weather, search, etc.)

### 2. Integration Skills
External service connectors with setup wizards (Google Analytics, Slack, etc.)

## Skill Structure

Each skill is a folder containing:

```
skill-name/
├── SKILL.md          # Main skill definition (required)
├── examples/         # Example inputs/outputs (optional)
│   ├── example1.md
│   └── example2.md
└── assets/           # Supporting files (optional)
```

### Integration Skill Structure (Extended)

```
integration-name/
├── SKILL.md              # Main definition with config detection
├── setup.md              # Step-by-step setup wizard
├── config.schema.json    # JSON Schema for config file
└── queries/              # Query templates (optional)
    ├── query1.md
    └── query2.md
```

**Config storage:** `~/.ekoa/integrations/[service-name].json`

## SKILL.md Format

```markdown
# Skill Name

Brief description of what the skill does.

## Purpose
One paragraph explaining the skill's purpose and when to use it.

## Invocation
Description of when this skill should be triggered.

### Trigger Patterns
- Pattern 1
- Pattern 2
- Pattern 3

## How to Use

### Tool Call Pattern
```
tool: [tool_name]
[parameters]
```

### Response Format
Description of expected response structure.

### Example

**User:** [example input]

**Skill Execution:**
1. Step 1
2. Step 2
3. Step 3

**Response:** 
[example output]

## Notes
Any additional notes, limitations, or tips.
```

## Skill Discovery

Agents discover skills by:
1. Reading `~/.claude/skills/` directory
2. Loading each `SKILL.md` file
3. Matching user intent against trigger patterns
4. Executing the skill's tool call pattern

## Skill Invocation Protocol

When a skill is invoked via WebSocket, emit:

```json
{
  "type": "skill_invocation",
  "payload": {
    "skill": "skill-name",
    "trigger": "matched pattern",
    "timestamp": "ISO8601"
  }
}
```

After execution, emit:

```json
{
  "type": "skill_complete",
  "payload": {
    "skill": "skill-name",
    "success": true,
    "duration_ms": 1234,
    "tools_used": ["tool1", "tool2"]
  }
}
```

## Creating New Skills

Use the Skill Builder chat panel or create files directly following this format.

---

## Integration Skill Pattern

Integration skills connect to external APIs (Google Analytics, Slack, GitHub, etc.).

### Key Differences from Standard Skills

1. **Config detection** - Check if already set up before executing
2. **Setup wizard** - Guide users through auth/credentials
3. **Persistent config** - Store credentials in `~/.ekoa/integrations/`
4. **Query templates** - Pre-built API request patterns

### SKILL.md Template for Integrations

```markdown
# Service Name Integration

Brief description.

## Configuration Detection

**Config file:** `~/.ekoa/integrations/service-name.json`

### Pre-flight Check
\`\`\`bash
jq -r '.configured // false' ~/.ekoa/integrations/service-name.json 2>/dev/null
\`\`\`

### Decision Tree
- Config exists + configured=true → Execute query
- Otherwise → Trigger setup.md wizard

## Trigger Patterns
- "setup/configure [service]"
- "[service-specific queries]"

## Query Routing
| Intent | Template |
|--------|----------|
| Query type 1 | queries/query1.md |
| Query type 2 | queries/query2.md |
```

### setup.md Template

```markdown
# Service Setup Wizard

## Prerequisites
- [ ] Account on service
- [ ] API access enabled

## Step 1: Get Credentials
Instructions...

## Step 2: Configure Ekoa
Create `~/.ekoa/integrations/service-name.json`:
\`\`\`json
{
  "configured": true,
  "credentials": {...}
}
\`\`\`

## Verify
Test command to confirm setup works.
```

### Query Template Format

```markdown
# Query Name

## Description
What this query does.

## Parameters
| Parameter | Type | Default | Description |

## API Request
\`\`\`json
{...}
\`\`\`

## Implementation
Python/curl code.

## Human-Friendly Output
How to format for chat/voice.
```

### Example Integration Skills

- `google-analytics/` - Full implementation with 4 query types
- More examples in `~/.ekoa/integrations/README.md`

### Tier Routing for Integrations

| Task | Tier | Notes |
|------|------|-------|
| Check if configured | IMMEDIATE | Simple file check |
| Setup wizard | COMPLEX | Needs conversation |
| Execute queries | COMPLEX | API calls + formatting |
