/**
 * E2E Test Runner Helper Script
 *
 * This script provides Playwright-based browser strategies as a secondary option.
 * The primary tool for web app E2E testing is agent-browser CLI.
 *
 * Usage:
 *   npx tsx run_e2e_test.ts --url http://localhost:3000 --action "click Login"
 *
 * Strategies:
 *   1. Chrome debug mode (connect via CDP if running)
 *   2. Chromium persistent context
 *
 * If all strategies fail, use agent-browser CLI directly.
 */

import { chromium, type BrowserContext, type Page } from 'playwright';
import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs';

const E2E_DIR = path.join(os.homedir(), '.e2e-testing');

interface BrowserResult {
  strategy: string;
  context: BrowserContext;
  page: Page;
  cleanup: () => Promise<void>;
}

/**
 * Strategy 3: Connect to Chrome running in debug mode
 */
async function tryChromeCDP(): Promise<BrowserResult | null> {
  try {
    console.log('Trying Strategy 3: Chrome Debug Mode (CDP)...');

    // Check if Chrome debug port is available
    const response = await fetch('http://localhost:9222/json/version').catch(() => null);
    if (!response) {
      console.log('  Chrome debug mode not available');
      return null;
    }

    const browser = await chromium.connectOverCDP('http://localhost:9222');
    const contexts = browser.contexts();

    if (contexts.length === 0) {
      console.log('  No browser contexts available');
      await browser.close();
      return null;
    }

    const context = contexts[0];
    const pages = context.pages();
    const page = pages[0] || await context.newPage();

    console.log('  Connected to Chrome debug mode');

    return {
      strategy: 'chrome-cdp',
      context,
      page,
      cleanup: async () => {
        // Don't close the browser when connected via CDP, just disconnect
        await browser.close();
      }
    };
  } catch (error) {
    console.log(`  Failed: ${(error as Error).message}`);
    return null;
  }
}

/**
 * Strategy 4: Launch Chromium with persistent context
 */
async function tryChromiumPersistent(): Promise<BrowserResult | null> {
  try {
    console.log('Trying Strategy 4: Chromium Persistent Context...');

    const userDataDir = path.join(E2E_DIR, 'chromium-profile');

    // Ensure directory exists
    fs.mkdirSync(userDataDir, { recursive: true });

    const context = await chromium.launchPersistentContext(userDataDir, {
      headless: false,
      slowMo: 100,
      viewport: { width: 1280, height: 720 },
      args: [
        '--disable-blink-features=AutomationControlled',
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-infobars',
        '--disable-dev-shm-usage'
      ]
    });

    const pages = context.pages();
    const page = pages[0] || await context.newPage();

    console.log('  Launched Chromium with persistent context');

    return {
      strategy: 'chromium-persistent',
      context,
      page,
      cleanup: async () => {
        await context.close();
      }
    };
  } catch (error) {
    console.log(`  Failed: ${(error as Error).message}`);
    return null;
  }
}

/**
 * Get browser using fallback strategy (Strategies 3-4)
 *
 * NOTE: agent-browser CLI is the primary tool for web app E2E testing.
 * This script is a secondary option. If this script fails, use
 * agent-browser CLI directly.
 */
export async function getBrowser(): Promise<BrowserResult> {
  console.log('=== E2E Testing: Playwright Strategies ===\n');
  console.log('Note: agent-browser CLI is the primary tool. This is a secondary option.\n');

  let result: BrowserResult | null;

  // Strategy 3: Chrome CDP
  result = await tryChromeCDP();
  if (result) return result;

  // Strategy 4: Chromium persistent
  result = await tryChromiumPersistent();
  if (result) return result;

  console.log('\n=== All Playwright strategies failed ===');
  console.log('Final fallback: Use the agent-browser skill directly.\n');
  console.log('Example commands:');
  console.log('  agent-browser open <url>');
  console.log('  agent-browser snapshot -i');
  console.log('  agent-browser click @e1');
  console.log('  agent-browser fill @e2 "text"');
  console.log('  agent-browser screenshot result.png\n');

  throw new Error(
    'Playwright strategies failed. Use agent-browser skill as final fallback. ' +
    'See the agent-browser skill for complete CLI reference.'
  );
}

/**
 * Run a simple test
 */
async function runSimpleTest(url: string, action?: string) {
  const { strategy, page, cleanup } = await getBrowser();

  console.log(`\nUsing strategy: ${strategy}`);
  console.log(`Navigating to: ${url}\n`);

  try {
    await page.goto(url, { waitUntil: 'networkidle' });
    console.log(`Page title: ${await page.title()}`);

    if (action) {
      console.log(`\nPerforming action: ${action}`);
      // Simple action parsing
      if (action.startsWith('click ')) {
        const selector = action.substring(6);
        await page.click(`text=${selector}`);
        console.log(`Clicked: ${selector}`);
      } else if (action.startsWith('type ')) {
        const [, selector, ...textParts] = action.split(' ');
        const text = textParts.join(' ');
        await page.fill(selector, text);
        console.log(`Typed "${text}" into ${selector}`);
      }
    }

    // Take screenshot
    const screenshotPath = path.join(process.cwd(), 'e2e-test-result.png');
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`\nScreenshot saved: ${screenshotPath}`);

  } finally {
    await cleanup();
  }
}

// CLI interface
const args = process.argv.slice(2);

if (args.includes('--help') || args.length === 0) {
  console.log(`
E2E Test Runner Helper Script

This script provides Playwright-based browser strategies.
The primary tool for web app E2E testing is agent-browser CLI.

Usage:
  npx tsx run_e2e_test.ts --url <URL> [--action <ACTION>]

Options:
  --url <URL>       URL to navigate to
  --action <ACTION> Action to perform (e.g., "click Login", "type #email test@example.com")
  --help            Show this help message

Examples:
  npx tsx run_e2e_test.ts --url http://localhost:3000
  npx tsx run_e2e_test.ts --url http://localhost:3000 --action "click Sign In"

Strategy Order:
  Primary: agent-browser CLI (preferred for all web app testing)
  1. Chrome Debug Mode (CDP) - this script
  2. Chromium Persistent Context - this script

If this script fails, use agent-browser CLI directly.
`);
  process.exit(0);
}

// Parse CLI args
let url = '';
let action = '';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--url' && args[i + 1]) {
    url = args[i + 1];
    i++;
  } else if (args[i] === '--action' && args[i + 1]) {
    action = args[i + 1];
    i++;
  }
}

if (url) {
  runSimpleTest(url, action).catch(console.error);
} else {
  console.error('Error: --url is required');
  process.exit(1);
}
