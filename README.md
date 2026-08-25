# FixEase

FixEase is a Flutter app for AI-assisted car issue triage. The current app supports symptom-based diagnosis, photo-based diagnosis, a conversational live-assist flow, vehicle management, and local report history.

This repo now runs in a local-first mode:
- vehicle data stays on the device
- diagnostic history stays on the device
- photo references stay on the device
- Gemini calls go through a small backend proxy so the API key is never shipped in the app

## Current Status

Implemented:
- local vehicle storage
- urgent diagnosis flow
- photo diagnosis flow
- Gemini-backed live helper flow
- local report history
- optional guest-mode auth UI

Not implemented yet:
- service checker / side-by-side shop comparison
- calendar / maintenance scheduling
- true production live audio/video session handling

## Building & Running the Project

1. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

2. **Setup the AI Backend:**
   The backend manages environment variables seamlessly via a `.env` file.
   ```bash
   cd backend
   npm install
   ```
   *Note: Ensure your `backend/.env` file exists and contains `GEMINI_API_KEY=your_actual_key_here`.*

3. **Start the Express API:**
   ```bash
   npm start
   ```

4. **Connect & Run the App:**
   Depending on your test environment, route your networking accordingly. Open a *new* terminal at the root:

   **A) Physical Android Device via USB (Recommended)**
   Route the phone's port directly to your PC over the ADB wire to bypass Wi-Fi/firewall issues:
   ```bash
   adb reverse tcp:8787 tcp:8787
   flutter run --dart-define=AI_BACKEND_URL=http://127.0.0.1:8787
   ```

   **B) Android Emulator**
   The emulator maps the magic IP `10.0.2.2` to your host computer:
   ```bash
   flutter run --dart-define=AI_BACKEND_URL=http://10.0.2.2:8787
   ```

   **C) Physical Device via Wi-Fi**
   Find your machine's local IP address (e.g., `192.168.1.5`) matching your phone's network and run:
   ```bash
   flutter run --dart-define=AI_BACKEND_URL=http://YOUR_LOCAL_IP:8787
   ```

*Note: If `AI_BACKEND_URL` is omitted or unreachable, the app remains fully functional and will gracefully fall back to local heuristic estimations instead of Gemini.*

## Production Android Billing

FixEase uses Google Play Billing through RevenueCat. Production builds default
to real store billing; demo entitlement controls are disabled unless
`FIXEASE_DEMO_MODE=true` is explicitly supplied.

1. Create these products in Google Play Console and attach them to the
   RevenueCat `default` offering:
   - `fixease_emergency_pass`
   - `fixease_pro_driver_monthly`
2. Map them to `ENTITLEMENT_EMERGENCY` and `ENTITLEMENT_PRO` in RevenueCat.
3. Copy `release_defines.example.json` to an ignored local file such as
   `release_defines.json`, then add the Android public RevenueCat SDK key.
4. Configure the backend `REVENUECAT_SECRET_API_KEY`. This key belongs only on
   the server and must never be passed to Flutter or committed.
5. Create `android/key.properties` with the Play release signing details:

   ```properties
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=your_key_alias
   storeFile=C:/secure/path/to/fixease-upload.jks
   ```

6. Build the Play release:

   ```bash
   flutter build appbundle --release --dart-define-from-file=release_defines.json
   ```

For an installable APK, replace `appbundle` with `apk`. Google Play production
distribution should use the Android App Bundle and a release signing key.

### Google Play promotion codes

The paywall includes **Redeem a Google Play code** for both paid products. It
starts that product's normal Google Play purchase sheet; the tester then opens
the payment-method menu and chooses **Redeem code**. RevenueCat receives the
result and unlocks the matching entitlement through the same verified purchase
path as a paid transaction.

Create production codes in Play Console under the promotion settings for the
matching product. Do not hard-code codes in Flutter: strings embedded in an APK
can be extracted and reused. Google Play supports automatically generated
single-use codes; subscription products can also use custom multi-use codes.

Billing and promotion-code tests must use a Google Play test track and an
approved tester account. A debug-signed APK can be sideloaded to review the app,
but an APK that has no signature cannot be installed, and sideloading does not
reproduce the complete Play purchase environment.

## Backend Models

- standard diagnosis: `gemini-flash-latest`
- live helper endpoints: `gemini-3.1-flash-live-preview`

The backend can override them with:
- `GEMINI_DIAGNOSIS_MODEL`
- `GEMINI_LIVE_MODEL`

## Architecture

- Flutter app: UI, camera/photo capture, local persistence, report rendering
- Local storage: `shared_preferences` for vehicles, diagnostics, and subscription state
- AI backend: Express + `@google/genai`
- RevenueCat: Google Play/StoreKit purchase and entitlement synchronization

## Key Environment Variables

Flutter:
- `AI_BACKEND_URL`
- optional `SUPABASE_URL`
- optional `SUPABASE_ANON_KEY`

Backend:
- `GEMINI_API_KEY`
- optional `PORT`
- optional `GEMINI_DIAGNOSIS_MODEL`
- optional `GEMINI_LIVE_MODEL`

## Docs

Detailed feature and implementation notes live in [docs/features.md](docs/features.md).
