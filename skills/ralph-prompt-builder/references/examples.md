# Complete Examples

Real-world examples of ralph-loop prompts using the e2e-testing skill for verification.

---

## Sidebar Scrolling Fix (5 iterations)

```
/ralph-loop:ralph-loop "ultrathink Fix sidebar navigation scrolling on smaller screens. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Sidebar navigation shows logo at top, menu icons for Orchestration, Examples, Agents, Platform, Branding, Users, Artifacts, Integrations, Resources, Tunnel, and user avatar at bottom. On smaller viewport heights, bottom items are cut off with no scrolling. REQUIREMENTS: 1) Add vertical scrolling to sidebar nav area, 2) Hide scrollbar visually with CSS using webkit-scrollbar hidden or scrollbar-width none, 3) Keep logo fixed at top, 4) Only modify sidebar component. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to app, 2) Resize viewport to 500-600px height, 3) Scroll sidebar and verify all items accessible including Tunnel and avatar at bottom, 4) Verify no visible scrollbar, 5) Take screenshot confirming scrolling works. Output <promise>SIDEBAR_SCROLL_FIXED</promise> ONLY after e2e tests confirm the fix works." --max-iterations 5 --completion-promise "SIDEBAR_SCROLL_FIXED"
```

---

## Simple Button Fix (5 iterations)

```
/ralph-loop:ralph-loop "ultrathink FIX BUTTON NOT RESPONDING. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: On the settings page at /settings, there is a Save button with label Guardar in the top right. When user clicks the button, nothing happens - no loading state, no success message, no error. The button has cyan/teal styling. Console shows no errors. ISSUE: Button click handler is not connected or not working. FIX: 1) Find the Save button component in the settings page, 2) Check onClick handler exists and is properly bound, 3) Ensure the save function is called and shows feedback. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to /settings, 2) Make a change to any setting, 3) Click Guardar button, 4) VERIFY button shows loading state, 5) VERIFY success message appears or data is saved, 6) Take screenshot to confirm. Output <promise>SAVE_BUTTON_FIXED</promise> ONLY after e2e tests confirm the fix works." --max-iterations 5 --completion-promise "SAVE_BUTTON_FIXED"
```

---

## Dark Mode Feature (6 iterations)

```
/ralph-loop:ralph-loop "ultrathink FEATURE: Add dark mode toggle. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Users need light/dark theme switching. Currently app only has light mode. REQUIREMENTS: 1) Add toggle to Settings page, 2) Implement theme context with localStorage persistence, 3) Update Tailwind config for dark mode, 4) Apply dark: variants to main layout components, 5) Ensure toggle reflects correct state on page load. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to settings, 2) Click dark mode toggle, 3) VERIFY dark theme applies to page, 4) Refresh page, 5) VERIFY dark mode persists after refresh, 6) Take screenshots showing both themes. Output <promise>DARK_MODE_WORKING</promise> ONLY after e2e tests confirm the feature works." --max-iterations 6 --completion-promise "DARK_MODE_WORKING"
```

---

## Login Page with Tests (10 iterations)

```
/ralph-loop:ralph-loop "ultrathink BUILD LOGIN PAGE. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Need to create a login page for the application. Currently no login page exists. REQUIREMENTS: 1) Create login page at /login with email and password fields, 2) Add form validation, 3) Connect to auth API, 4) Redirect to dashboard on success, 5) Show error message on failure. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to /login, 2) VERIFY form fields exist with proper labels, 3) Submit with empty fields and VERIFY validation errors shown, 4) Submit with invalid credentials and VERIFY error message shown, 5) Submit with valid credentials and VERIFY redirect to dashboard, 6) Take screenshots of each state. Output <promise>LOGIN_PAGE_COMPLETE</promise> ONLY after e2e tests confirm all scenarios work." --max-iterations 10 --completion-promise "LOGIN_PAGE_COMPLETE"
```

---

## Multi-Issue Build Page Fix (12 iterations)

```
/ralph-loop:ralph-loop "ultrathink FIX MULTIPLE BUILD PAGE ISSUES. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: On Build page at /build, multiple problems exist. ISSUE 1: Configuration section shows BEFORE user sends first message - should be hidden until after. ISSUE 2: All config sections open simultaneously - should be sequential. ISSUE 3: Duplicate headers in integrations section. REQUIREMENTS: 1) Hide config sections on initial load, 2) Show config only AFTER first message, 3) Make flow sequential, 4) Remove duplicate headers, 5) Add step indicators. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to /build, 2) VERIFY config sections hidden initially, 3) Type message and send, 4) VERIFY config appears sequentially, 5) VERIFY no duplicate headers, 6) VERIFY step indicators visible, 7) Take screenshots at each step. Output <promise>BUILD_PAGE_FIXED</promise> ONLY after e2e tests confirm all issues are fixed." --max-iterations 12 --completion-promise "BUILD_PAGE_FIXED"
```

---

## Mobile Responsiveness Fix (8 iterations)

```
/ralph-loop:ralph-loop "ultrathink FIX MOBILE LAYOUT ISSUES. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: On mobile viewport at /dashboard, the sidebar overlaps main content, buttons are too small to tap, and text is cut off. Desktop layout works correctly. REQUIREMENTS: 1) Make sidebar collapsible on mobile, 2) Increase button touch targets to 44px minimum, 3) Fix text overflow with proper truncation, 4) Add hamburger menu for navigation. CONSTRAINTS: Must not break desktop layout. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to /dashboard, 2) Resize viewport to mobile (375x667), 3) VERIFY sidebar does not overlap content, 4) VERIFY buttons are tappable size, 5) VERIFY text not cut off, 6) Resize to desktop (1280x720), 7) VERIFY desktop layout still correct, 8) Take screenshots at both sizes. Output <promise>MOBILE_RESPONSIVE_FIXED</promise> ONLY after e2e tests confirm both mobile and desktop work." --max-iterations 8 --completion-promise "MOBILE_RESPONSIVE_FIXED"
```

