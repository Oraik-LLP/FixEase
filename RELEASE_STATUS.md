# Android 1.1.0 release status — November 13, 2026

This status supersedes older planning claims about these items. Internal beta uses version code 16 (`1.1.0-beta.1`); the production candidate uses code 17 (`1.1.0`). Both use package `com.oraik.fixease` and the configured public RevenueCat Android SDK key. They are successive builds of the same app, not side-by-side installs. Build artifacts are in ignored `finrel/v16` and `finrel/v17` directories.

## Implemented in the Android source

- RevenueCat Flutter 11.0.0 / Google Play Billing 9.1.0, carried forward from v15. Verified entitlement cache preserves bounded offline paid access without an editable saved paid flag. New purchases, restores and AI requests require connectivity.
- Direct make/model input with a small bundled offline catalogue and up to four matching suggestions. Common makes and model prefixes work without an AI call; custom text remains accepted. This is a lookup table, not an offline AI model or a complete market/year database.
- Optional one/two-photo vehicle recognition through the online backend, editable candidates, second-photo guidance, retry/manual/skip recovery and saved local profile photos. The matching backend must be deployed before recognition works in production.
- Category-aware vehicle records for cars, SUVs, motorcycles, scooters, pickups, vans, trucks and buses. Unknown year, fuel, mileage and service information stays unknown. Existing records remain readable. Vehicle selection persists; full details and optional local VIN are editable.
- Clearer diagnosis choices, scrollable setup and release notes, contextual microphone guidance, privacy/permissions information, and compatibility explanations. No GPS collection was added.
- Longer Bluetooth connection timeout for older adapters, bounded permission/discovery operations and paired-adapter fallback when scanning fails. Android 11 / ROG Phone 2 hardware validation remains outstanding.
- Matching release-history content in the app and website. Approved Android icon/splash restoration from the stable reference is retained.

## P0 production status

- A real online symptom diagnosis returned HTTP 200 and a structured diagnosis from the existing production AI backend. This was a synthetic release-validation case, not a real vehicle inspection.
- Server purchase verification and vehicle recognition are tested and pushed to `Oraik-LLP/back_car` main, commit `8cff9f9`. Production now reports `release: 1.1.0-v17`, `purchase_verification: revenuecat-server-v1` and `vehicle_recognition: 1`.
- **Production deployment observed and smoke-tested on November 13, 2026.** A Pro hint without a customer ID returns HTTP 401. A synthetic symptom diagnosis returns HTTP 200 from Gemini (`is_fallback: false`). Online recognition of the bundled stylized Cybertruck illustration returns HTTP 200, identifies Tesla/Cybertruck/pickup, and leaves year and fuel unknown. This is an illustration-based endpoint check, not real-world vehicle-recognition accuracy validation. The deployment dashboard is `https://deploy.oraik.co`, protected by Cloudflare Access. No dashboard configuration or credentials were changed during these checks.
- Genuine Play license-tester purchase/restore/refund/pending-payment testing and airplane-mode checks on a phone remain necessary. The replacement upload key must be active in Play Console before Play accepts these signed bundles.
- Anonymous RevenueCat IDs are not account authentication. Server verification removes a plan-header-only bypass; authenticated account binding/attestation remains future work. Modified APKs cannot be made completely unpatchable.

## Verification

- Flutter analysis: clean.
- Flutter tests: 30 passing, covering OBD parsing, signed entitlement policy, legacy/nullable vehicle records, catalogue matching, narrow-screen input/skip and selected-vehicle persistence.
- Backend: 13 pure tests pass for purchase verification and image/result validation.
- Website: production build and three existing beta/waitlist regression tests pass; changelog preview checked at desktop and mobile viewport sizes.
- No emulator repair or emulator testing was performed. Physical Bluetooth, Play purchases and production photo inference are not established by unit tests.

## Remaining feature backlog

1. Verify a genuine paid RevenueCat entitlement, expired/revoked purchases, and real one/two-photo vehicle recognition through the phone. Production deployment, a free symptom inference, one-image illustration recognition and rejection of a header-only Pro claim are now confirmed; these do not establish the genuine paid path or real-photo accuracy.
2. Phone/internal-track purchase and Bluetooth regression testing, including Android 11 and an actual supported adapter/vehicle combination.
3. Rev Sound / rev-matching entertainment feature: telemetry/audio prototype, licensed sounds, routing/volume/interruption handling and stale-telemetry stop behavior. Not implemented in this build.
4. Verified bike/scooter and commercial-vehicle adapter/protocol coverage, a tested compatibility catalogue, category-specific reports and heavy-duty J1939/SPN/FMI support. Category selection alone does not establish these capabilities.
5. Durable offline scan-analysis retry queue with deduplication, fuller technician raw-data/PDF archive, and model/provider fallback with request/quota idempotency. Grok is not integrated.
6. Broader reviewed make/model/year catalogue, richer category-specific questions and diagnostic content. The current small catalogue allows manual correction for missing entries.
7. Authenticated accounts, account-bound purchases, backup/sync and deletion controls; production iOS signing, purchases and device/adapter testing.
8. Gradle/AGP/Kotlin toolchain migration; current builds succeed but Flutter reports future-support warnings.

Build with `build_playstore.ps1 -SigningCredentialsFile ..\signing\LOCAL_CREDENTIALS.txt`, using explicit `-BuildNumber`, `-BuildName` and `-Channel` for internal builds. Secret signing material remains outside this public repository; the backend RevenueCat secret never belongs in Dart defines.
