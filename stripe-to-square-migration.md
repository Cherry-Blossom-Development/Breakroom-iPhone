# Stripe → Square Migration — iPhone Side

**Status**: BLOCKED — do not start until the backend migration has shipped
**Blocked on**: `Breakroom/docs/stripe-to-square-migration.md` in the **Breakroom repo**
(Vue frontend + Express backend, not this repo) — specifically its Phase 3 ("Backend:
Storefront checkout + webhooks") needs to be live in production before this app changes
anything, since this app just consumes whatever `platform` value and URLs the backend's
`/api/billing/*` endpoints return. If you're picking this up on a machine that doesn't
have the Breakroom repo checked out, you'll need to check with Dallas on whether that
backend work has actually shipped before starting anything here.

## Background (for a cold read, no prior conversation context)

This is the native SwiftUI iOS app for Prosaurus (the app is branded "Prosaurus" but the
code/package is still named `Breakroom` throughout — see this repo's `CLAUDE.md`). It
shares a backend API (`prosaurus.com/api`) with a Vue web frontend and a native Android
app, all hitting the same Express backend and MariaDB database.

Stripe has turned off payment processing on the account, and after trying to resolve it
directly with Stripe support with no success, the decision was made to migrate all
web-side payment processing to **Square**. This does **not** affect Apple's own
StoreKit / App Store in-app purchase system if this app uses one — this migration is only
about the web-side Stripe integration (Connect payouts for artists/sellers, and the
$3.99/mo Pro subscription billing), which this app accesses only as a thin REST client.

**This app has zero embedded Stripe SDK.** Confirmed by grepping the whole repo
(2026-07-24): no CocoaPods Podfile, no SPM Stripe package (`stripe-ios` or similar) in
`Breakroom.xcodeproj/project.pbxproj` — the only SPM dependencies are `firebase-ios-sdk`
and `socket.io-client-swift`. No hardcoded Stripe publishable key anywhere. This app never
embeds a card entry form or calls Stripe's API directly — it only displays a `platform`
string returned by the backend and opens whatever URL the backend hands back via
`UIApplication.shared.open(...)`. This means the required change here is small and
low-risk: no new SPM dependency, no new SDK integration, no App Store review risk (this
doesn't touch in-app purchase at all).

## Current state — every Stripe reference in this repo

Confirmed via full-repo grep, 2026-07-24 — this is the complete list, not a sample:

1. **`Breakroom/Views/Billing/BillingView.swift`** — the subscription/billing screen.
   - Checks `planPlatform == "stripe"` (string comparison) to decide what the "manage
     subscription" action does
   - Calls `CollectionsAPIService.getBillingPortalUrl()` then opens the returned URL via
     plain `UIApplication.shared.open(portalURL)` (~line 373)
   - Displays static UI copy mentioning "Stripe" and its processing fee in a fee-breakdown
     section (no logic, just text)

2. **`Breakroom/Views/Collections/PaymentSetupView.swift`** — the Connect (seller payout)
   onboarding screen.
   - Tracks `connectStatus` (`"not_connected"` / `"pending"` / `"active"`)
   - Calls `CollectionsAPIService.startConnect()` / `getConnectStatus()`, opens the
     returned onboarding URL via `UIApplication.shared.open(openUrl)`
   - **Hardcoded link**: `https://dashboard.stripe.com/express`, opened the same way, shown
     when status is `"active"`
   - UI copy strings: "Connect with Stripe", "Continue Stripe Setup", etc. — text only, no
     SDK calls

3. **`Breakroom/Services/CollectionsAPIService.swift`** — networking layer, has a section
   commented `// MARK: - Billing / Stripe Connect`. Hits plain REST endpoints:
   `/api/billing/plan`, `/api/billing/connect/status`, `/api/billing/connect/start`,
   `/api/billing/portal-url`. Pure `APIClient.shared.request(...)` calls returning
   URLs/status strings — no Stripe client code, just a comment label.

4. **`Breakroom/Models/CollectionsModels.swift`** — Codable structs parsing generic field
   names, not Stripe-specific ones:
   - `BillingPlan` (`subscribed`, `platform`, `feePercent`/`fee_percent`)
   - `ConnectStatus` (`status`)
   - `ConnectStartResponse` (`url`, `status`)
   - `BillingPortalResponse`
   - No `stripe_account_id` or any Stripe-prefixed key anywhere in this file.

5. **`Breakroom/Views/Collections/CollectionsView.swift`** — one line of UI copy: "Connect
   Stripe to receive payouts" (navigation entry point into `PaymentSetupView`).

## What needs to change (once unblocked)

1. **`BillingView.swift`**: the `planPlatform == "stripe"` check needs a `"square"`
   counterpart (or both, if the backend runs both processors in parallel during
   transition — check the Breakroom repo's migration doc for whether dual-run was the
   chosen cutover strategy). Confirm the actual new `platform` string value with whatever
   the backend ships before writing this — don't guess the exact string.
2. **`PaymentSetupView.swift`**: replace (or branch on platform for) the hardcoded
   `https://dashboard.stripe.com/express` with Square's equivalent seller dashboard URL
   (likely something under `squareup.com/dashboard/` — confirm the exact URL before
   implementing, don't guess).
3. **UI copy** in both files plus `CollectionsView.swift` ("Connect with Stripe",
   "Continue Stripe Setup", "Connect Stripe to receive payouts", the fee-breakdown text
   in `BillingView.swift`): update to reference Square. Check whether Square's actual
   processing fee differs from the currently-quoted Stripe rate (~2.9% + $0.30) — this is
   real text shown to users about their money, get the number right, don't just
   find-replace the word "Stripe" and leave a wrong fee percentage.
4. **`CollectionsModels.swift`**: only touch if the backend actually renames a field.
   Since the current models already use generic names (`platform`, `fee_percent`, not
   Stripe-prefixed keys), this file likely needs **no changes at all** — the backend
   migration doc explicitly designed `user_subscriptions.platform` to be a generic enum
   for exactly this reason (it already serves Apple/Google/Stripe as of this writing).
5. Grep this repo fresh for "stripe" (case-insensitive) again right before starting — do
   not trust this list if significant time has passed or other work has touched these
   files since 2026-07-24.

## How to verify the backend is actually ready

Before starting, confirm against a real (or staging) backend response:
```
GET /api/billing/plan
```
and check whether the `platform` field can return `"square"` yet, and whether
`GET /api/billing/connect/status` / `POST /api/billing/connect/start` return
Square-shaped URLs. This repo has no visibility into the Breakroom repo's progress log —
check with Dallas directly if there's any doubt about backend readiness.

## Progress log

- 2026-07-24: Doc created during a planning session run from the Android repo (this repo
  was inventoried remotely as part of that session, not edited). No code changes made
  here yet. Blocked on backend work in the Breakroom repo.
