---
name: test-artifact
description: Orchestrate browser-based E2E testing for artifacts using the e2e-testing skill
---

# Test Artifact Skill

## Purpose

This skill orchestrates end-to-end (E2E) browser testing for artifacts built by the coding agent. It analyzes the artifact, creates test scenarios, and delegates execution to the "e2e-testing" skill for browser automation.

**IMPORTANT:** This skill uses browser automation (Playwright/Chrome), NOT traditional unit tests. Tests interact with the running application in a real browser.

## When to Use

- **ALWAYS** use this skill when the "Quality Assurance" refinement is enabled
- After the artifact implementation is complete
- After the artifact is running (dev server started)
- When you need to verify user flows work correctly

## Prerequisites

Before using this skill:
1. The artifact must be built and runnable
2. The dev server must be started (e.g., `npm run dev`)
3. You must know the URL where the artifact is running

## Instructions

### Step 1: Ensure the App is Running

1. Start the development server if not already running
2. Confirm the URL where the app is accessible
3. Wait for the app to be ready (health check)

### Step 2: Analyze the Artifact

Examine the built artifact to understand:
- What pages/routes exist?
- What forms need to be tested?
- What user interactions are expected?
- What success states should be verified?

### Step 3: Create Test Scenarios

Create a list of E2E test scenarios covering:

| Category | Examples |
|----------|----------|
| **Navigation** | Page loads, links work, routing correct |
| **Forms** | Input validation, submission, error states |
| **User Flows** | Complete user journeys (e.g., signup -> dashboard) |
| **UI States** | Modals, dropdowns, loading states |
| **Responsive** | Mobile/tablet/desktop layouts |

### Step 4: Invoke e2e-testing Skill

For each test scenario, invoke the "e2e-testing" skill with specific instructions:

Example invocation:
"Use the e2e-testing skill to test the login form:
1. Navigate to /login
2. Enter email: test@example.com
3. Enter password: password123
4. Click the login button
5. Verify redirect to /dashboard
6. Verify welcome message is visible"

### Step 5: Handle Test Failures

If a test fails:
1. Analyze the failure (screenshot, error message)
2. Identify the root cause in the artifact code
3. Fix the artifact code
4. Re-run the failing test
5. Continue until all tests pass or max iterations reached

### Step 6: Report Results

After testing, report:
- Total scenarios tested
- Passed/failed count
- Any remaining issues
- Recommendations for manual testing

## Input Expected

- Running artifact URL (e.g., http://localhost:3001)
- Artifact type and structure
- Max iterations for autofix (from config)

## Output Expected

1. Test scenario list
2. Test execution results
3. Any fixes applied
4. Final test summary

## Iteration Handling

The skill supports multiple autofix iterations:

**Iteration Loop:**
1. Run all test scenarios
2. If any fail, fix the artifact code
3. Increment iteration counter
4. Re-run tests
5. Repeat until all pass OR max iterations reached

**Progress Reporting:**
Report each iteration: "Testing Phase - Iteration X/Y - Running tests..."

**Exit Conditions:**
- All tests pass -> Success
- Max iterations reached with failures -> Report remaining issues
- Critical error (app crash) -> Stop and report

## Test Scenario Templates

### Landing Page Tests
- Hero section loads correctly
- Navigation links work
- CTA buttons are clickable
- Footer links are present
- Mobile menu works on small screens

### Form Tests
- Empty form shows validation errors
- Valid input is accepted
- Invalid input shows specific errors
- Form submission works
- Success/error states display correctly

### Dashboard Tests
- Dashboard loads with data
- Charts render correctly
- Filters update the view
- Data table pagination works
- Export functionality works

### Authentication Tests
- Login form validates input
- Successful login redirects correctly
- Logout clears session
- Protected routes redirect to login
- Remember me works

## Examples

### Example 1: Testing a Contact Form

"Use the e2e-testing skill to verify the contact form:

Scenario 1 - Empty Submission:
1. Navigate to /contact
2. Click submit without filling fields
3. Verify validation errors appear for name, email, message

Scenario 2 - Invalid Email:
1. Fill name: John Doe
2. Fill email: invalid-email
3. Fill message: Test message
4. Click submit
5. Verify email validation error

Scenario 3 - Successful Submission:
1. Fill name: John Doe
2. Fill email: john@example.com
3. Fill message: This is a test message
4. Click submit
5. Verify success message appears
6. Verify form is cleared"

### Example 2: Testing Navigation

"Use the e2e-testing skill to verify navigation:

Scenario 1 - Main Navigation:
1. Navigate to homepage
2. Click 'About' link
3. Verify URL is /about
4. Verify About page content loads

Scenario 2 - Mobile Navigation:
1. Set viewport to mobile (375x667)
2. Navigate to homepage
3. Click hamburger menu
4. Verify mobile menu opens
5. Click 'Contact' link
6. Verify navigation to /contact"

## Important Notes

- Always wait for elements before interacting
- Use realistic test data
- Test both happy path and error cases
- Screenshots help diagnose failures
- Don't test external services (mock them)
- Focus on user-visible behavior, not implementation details
