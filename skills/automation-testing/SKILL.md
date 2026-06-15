---
name: automation-testing
description: Prove a non-UI automation actually works — synthetic trigger → assert side effect → assert no error logs — and, when evidence is wanted, film it as a trigger → live-log → surfaced-result walkthrough. Use for server-side, event-triggered behaviour where screenshots prove nothing: webhooks, Microsoft 365 Graph mail/SharePoint/SSO listeners, "acting" webhooks that reply or write, scheduled jobs, agent runs. autothing uses this for automation slices; usable directly to validate or demo any backend automation. Do NOT use for UI-flow testing (use the project's testing skill) or visual design judgement (that is a design-audit / polish-ui skill).
---

# automation-testing

For behaviour that is server-side and event-triggered (Microsoft 365 mail/SharePoint/SSO listeners, "acting" webhooks, scheduled/agent runs). UI screenshots alone do not prove these — assert behaviour. `autothing` invokes this for automation slices (it maps onto the project's `<proj>-testing` step 3 and the `walkthrough` evidence beat); use it directly to validate or film any backend automation.

## Validation pattern
**Synthetic trigger → assert side effect → assert no error logs.** Never depend on a real external event firing during the test.

- **Webhook / Graph change-notification listeners** (e.g. new mail): `POST` a synthetic notification payload to the local endpoint. Handle the Graph **validation-token handshake** (echo `validationToken` on subscription-validation requests). Assert the side effect — the automation run row created, the parsed entity stored, the downstream action attempted.
- **"Acting" webhooks** (listen *and* do something, e.g. send a reply, write a file): **mock the outbound call** (Graph send-mail, SharePoint write) and assert it was invoked with the right arguments. Do not hit the real tenant from a test.
- **SharePoint sync**: trigger the delta sync against a **seeded/synthetic delta**; assert the documents surface in the store + UI list.
- **SSO / connection (Entra / MSAL)**: do not perform interactive auth in tests. Reuse a **stored session/connection** (`.walkthrough/auth.json`) or a seeded token from the test env. Assert the connected/authed state. Never inline tenant secrets; never print tokens.

Assert no server `error`-level logs during the run, the same way UI tests assert no console errors. Commit the trigger + assertions as a re-runnable test (a spec, or a committed driver script where no runner ships) — an ephemeral one-off `curl` is exploration, not the gate.

## Filming the automation (what to pass `walkthrough`)
These map cleanly onto walkthrough's existing segment types — request that flow shape:
1. **Trigger (terminal segment)** — the command that fires the synthetic event (`curl`/script POSTing the payload). Caption: "Simulating an inbound M365 mail notification".
2. **Live log tail (live-log segment)** — tail the running server / job stream (e.g. the `useJobStream` job log) showing the listener fire and act. Caption: "The listener picks it up and creates an automation run".
3. **Surfaced result (browser segment)** — the UI surface where the result appears (the automation-run row, the synced file), with the asserted element highlighted. Caption: "The run appears in the dashboard — verified".

Never put credentials, tokens, or `.env` contents into a terminal/log segment that gets filmed.

## Honesty
If an automation cannot complete (e.g. a sandbox tenant rejects a token), let it render the failure honestly (walkthrough's `expectFailure` → red FAILED beat), flag the run, log the blocker (in an autothing build: `docs/decisions.md`), and continue. A truthfully-shown failure is acceptable evidence; a faked success is not.