---

## API Endpoint Addition (7 iterations)

```
/ralph-loop:ralph-loop "ultrathink FEATURE: Add user profile API endpoint. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Need GET and PUT endpoints for user profile data. Currently no profile endpoints exist. REQUIREMENTS: 1) Create GET /api/user/profile endpoint returning user data, 2) Create PUT /api/user/profile endpoint for updates, 3) Add validation for profile fields, 4) Connect frontend profile page to new endpoints, 5) Handle loading and error states in UI. VERIFICATION: FIRST check .env for UI_PORT and API_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to profile page, 2) VERIFY profile data loads from API, 3) Make a change and save, 4) VERIFY change persists after refresh, 5) VERIFY error handling works when API fails, 6) Take screenshots showing success and error states. Output <promise>PROFILE_API_COMPLETE</promise> ONLY after e2e tests confirm the feature works." --max-iterations 7 --completion-promise "PROFILE_API_COMPLETE"
```

---

## Form Validation Fix (4 iterations)

```
/ralph-loop:ralph-loop "ultrathink BUG FIX: Form submits with invalid data. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: On the registration form at /register, user can submit form with empty required fields and invalid email format. No validation errors shown. Form fields: name, email, password, confirm password. ISSUE: Client-side validation missing or not working. FIX: 1) Add required field validation, 2) Add email format validation, 3) Add password match validation, 4) Show error messages below each field. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to /register, 2) Click submit with empty fields, 3) VERIFY error messages appear for required fields, 4) Enter invalid email and submit, 5) VERIFY email format error shown, 6) Enter mismatched passwords, 7) VERIFY password mismatch error shown, 8) Take screenshot showing validation errors. Output <promise>FORM_VALIDATION_FIXED</promise> ONLY after e2e tests confirm all validations work." --max-iterations 4 --completion-promise "FORM_VALIDATION_FIXED"
```

---

## Refactoring Example (10 iterations)

```
/ralph-loop:ralph-loop "ultrathink REFACTOR: Extract shared components. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: Multiple pages have duplicate button, card, and modal components with slight variations. Code is hard to maintain. Pages affected: Dashboard, Settings, Profile. GOALS: 1) Create shared Button component with variants, 2) Create shared Card component, 3) Create shared Modal component, 4) Replace duplicates across all three pages, 5) Ensure consistent styling. CONSTRAINTS: Must not change any existing functionality or visual appearance. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to Dashboard, 2) VERIFY all buttons and cards look identical to before, 3) Navigate to Settings, 4) VERIFY all buttons and cards look identical to before, 5) Navigate to Profile, 6) VERIFY all buttons and cards look identical to before, 7) Test a modal on each page, 8) VERIFY modals work correctly, 9) Take screenshots of each page. Output <promise>REFACTOR_COMPLETE</promise> ONLY after e2e tests confirm no visual changes on all pages." --max-iterations 10 --completion-promise "REFACTOR_COMPLETE"
```

---

## Integration Error Fix (6 iterations)

```
/ralph-loop:ralph-loop "ultrathink BUG FIX: Integration error card not actionable. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: On the Chat page at /chat, when integration errors occur, an error card appears with coral/red background showing title Erro na Integracao, error details section, suggestions section, and a Transferir Logs button at the bottom. ISSUE: The Transferir Logs button does not work when clicked - no response, no download, no error. FIX: 1) Find the error card component, 2) Check button onClick handler, 3) Implement log transfer functionality, 4) Add loading state to button, 5) Show success or error feedback after transfer. VERIFICATION: FIRST check .env for UI_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify on the correct port: 1) Navigate to /chat, 2) Trigger an integration error, 3) VERIFY error card appears, 4) Click Transferir Logs button, 5) VERIFY button shows loading state, 6) VERIFY logs are transferred or appropriate feedback shown, 7) Take screenshot showing the working button. Output <promise>LOG_TRANSFER_FIXED</promise> ONLY after e2e tests confirm the button works." --max-iterations 6 --completion-promise "LOG_TRANSFER_FIXED"
```

---

## Critical Port Protection Fix (5 iterations)

```
/ralph-loop:ralph-loop "ultrathink CRITICAL BUG: Port guardrails incomplete. PLAN FIRST then AUTO-ACCEPT and implement without waiting for confirmation. CONTEXT: RESERVED_PORTS is hardcoded but actual ports are in .env. User apps deploying on reserved ports causing conflicts. ISSUE: allocatePort function does not read UI_PORT and API_PORT from .env file. FIX: 1) Modify allocatePort to read UI_PORT and API_PORT from .env, 2) Add these to reserved ports dynamically, 3) Keep hardcoded defaults as fallback, 4) Add logging for reserved ports. VERIFICATION: FIRST check .env for UI_PORT and API_PORT. After implementation, use the e2e-testing skill from ~/.claude/skills/e2e-testing to verify: 1) Navigate to project creation page, 2) Create a new project, 3) Deploy it, 4) VERIFY deployed app does NOT use port matching UI_PORT or API_PORT from .env, 5) Take screenshot showing the deployed app on a different port. Output <promise>ENV_PORTS_PROTECTED</promise> ONLY after e2e tests confirm port protection works." --max-iterations 5 --completion-promise "ENV_PORTS_PROTECTED"
```
