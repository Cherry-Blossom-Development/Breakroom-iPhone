# Alternate Email — iPhone Side

**Status**: NOT STARTED — planning doc only, written on Windows without Xcode/a
simulator available. Intentionally left for implementation on the Mac so it can be
properly built and tested on-device/in-simulator.
**Backend**: Already fully built and deployed to production. No backend work needed —
this is purely an iOS client feature consuming already-live endpoints.
**Companion features already shipped elsewhere**: Web (`Breakroom` repo,
`frontend/src/views/profile/ProfileSettings.vue` + `VerifyAlternateEmailPage.vue`) and
Android (`Android` repo, `SettingsScreen.kt`'s `AlternateEmailCard`) — both live in
production. This app is the last of the three to get it.

## Background (for a cold read, no prior conversation context)

This is the native SwiftUI iOS app for Prosaurus (branded "Prosaurus", code/package
still named `Breakroom` — see this repo's `CLAUDE.md`). It shares a backend API
(`prosaurus.com/api`) with a Vue web frontend and a native Android app, all hitting the
same Express backend and MariaDB database.

**The feature**: users can add a second ("alternate") email address to their account.
A user-entered address must be confirmed via an emailed link before it's used (prevents
someone typing in a stranger's address and having them start receiving mail without
consent). Once confirmed, a per-user toggle controls whether eligible account notices
(currently: band invites, storefront seller emails, Pro-upgrade emails — deliberately
*not* signup verification or password reset, which stay primary-email-only for
security) also get delivered to that address. This exists because many users sign up
with a throwaway email and don't see important notices — the account owner often has
the person's real address separately and wants notices to reach it too.

## Already-live backend endpoints (nothing to build server-side)

- `GET /api/user/alternate-email` → `{alternate_email, alternate_email_verified, send_notices_to_alternate_email}`
- `PUT /api/user/alternate-email` body `{alternate_email}` → sets it unverified and
  sends a confirmation email; empty string clears it entirely; `409` if the address
  collides with another account's handle/email/alternate email; `400` on invalid format
- `POST /api/user/alternate-email/resend` → resends the confirmation email; `400` if
  nothing pending or already verified
- `POST /api/user/alternate-email/confirm` body `{token}` — **no auth header required**,
  the token itself is the credential (a user could click the link on a different
  device/session than the one that set it)
- `PUT /api/user/alternate-email/notify` body `{enabled}` → toggles delivery; `400` if
  not yet verified (can't turn it on before confirming)

All five already work in production today — verify against a real account if useful,
but no backend changes are needed to build the iOS side.

## Key finding that shapes the design: no deep link infrastructure exists

Checked `Breakroom/Breakroom.entitlements` (2026-08-07) — only `aps-environment` (push
notifications) is declared. No `com.apple.developer.associated-domains` entitlement, no
`onOpenURL`/Universal Links handling anywhere in the codebase (grepped the whole repo).
**This app cannot currently open `https://prosaurus.com/...` links in-app at all** —
they open in Safari like any other link, and confirmation happens on the *web* page
(`VerifyAlternateEmailPage.vue`, already live), not in this app.

Android has this exact same gap (confirmed while porting this feature there — even its
*existing* primary-email verification link has no deep link handling, it's dead code).
**Recommendation: don't build Associated Domains/Universal Links support just for this
feature.** It would be new infrastructure this app has nowhere else, inconsistent with
how primary-email verification already works (or rather, doesn't work, in-app), and out
of scope for what was asked. Instead: the app's job is to (a) let the user trigger the
confirmation email, and (b) refresh its own state when the user returns to the app
after clicking the link in their email/Safari — there's already a proven pattern for
this in the codebase (below).

## Suggested implementation

Mirror the shape of the existing notification-settings feature in
`Views/Settings/SettingsView.swift`, and reuse the refresh-on-foreground pattern already
established in the freshest similar addition, `Views/Collections/PaymentSetupView.swift`
(`@Environment(\.scenePhase)` + `.onChange(of: scenePhase)`, `PaymentSetupView.swift:20,70`
— refreshes Connect status when the user returns from Safari/Square's site; do the exact
same thing here for alternate-email verification status).

**1. Model** — add to `Models/SettingsModels.swift`, right alongside `NotificationSettings`
(`SettingsModels.swift:5-29`), matching its exact `Codable` + explicit `CodingKeys`
convention (confirmed: this app does NOT use a global `.convertFromSnakeCase` decoder
strategy, every model spells out its own snake_case mapping explicitly):
```swift
struct AlternateEmailResponse: Codable {
    let alternateEmail: String?
    let alternateEmailVerified: Bool
    let sendNoticesToAlternateEmail: Bool

    enum CodingKeys: String, CodingKey {
        case alternateEmail = "alternate_email"
        case alternateEmailVerified = "alternate_email_verified"
        case sendNoticesToAlternateEmail = "send_notices_to_alternate_email"
    }
}
```

**2. `ProfileAPIService.swift`** — add four static async functions alongside
`getNotificationSettings()`/`saveNotificationSettings()` (`ProfileAPIService.swift:104-114`):
```swift
static func getAlternateEmail() async throws -> AlternateEmailResponse {
    try await APIClient.shared.request("/api/user/alternate-email")
}
static func setAlternateEmail(_ email: String) async throws {
    try await APIClient.shared.requestVoid("/api/user/alternate-email", method: "PUT", body: ["alternate_email": email])
}
static func resendAlternateEmailVerification() async throws {
    try await APIClient.shared.requestVoid("/api/user/alternate-email/resend", method: "POST")
}
static func setAlternateEmailNotify(_ enabled: Bool) async throws {
    try await APIClient.shared.requestVoid("/api/user/alternate-email/notify", method: "PUT", body: ["enabled": enabled])
}
```
`PUT`/`POST` methods here need to actually reach the backend — see the bug note below
about what's currently on this screen.

**3. `SettingsView.swift`** — add `@State` vars (`alternateEmail: String?`,
`alternateEmailVerified: Bool`, `sendNoticesToAlternateEmail: Bool`,
`alternateEmailInput: String`, `isEditingAlternateEmail: Bool`, plus loading/error
state per action — same shape as the existing `notificationsEnabled` etc. vars at
`SettingsView.swift:11-12`), a new section between the Notifications section and the
Account Deletion section with three states matching web/Android's UX exactly:
- Not set / editing → `TextField` + "Send Verification Email" button.
- Set, unverified → address text + "check your inbox" copy + Resend / Change / Remove
  buttons.
- Verified → address text + a `Toggle` (reuse the existing `notificationToggle(title:isOn:)`
  helper at `SettingsView.swift:87` for visual consistency) labeled "Also send notices
  to this address" + Change / Remove buttons.
- Add `.onChange(of: scenePhase)` (mirroring `PaymentSetupView.swift:70`) to reload
  alternate-email status when the app returns to foreground.

**Not in scope**: no admin-side UI. iPhone's admin surface is impersonation only
(`Views/Admin/`), matching Android — admin/back-office tools are staying web-only by
design, not a gap.

## ⚠️ Pre-existing bug found while researching this (unrelated to alternate email, but in the same file — worth fixing while in there)

`ProfileAPIService.swift:104-123`'s existing notification-settings and account-deletion
calls hit **wrong paths that don't exist on the backend**:
- `getNotificationSettings()`/`saveNotificationSettings()` call
  `/api/profile/notification-settings` — the real route is
  `/api/user/notification-settings` (`Breakroom/backend/routes/user.js:557-591`, mounted
  at `/api/user`). Wrong prefix (`profile` vs `user`).
- `requestAccountDeletion()` calls `/api/profile/request-deletion` — the real route is
  `/api/profile/deletion-request` (`Breakroom/backend/routes/profile.js:584`, mounted at
  `/api/profile`). Words are swapped.

Both are confirmed absent from the backend (grepped `backend/routes/*.js` directly).
Practical effect: on iPhone today, the notification toggles in Settings silently fall
back to defaults on load (`SettingsView.swift:206`'s `catch` comment: "Use defaults if
settings don't exist yet") and silently fail to save, and account deletion requests
likely 404. Since this doc's new alternate-email feature lives in the exact same file
and area, worth fixing these two paths in the same pass rather than as a separate trip
back into this file later.

## Verification (once implemented, on the Mac)

- Build and run in Simulator: set an alternate email, receive the real email (or use a
  test/staging account), confirm the confirmation link opens the web confirm page
  correctly, background/foreground the app (or switch away and back) and confirm the
  verified state updates without a manual pull-to-refresh.
- Confirm the 409 collision case (try to set an address already used elsewhere) and the
  400 "not yet verified" toggle guard both surface clear error text, not a raw failure.
- Confirm Remove clears the address and reverts the UI to the "not set" state.
- While in the file: verify the notification-settings/account-deletion path fix above
  actually round-trips correctly against a real backend (toggle a notification pref,
  reload the screen, confirm it persisted).
