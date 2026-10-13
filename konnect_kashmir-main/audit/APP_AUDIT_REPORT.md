# KonnectKashmir — Complete Flutter Application Audit

**Scope:** whole repository (`lib/`, `test/`, `android/`, `ios/`, `assets/`, `pubspec.yaml`, config, Git hygiene) plus a *read-only* look at the live backend from the public (anon) key.
**Date:** 2026-10-13 · **Branch:** `main` (clean working tree, 2 commits ahead of `origin/main`) · **App version:** 1.0.4+6
**Mode:** analysis only. No source file was modified, no dependency was changed, no write request was sent to the backend. This report is the only file added.

**How to read the labels**

| Label | Meaning |
|---|---|
| **Confirmed (code)** | Read directly in the source; the behaviour follows from the code. |
| **Confirmed (probe)** | Observed by a read-only request or a tool run during this audit. |
| **Potential** | Pattern that is likely to matter but needs profiling or a device to prove. |
| **Backend-verify** | Depends on server behaviour that is not in this repository. Not verified. |
| **Device-verify** | Needs a real iOS/Android device test. |

Nothing in this report was measured with DevTools; no performance number is claimed unless it says where it came from.

---

## A. Executive Summary

**Overall health: good foundations, a few real defects, a lot of dead weight.**

The app is better structured than its size suggests. There is a single theme/token file, localization is complete (299 keys in each of English, Hindi, Urdu), controllers/timers/subscriptions are disposed consistently, token refresh is single-flight, the credit-unlock flow reconciles after failures, request sequencing exists on the main list, and the anonymous key can read nothing sensitive (see §D "Backend probe"). There is no cleartext HTTP anywhere.

**The issues that matter most**

1. **Credentials and PII reach the log in release builds** — the `verify-otp` response body (which contains the account's generated e-mail and password) and phone numbers are printed with `debugPrint`, which is not stripped from release builds. *(SEC-02)*
2. **Auth tokens are stored in plain `SharedPreferences`** while `flutter_secure_storage` sits unused in `pubspec.yaml`, and Android auto-backup is not disabled. *(SEC-01)*
3. **A failed network call shows "0 credits"** (`getUserCredits` returns `0` on any error and `LiveSync` accepts it). This can trigger "out of credits" banners and push people into watching ads. *(API-01)*
4. **Saving or editing a business is three unchecked writes** (PATCH vendor → DELETE categories → POST categories). A failure in the last two silently leaves the business with no categories. *(API-02)*
5. **Ad rewards depend on a client-side 30-second timer**; the server only receives `{adId}`. Whether it can be abused depends on server rules I could not see. *(SEC-03, Backend-verify)*
6. **About 4,700 lines (≈19.5 %) of `lib/` are unreachable legacy screens**, and 93 of the 116 public `ApiService` methods (about 1,320 of its 2,012 lines) are unused, including admin-style calls such as `updateUserCredits`. *(ARCH-01, ARCH-02)*

**Biggest UI/UX opportunities:** the Home screen (3,450-line file), the Add-Credit/ads area (silent failures), the business registration form (hard-coded locality list, 107 names vs 386 in the database), accessibility (one `Semantics` widget in the whole app), and a handful of dead-end controls (a "Saved providers only" filter that cannot be used because nothing can be saved).

**Biggest performance opportunities (all need before/after profiling):**
(a) Home fetches platform statistics on every load — three requests that download every vendor id — and never displays the result; (b) a fixed 2.4 s splash plus a blocking `Future.wait` before `runApp`; (c) the vendor list builds every loaded card eagerly; (d) ~12–14 requests on every Home load, some of which download whole tables just to count rows; (e) per-request latency (~0.35–0.4 s measured earlier in this project, with ~3 ms database time) points to the backend region.

**Security/reliability to confirm on the backend:** OTP attempt limiting (4-digit OTP), server-side enforcement of ad-watch time, row-level policies on client-supplied fields (`is_approved`, `user_id`, `credit_balance`), and cross-user access with two real accounts.

**Counts:** 61 findings — Critical 0 · High 4 · Medium 26 · Low 31. (Nothing is "Critical": none of the issues allows a remote, unauthenticated attacker to take over accounts or money from what I can verify. SEC-03/04/05 could be raised if the backend turns out not to enforce what the app assumes.)

---

## B. Codebase Coverage

### B.1 Inventory

| Area | Files | Notes |
|---|---|---|
| `lib/` | 71 Dart files (+4 generated localization files) | 24,206 lines excluding generated code |
| `test/` | 3 | 2 real test files (21 tests) + 1 placeholder |
| `android/` | 33 | Gradle, manifest, resources |
| `ios/` | 53 | Info.plist, entitlements, AppDelegate, xcodeproj, assets |
| `assets/` | 3 images | 4.45 MB combined |
| `web/ windows/ linux/ macos/` | 66 | Generated platform scaffolding, not store targets |

### B.2 Review depth (honest)

**Read in full (or all the relevant code):**
`main.dart`, `providers/auth_provider.dart`, `providers/theme_provider.dart`, `providers/locale_provider.dart`, `services/api_service.dart`, `services/auth_service.dart`, `services/live_sync.dart`, `services/notification_service.dart`, `services/shared_http.dart`, `services/backend_config.dart`, `services/lead_loader.dart`, `services/customer_location.dart`, `screens/splash_screen.dart`, `screens/main_shell.dart`, `screens/login_screen.dart`, `screens/my_business_tab.dart`, `screens/ad_watch_dialog.dart`, `widgets/add_credit_section.dart`, `widgets/error_retry.dart`, `widgets/theme_reveal.dart`, `widgets/app_widgets.dart`, `widgets/app_background.dart`, `static/legal_accordion.dart`, `static/legal_chrome.dart`, `static/contact_screen.dart`, `screens/deen/quran_service.dart`, ARB files (key parity).

**Read in part (key flows) + pattern scans:**
`screens/customer_screen.dart` (~900 of 3,450 lines: data loading, `build`, list assembly, vendor card, unlock/reveal; the rest by pattern scan), `screens/otp_ver.dart` (260/469), `screens/vendor_screen.dart` (~380/1,241: initialisation, helpers, the whole submit path), `screens/profile_tab.dart` (300/601), `screens/profile_screen.dart` (165/430), `screens/deen/deen_tab.dart` (240/1,143), `screens/deen/audio_screen.dart` (~70/326), `theme/app_theme.dart` (~120/318 + grep), the four static legal screens (structure and headers; the legal wording itself was **not** reviewed for legal accuracy).

**Pattern-scanned only (grep / analyzer / reachability):**
`screens/dashboard_screen.dart`, `vendor_dashboard.dart`, `home_screen.dart`, `profile2.dart`, `role_selection.dart`, `transaction_history_screen.dart`, `ad_credits_screen.dart`, `language_screen.dart`, `deen/quran_screens.dart`, `deen/duas_screen.dart`, `deen/deen_data.dart`, `deen/prayer_service.dart`, and the small widgets (`app_chip`, `app_header`, `app_overlays`, `app_snack`, `category_meta`, `english_only`, `expandable_text`, `force_ltr`, `lead_contact_sheet`, `text_size_sheet`, `transaction_card`, `transactions_section`).
Findings about the legacy screens (dashboard/vendor_dashboard/profile2/home/role_selection) come from the analyzer, reachability tracing and grep, not from a line-by-line read — they are unreachable, which is why I did not read them in full.

**Native & config read:** `AndroidManifest.xml`, `app/build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`, `key.properties` (key *names* only, values never printed), `res/values/colors.xml`; `Info.plist`, `Runner.entitlements`, `AppDelegate.swift`, deployment target in `project.pbxproj`; `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `test/*`, `README.md`; `flutter analyze` (353 issues categorised), `flutter pub outdated`, `git ls-files`.

### B.3 Not inspected, and why

| Item | Reason |
|---|---|
| Supabase Edge Function source, SQL, RLS policies | Not in the repository. Only the public (anon) surface was probed. |
| Firebase, Play Console, App Store Connect, Meta dashboards | No access. |
| `web/ windows/ linux/ macos/` | Generated scaffolding, not shipped to stores. |
| `build/`, `.dart_tool/`, Gradle caches, Pods | Generated/vendored. |
| Binary assets | Sizes only. |
| Runtime behaviour (frame times, memory, startup, battery) | No profiling was run. |
| iOS behaviour | No Mac/iPhone in this session. |

### B.4 Two read-only production probes (disclosed)

Using the same public key and endpoints the app already uses: (1) 20 rows of `vendors_public.phone`, evaluated by pattern only — no numbers were printed or stored; (2) one `limit=1` request per table asking only for the row count. No write requests, no authenticated requests.

---

## C. Screen-by-Screen UI/UX Review

*(Severity and IDs refer to §D. "Reviewed: full/partial/scan" matches §B.2.)*

### C1. Splash — `lib/screens/splash_screen.dart` (full)
- Fixed 2.4 s wait (`Future.delayed(2400 ms)`, line 42) on every cold start regardless of readiness. **PERF-04**
- Nice, light animation (single controller, painter has no per-frame allocation). Leave as is.

### C2. Sign-in — `lib/screens/login_screen.dart` (full)
- Phone field has no digit-only formatter, `maxLength`, `textInputAction`/`onSubmitted`, or `autofillHints`; the keyboard "done" key does not submit. **UX-05**
- Visual label "Mobile number" is a separate `Text`; the field has no `labelText`/semantic label. **UX-04**
- `setState` after `await` without a `mounted` check in the error branches (lines 88, 91). **API-06b**
- `onChanged` rebuilds the whole scroll tree each keystroke (`setState(() {})`, line 414). **PERF-06**
- Hard-coded dark palette constants (`inputBorderDark` used in light mode too) instead of tokens. **UX-10**
- Error text shown as `'Error: ${e.toString()}'`. **SEC-09**

### C3. OTP — `lib/screens/otp_ver.dart` (partial)
- `_verifyOTP` / `_resendOTP` call `setState` **before** `if (!mounted) return;` (lines 122–123, 159–160) → "setState after dispose" if the user leaves mid-request. **API-06b**
- Blinking cursor loops `setState` on the whole screen every 600 ms. **PERF-06**
- Language picker is shown after every sign-in (by earlier request; preselected). **UX-06**
- 4-digit code: attempt limiting is a server matter. **SEC-05**

### C4. Language — `lib/screens/language_screen.dart` (scan)
- Not read in full. No issues found by pattern scan.

### C5. Complete profile — `lib/screens/profile_screen.dart` (partial)
- Reads the token straight from `SharedPreferences` rather than `AuthProvider`; duplicates URL/key constants. **SEC-06, SEC-01**
- Non-2xx shows the backend `message` verbatim. **SEC-09**

### C6. App shell — `lib/screens/main_shell.dart` (full)
- Good: lazy tabs via `_opened`, `PopScope` back-to-Home, session-expired dialog.
- Hidden tabs keep tickers running (IndexedStack). **PERF-05**

### C7. Home — `lib/screens/customer_screen.dart` (partial, 3,450 lines)
- All loaded vendor cards are built eagerly each rebuild; `context.watch<AuthProvider>()` at the top of `build`. **PERF-02**
- Startup fires ~12–14 requests; stats are fetched but never shown. **PERF-01, PERF-03**
- "Saved providers only" filter without a way to save providers. **UX-01**
- Dead `_buildBottomNavBar`, `_toggleFavorite`, `_sortLabel`, `_buildBrowseByService` (analyzer). **ARCH-06**
- Vendor logos: `Image.network`, no disk cache, bypasses the DNS-fallback client. **PERF-07**
- Unlock/reveal flow is solid: double-tap guard, reconcile after failure. Leave alone.
- 3,450 lines / ~70 state fields in one class. **ARCH-03**

### C8. My Business — `lib/screens/my_business_tab.dart` (full)
- Leads with no `vendor_id` are shown under **every** business of the user (lines 233–238). **API-08**
- All leads rendered eagerly in a `Column`; no pagination. **PERF-10**
- Error/empty/loading states all exist (good). Raw error text reaches the snackbar via `snackCouldntRefreshLeads`. **SEC-09**
- Credit-0 fallback drives the "out of credits" banner. **API-01**

### C9. Business registration/edit — `lib/screens/vendor_screen.dart` (partial)
- Three unchecked sequential writes. **API-02**
- Locality chosen from a hard-coded 107-name map, resolved by name only. **API-03**
- No timeouts on any of the calls in `_submitForm`. **API-04**
- Sends `is_approved`, `is_verified`, `user_id` from the client. **SEC-04**
- Duplicated URL/anon key. **SEC-06**

### C10. Profile — `lib/screens/profile_tab.dart` (partial)
- Delete-account flow is careful (phone confirmation, blocking progress dialog, 401 refresh-and-retry). Leave alone.
- `Future.delayed(500 ms, ctrl.dispose)` to dispose a sheet controller is a workaround (works). **ARCH-06**

### C11. Add credit / ads — `widgets/add_credit_section.dart`, `screens/ad_watch_dialog.dart`, `screens/ad_credits_screen.dart` (full)
- Failures swallowed; offline looks like "No ads right now"; balance can be `null` forever (skeleton). **UX-02**
- Reward claim trusts a client timer. **SEC-03**
- `ad_watch_dialog.dart` forces `portraitUp` on dispose, which locks the whole app to portrait after the first ad. **UX-07**
- Full-screen layout (changed earlier today) works; the 190 dp "free height" estimate is a heuristic (the player shrinks safely if wrong).

### C12. Deen — `deen/deen_tab.dart` (partial), `audio_screen.dart` (partial), `quran_screens.dart`, `duas_screen.dart` (scan)
- Well built: compass isolated in a `ValueNotifier` and stopped when the tab is hidden; cached times shown first.
- `_error = e.toString()` shown to users in several Deen screens. **SEC-09**
- Prayer times for "today" are not recomputed after midnight while the app stays open (low; `_now` ticks but `_day` stays). **UX-11**

### C13. Legal & Contact — `static/*` (structure only for legal text)
- Reworked earlier today (shared app bar/header, numbered accordion). Consistent. Legal text itself is English-only. **UX-08**
- Privacy policy content does not match the app's data practices. **SEC-08**

### C14. Legacy screens (unreachable) — `dashboard_screen.dart`, `vendor_dashboard.dart`, `profile2.dart`, `home_screen.dart`, `role_selection.dart`, `transaction_history_screen.dart`
- Not reachable from any live code path (§D ARCH-01). Contain 50+ hard-coded English strings, a duplicated anon key and bodies logged with `debugPrint`. Recommend deletion rather than polishing.

---

## D. Detailed Technical Findings

Severity counts: **High 4 · Medium 26 · Low 31** (61 findings; cross-reference stubs UX-09 and PLT-08 are not counted). Where a finding sits between two levels it is rated at the lower one; SEC-03 could be High depending on the backend. Findings are ordered by category, then severity.

### D.0 Backend probe (anonymous key, read-only) — *Confirmed (probe)*

| Table / view | Rows visible to anon | Reading |
|---|---|---|
| `profiles`, `user_roles`, `credit_transactions`, `call_clicks`, `user_device_tokens`, `unlocked_vendor_contacts`, `unlocked_leads`, `ad_views`, `reports`, `vendor_reviews`, `activity_logs`, `referrals`, `jobs`, `job_applications`, `vendors` | 0 | Row-level security is working for the anonymous role. |
| `vendors_public` | 1,927 (intended) | `phone` was empty in 20 of 20 sampled rows → the paywall is **not** bypassable through this view by an anonymous client. |
| `ads` (4), `service_categories` (59), `districts` (11), `localities` (386), `vendor_reviews_public` (1) | readable | Intended public data. |
| `aadhaar_verifications` | HTTP 401 | Locked for anon. |

**Not covered:** what an *authenticated* user can read/write of *another* user's rows (needs two real accounts). Tracked as SEC-04.

---

### Security & Privacy

#### SEC-02 — Credentials/PII written to the release log
- **Category / Severity / Type:** Security · **High** · Confirmed (code)
- **File / Location:** `lib/providers/auth_provider.dart:187` (verify-otp body), `:144` (phone number); `lib/services/notification_service.dart:227` (response body); `lib/screens/dashboard_screen.dart:116,130` (unreachable)
- **Current problem:** `debugPrint('[AuthProvider] legacyVerifyOTP → ${verifyResponse.statusCode}: ${verifyResponse.body}')`. The same method reads `verifyData['email']` and `verifyData['password']` from that body (lines 203–211), so the account's server-generated password is printed. `debugPrint` is not removed in release builds.
- **Evidence:** the two lines above; `debugPrint` has no `kDebugMode` guard.
- **Recommendation:** delete these logs or wrap them in `if (kDebugMode)`; never log bodies of auth calls; log status codes only. Longer term, have the Edge Function return session tokens instead of a password (backend change).
- **Expected benefit:** removes a credential/PII leak path (visible via `adb logcat`/crash collectors on any device with debugging enabled).
- **Risk:** none functionally. **Effort:** Small.
- **Validation:** run a release build, sign in, `adb logcat | findstr /i "password email otp"` → no matches.

#### SEC-01 — Auth tokens in plain `SharedPreferences`; auto-backup not disabled
- **Category / Severity / Type:** Security · **High** · Confirmed (code)
- **File / Location:** `auth_provider.dart:275–285, 468–480`; `profile_screen.dart:63`; `android/app/src/main/AndroidManifest.xml` (`<application>` has no `allowBackup`); `pubspec.yaml` (`flutter_secure_storage` declared, 0 imports)
- **Current problem:** access token, refresh token, user id, phone, e-mail and name are stored unencrypted. The manifest does not set `android:allowBackup`, whose platform default is `true`, so the preferences file is eligible for Auto-Backup/`adb backup` (confirm in the merged manifest).
- **Evidence:** `prefs.setString('access_token' …)`, `prefs.setString('refresh_token' …)`; grep shows `flutter_secure_storage` is never imported.
- **Recommendation:** store tokens in `flutter_secure_storage` (already a dependency; Keystore/Keychain-backed), keep only non-sensitive preferences in `SharedPreferences`; add a one-time migration (read old keys → write secure → delete old). Set `android:allowBackup="false"` (or `dataExtractionRules` excluding preferences).
- **Expected benefit:** a stolen backup or rooted-device file read no longer yields a refresh token that can mint sessions.
- **Risk:** migration bugs could sign users out once; secure storage can fail on some Android devices (handle read errors as "signed out"). **Effort:** Medium.
- **Validation:** unit-test the migration; on a device confirm `shared_prefs/FlutterSharedPreferences.xml` no longer contains `access_token`/`refresh_token`; `adb backup` produces no tokens.

#### SEC-03 — Ad reward trusts a client-side 30 s timer
- **Category / Severity / Type:** Security/abuse · **Medium** (could be High) · Confirmed (code) + **Backend-verify**
- **File / Location:** `lib/screens/ad_watch_dialog.dart` (`_requiredSeconds = 30`, timer counts only while the YouTube player reports "playing"); `lib/services/api_service.dart` `claimAdCredits` sends only `{adId}`
- **Current problem:** the server cannot know how long anything was watched. Any signed-in client (or a modified app) can call `claim-ad-credits` directly. The only possible protection is server-side (`max_views_per_user`, rate limits) which I could not see.
- **Evidence:** request body is `{'adId': adId}`; `ads` rows (including `max_views_per_user`) are world-readable.
- **Recommendation:** have the server issue a short-lived "view started" token/timestamp and refuse a claim earlier than N seconds after it; enforce `max_views_per_user` and a daily cap server-side; log anomalies. (No client change helps on its own.)
- **Expected benefit:** protects the credit economy that gates paid contact unlocks.
- **Risk:** requires coordinated backend + client release. **Effort:** Medium (backend).
- **Validation:** call the function directly with a valid user JWT and no view-start; it must be rejected.

#### SEC-04 — Client-supplied privileged fields (needs policy review)
- **Category / Severity / Type:** Security · **Medium** · **Backend-verify**
- **File / Location:** `vendor_screen.dart:1155–1160` (`is_approved:false, is_verified:false, user_id`); `api_service.dart` `updateUserProfile` (arbitrary map), `updateUserCredits:1611–1634` (client-side read-modify-write of `profiles.credit_balance`, unused)
- **Current problem:** the app sends approval flags and `user_id` itself, and exposes generic PATCH helpers. Whether a malicious client can set `is_approved:true`, write another user's `user_id`, or change `credit_balance`/`role`/`is_blocked` depends entirely on RLS `WITH CHECK` clauses and column privileges.
- **Evidence:** payload construction in the file above; anonymous probe only proves anon cannot read.
- **Recommendation:** with two test accounts, try (read-only first, then writes on throw-away data): reading user B's rows; inserting a vendor with `is_approved:true`; patching own `credit_balance`/`role`; patching another user's profile. Pin with `WITH CHECK (user_id = auth.uid() AND is_approved = false)` and revoke column UPDATE on sensitive columns. Delete the unused client helpers.
- **Expected benefit:** closes self-approval/credit-tampering paths if they exist.
- **Risk:** policy changes can break the app's own writes — test first. **Effort:** Medium.
- **Validation:** scripted two-account test suite; every attempt above must return 401/403/0 rows.

#### SEC-05 — 4-digit OTP: attempt limiting not verifiable
- **Category / Severity / Type:** Security · **Medium** · **Backend-verify**
- **File / Location:** `services/auth_service.dart` (`otpLength = 4`, 5-min validity)
- **Current problem:** 10,000 possible codes. Brute-force resistance depends on server lockout per phone and per IP, and on `send-otp` throttling (SMS cost/abuse).
- **Recommendation:** verify/enforce e.g. ≤5 wrong attempts then lock and require a new OTP; per-phone and per-IP send limits; consider 6 digits if DLT template permits.
- **Expected benefit:** prevents account takeover by guessing and SMS-bombing.
- **Risk:** template/UX change if digits increase. **Effort:** Small–Medium (backend).
- **Validation:** call `verify-otp` 10 times with wrong codes for one phone; later attempts must be rejected.

#### SEC-08 — Privacy policy/consent does not match what the app does
- **Category / Severity / Type:** Privacy/compliance · **Medium** · Confirmed (code)
- **File / Location:** `lib/static/privacy_screen.dart` (§10 "Cookies", "Analytics"); `lib/main.dart:55`; `AndroidManifest.xml` (Facebook meta-data); `ios/Runner/Info.plist` (Facebook keys); `deen/prayer_service.dart` (coordinates to `api.aladhan.com`)
- **Current problem:** the Meta (Facebook) App Events SDK auto-initialises and `setAutoLogAppEventsEnabled(true)` is called before any consent; Firebase Messaging stores a device token; precise coordinates are sent to a third-party API (and to the platform geocoder). The policy is written for a website ("cookies", "browser settings") and names none of these.
- **Recommendation:** update the policy and the Play "Data safety" / App Store privacy answers to list location (use + third parties), device token, advertising/analytics SDK; consider disabling auto-init (`AutoInitEnabled`/`FacebookAutoLogAppEventsEnabled=false`) until the user accepts a short consent. *This is an engineering observation, not legal advice.*
- **Expected benefit:** store-review and DPDP-Act alignment.
- **Risk:** analytics volume drops until consent. **Effort:** Small (text) / Medium (consent gate).
- **Validation:** compare policy text with a network capture of a fresh install.

#### SEC-09 — Raw exception and server text reach the user
- **Category / Severity / Type:** Security (info leak) / UX · **Low** · Confirmed (code)
- **File / Location:** `api_service.dart:376` (`'Lead fetch failed (…): ${res.body}'`), many `_err('Network error: $e')`; `login_screen.dart:91`; `vendor_screen.dart:1136,1170`; `deen_tab.dart:173`, `audio_screen.dart:84`, `quran_screens.dart:47,226`; `my_business_tab.dart:274,281`
- **Current problem:** exception strings (e.g. `SocketException … host`) and backend messages (including Postgres constraint text) can be shown verbatim.
- **Recommendation:** one `userMessage(error)` mapper → localized, friendly text; log the detail in debug only.
- **Expected benefit:** cleaner UX; less internal detail exposed.
- **Risk:** low. **Effort:** Small–Medium.
- **Validation:** turn on airplane mode / force a 500 and read every error surface.

#### SEC-06 — Supabase URL/anon key duplicated in six places
- **Category / Severity / Type:** Maintainability/security hygiene · **Low** · Confirmed (code)
- **File / Location:** `api_service.dart:6–8`, `vendor_screen.dart:42–43`, `profile_screen.dart:34–36`, `dashboard_screen.dart:38–39` (dead), `vendor_dashboard.dart:38–39` (dead), `my_business_tab.dart:40` (URL) — while `services/backend_config.dart` says it is "the one place".
- **Current problem:** the anon key is a *public* key by design (acceptable to ship), but copies drift on rotation. `Supabase.initialize(anonKey:)` is also deprecated in favour of `publishableKey`.
- **Recommendation:** import `kSupabaseUrl`/`kSupabaseAnonKey` everywhere; move to `--dart-define` for per-environment builds.
- **Expected benefit:** single point of change.
- **Risk:** none. **Effort:** Small.
- **Validation:** `grep` shows only `backend_config.dart` contains the key.

#### SEC-07 — Firebase client config tracked in Git
- **Category / Severity / Type:** Security hygiene · **Low** · Confirmed
- **File / Location:** `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`; Firebase iOS options also in `notification_service.dart:79–88`
- **Current problem:** these are public client identifiers, not secrets, but their API keys should be restricted (package name/SHA-1, bundle id) in Google Cloud.
- **Recommendation:** confirm key restrictions; keep the service-account JSON out of the repo (it currently is).
- **Effort:** Small. **Validation:** Google Cloud console → API key → application restrictions set.

#### SEC-10 — Release build silently falls back to the debug key
- **Category / Severity / Type:** Release safety · **Low** · Confirmed (code)
- **File / Location:** `android/app/build.gradle.kts` (`signingConfig = if (hasReleaseKeystore) … else debug`)
- **Current problem:** a missing `key.properties` yields a debug-signed "release" with only a warning. Play rejects it, but a side-loaded debug-signed build could circulate.
- **Recommendation:** fail the build for `bundleRelease`/`assembleRelease` when the keystore is missing. Also rotate the upload-key passwords if they were ever shared outside a secure channel (they appeared in an earlier working session).
- **Effort:** Small. **Validation:** rename `key.properties`, run `flutter build appbundle` → must fail.

---

### API, Data & Reliability

#### API-01 — A failed request is shown as "0 credits"
- **Category / Severity / Type:** Reliability/functional · **High** · Confirmed (code)
- **File / Location:** `api_service.dart:1171–1192` (`getUserCreditsRPC` returns `0` on any error; `getUserCredits` returns `0` if the profile lookup also fails); `services/live_sync.dart:94–96` (`if (c != null …) setCredits(c)`)
- **Current problem:** offline, timeout or 5xx → `0` (not `null`) → `LiveSync.setCredits(0)`. `my_business_tab.dart:326` shows the "out of credits" banner; Home unlock logic treats 0 as "must watch an ad". Also, a *legitimate* balance of 0 triggers a second request (`rpcBalance > 0` check).
- **Evidence:** code above; `int? getUserCredits()` can never return `null`.
- **Recommendation:** return `null` on failure and keep the last known balance; treat `0` as a valid value (no fallback request when the RPC succeeded).
- **Expected benefit:** no false "0 credits", fewer ad prompts, one request fewer at zero balance.
- **Risk:** low — callers already handle `null`. **Effort:** Small.
- **Validation:** unit test with a mock client returning errors; manual airplane-mode check on Home/My Business.

#### API-02 — Business create/edit is a chain of unchecked writes
- **Category / Severity / Type:** Data integrity · **High** · Confirmed (code)
- **File / Location:** `vendor_screen.dart:1126–1150` (edit), `:1162–1184` (create)
- **Current problem:** edit does PATCH `vendors` → DELETE all `vendor_categories` → POST new categories; only the first status is checked. If the POST fails (offline, 5xx, constraint) after the DELETE succeeded, the business ends with **no categories** and the user is told "success". Create has the same gap (vendor saved, categories ignored on failure). No timeouts (API-04).
- **Recommendation:** make it one server-side operation (RPC/Edge Function in a transaction), or at minimum check each response, retry, and restore on failure; show an error and keep the form open.
- **Expected benefit:** no silent data loss.
- **Risk:** backend change for the transactional version. **Effort:** Medium.
- **Validation:** simulate a failing third request (proxy/blocked path) and confirm the previous categories survive.

#### API-03 — Locality picked from a stale hard-coded list and resolved by name
- **Category / Severity / Type:** Data correctness · **Medium** · Confirmed (code + probe)
- **File / Location:** `vendor_screen.dart:155–189` (map of 9 districts / 107 names), `:1096–1107` (`localities?name=eq.<name>&limit=1`)
- **Current problem:** the database has 11 districts / 386 localities (probe); the form can only offer the 107 names baked into the app. The lookup ignores the district, so a name present in two districts resolves to an arbitrary row, and a failed lookup silently saves `locality_id: null`.
- **Recommendation:** load districts/localities with the existing `getDistricts/getLocalities`, submit `locality_id` directly, block submit if missing.
- **Expected benefit:** forms stay in sync with the backend; correct location on every listing.
- **Risk:** low. **Effort:** Medium.
- **Validation:** add a locality in the DB → it appears in the form without an app update.

#### API-04 — Most network calls have no timeout
- **Category / Severity / Type:** Reliability · **Medium** · Confirmed (code)
- **File / Location:** `api_service.dart` (2 of ~108 calls use `.timeout`), `vendor_screen.dart` submit, `shared_http.dart` (no default)
- **Current problem:** on a stalled connection `Future`s never complete → spinners/disabled buttons forever (unlock, claim, create vendor, profile update).
- **Recommendation:** wrap `sharedHttp` once (a small `http.BaseClient` decorator) with a default 20 s timeout, with longer limits only where needed.
- **Expected benefit:** every screen recovers or shows an error instead of hanging.
- **Risk:** very slow uploads could time out; set per-call overrides. **Effort:** Small.
- **Validation:** throttle to 0 kbps in DevTools/proxy; every spinner must end ≤ timeout.

#### API-05 — 401 handling is ad hoc
- **Category / Severity / Type:** Reliability · **Medium** · Confirmed (code)
- **File / Location:** retry-after-refresh exists in `my_business_tab.dart:74–88`, `services/lead_loader.dart`, `profile_tab.dart:228–233`; absent for unlock, claim, listing, profile update, reviews, reports. UI decides by string matching (`err.contains('(401)')`, lines 83, 249).
- **Current problem:** a request made just after expiry fails with "(401)" even though a refresh would succeed; behaviour differs by screen.
- **Recommendation:** one authenticated-request helper that refreshes once on 401 and retries idempotent requests; return typed results (status code, not string).
- **Expected benefit:** fewer spurious errors, less duplicated retry code.
- **Risk:** must not retry non-idempotent charges blindly (unlock/claim are server-idempotent per earlier probes, but confirm). **Effort:** Medium.
- **Validation:** force an expired token (edit stored expiry) and exercise each action.

#### API-06 — `verifyOTP` can leave the login spinner stuck; `setState` before `mounted`
- **Category / Severity / Type:** Reliability · **Medium** · Confirmed (code)
- **File / Location:** `auth_provider.dart:301` (`on Exception catch`), `otp_ver.dart:122–123,159–160`, `login_screen.dart:88,91`
- **Current problem:** (a) a `TypeError`/`NoSuchMethodError` from an unexpected response shape is an `Error`, not an `Exception`, so it bypasses the catch and `_isLoading` stays `true`; (b) several screens call `setState` before checking `mounted`.
- **Recommendation:** `catch (e)`; validate that the decoded JSON is a `Map`; check `mounted` first.
- **Expected benefit:** no frozen sign-in; no "setState after dispose" exceptions.
- **Risk:** none. **Effort:** Small.
- **Validation:** unit test with `[]`/HTML bodies; widget test that pops the screen mid-request.

#### API-07 — Token lifetime hard-coded to 3,600 s
- **Category / Severity / Type:** Reliability · **Low** · Confirmed (code)
- **File / Location:** `auth_provider.dart:283–285, 344–346, 482–484`
- **Recommendation:** use `expires_in`/`expires_at` from the token response.
- **Effort:** Small. **Validation:** change server JWT expiry in a test project; refresh timing follows.

#### API-08 — Leads: attribution fallback and no pagination
- **Category / Severity / Type:** Data correctness/scale · **Medium** · Confirmed (code) + **Backend-verify**
- **File / Location:** `my_business_tab.dart:233–238`; `services/api_service.dart` `getLeadNames`
- **Current problem:** a lead without `vendor_id` is attached to **every** business the user owns (duplicates, wrong counts); the list is not paginated.
- **Recommendation:** have `get-lead-names` return `vendor_id` (already requested in an earlier session) and accept paging; drop the "show under all" fallback.
- **Risk:** backend change. **Effort:** Medium.
- **Validation:** two businesses + one lead → exactly one card shows it.

#### API-09 — `unlock-vendor-contact` is also used as a read
- **Category / Severity / Type:** Design risk · **Low** · Confirmed (code)
- **File / Location:** `customer_screen.dart:2882–2890` (`_resolveUnlockedPhone`)
- **Current problem:** fetching an already-unlocked phone calls the charging endpoint; correctness depends on server idempotency.
- **Recommendation:** add a read-only endpoint/RPC for "phone of vendors I unlocked".
- **Effort:** Small (backend). **Validation:** call twice, balance unchanged.

#### API-10 — Push-token registration is PATCH-then-POST
- **Category / Severity / Type:** Reliability · **Low** · Confirmed (code) + Backend-verify
- **File / Location:** `notification_service.dart:207–230`
- **Recommendation:** single upsert (`on_conflict=fcm_token`) if a unique constraint exists.
- **Effort:** Small.

---

### Performance

*(Everything below is Confirmed (code) unless marked Potential. None was profiled.)*

#### PERF-01 — Platform statistics fetched every Home load and never displayed
- **Category / Severity:** Performance · **Medium**
- **File / Location:** `customer_screen.dart:541` (`_loadStats`), `:318–320` (assigned, never read); `api_service.dart:1360–1386` (`getPlatformStats`)
- **Current problem:** three sequential requests; the first downloads the `id` of every approved vendor (1,927 rows in the probe) just to take `.length`. The three counters are written but never read.
- **Recommendation:** delete the call (or, if the numbers return to the UI, use `Prefer: count=exact` with `limit=0`).
- **Expected benefit:** 3 fewer requests and an estimated ~100 KB less per Home load (1,927 × ~50 B; estimate, not measured).
- **Risk:** none. **Effort:** Small.
- **Validation:** DevTools Network tab on a cold Home load, before/after.

#### PERF-02 — Home builds every loaded vendor card on each rebuild (Potential)
- **Category / Severity:** Performance · **Medium**
- **File / Location:** `customer_screen.dart:2020–2038` (`ListView(children: …)`), `:2470–2495` (`_vendorListChildren`), `:1999` (`context.watch<AuthProvider>()`), `:2497+` (`_buildVendorCard`)
- **Current problem:** with infinite scroll appending 20 per page, every `setState` (expand a card, search keystroke, auth notification) re-executes `_buildVendorCard` for **all** loaded vendors (regex split, `firstWhere` over categories, localisation lookups). `AnimatedOpacity` wraps each card.
- **Recommendation:** `ListView.builder`/`SliverList.builder`; extract `VendorCard` as its own widget with cached derived strings; `context.select` for the auth fields used.
- **Expected benefit:** rebuild cost independent of pages loaded; smoother scrolling after many pages.
- **Risk:** medium (scroll restoration, animations). **Effort:** Medium.
- **Validation:** DevTools Performance + "Track widget rebuilds" after scrolling to ~200 vendors; compare frame build time and rebuild counts.

#### PERF-03 — Home cold start issues ~12–14 requests
- **Category / Severity:** Performance · **Medium**
- **File / Location:** `customer_screen.dart:494` (`_loadData`), `api_service.dart:1970–1989` (`getUserAdViewCounts` downloads every `ad_views` row to count client-side), `:1961` (unlocked list)
- **Current problem:** districts, 3× stats, vendors, ads, categories, credits RPC (+profile fallback), unlocked list and ad-view rows all run on every Home load and pull-to-refresh. They are parallel (good), but several are not needed to draw the first screen.
- **Recommendation:** remove stats (PERF-01); defer ads, ad-view counts and the unlocked list until the user opens something that needs them; replace row-download-then-count with a grouped query/RPC.
- **Expected benefit:** faster first content; less data.
- **Risk:** low–medium (state that was preloaded now loads on demand). **Effort:** Medium.
- **Validation:** request count/bytes on cold start, before/after.

#### PERF-04 — Startup is gated by init and a fixed 2.4 s splash
- **Category / Severity:** Performance/UX · **Medium** (partly Potential)
- **File / Location:** `main.dart:38–43` (awaits `Future.wait([restoreSession, Supabase.initialize, ThemeProvider.load, LocaleProvider.load])` before `runApp`), `auth_provider.dart:435` (up to 4 s waiting for an expired token), `splash_screen.dart:42` (fixed 2,400 ms)
- **Current problem:** time-to-interactive ≥ 2.4 s + init, always. `Supabase.initialize` is used only for Realtime (the app otherwise uses its own REST client), so the whole SDK start-up sits on the critical path.
- **Recommendation:** call `runApp` first with a lightweight state; make the splash adaptive (e.g. minimum ~1 s, continue when ready); initialise Supabase lazily when `LiveSync` first needs it (or reconsider the SDK).
- **Expected benefit:** the biggest single "feels faster" change available client-side.
- **Risk:** low–medium (ordering assumptions). **Effort:** Small–Medium.
- **Validation:** `flutter run --profile --trace-startup` → compare `timeToFirstFrameMicros`; stopwatch from tap to Home.

#### PERF-05 — Hidden tabs keep animating (Potential)
- **Category / Severity:** Performance/battery · **Low**
- **File / Location:** `main_shell.dart` `IndexedStack`; `widgets/app_widgets.dart:102–107` (`Skeleton` = repeating controller per instance); spinners
- **Current problem:** `IndexedStack` does not disable tickers of off-screen children.
- **Recommendation:** wrap non-active tabs in `TickerMode(enabled: isActive, …)`; share one shimmer controller.
- **Effort:** Small. **Validation:** DevTools frame timeline while a hidden tab is "loading".

#### PERF-06 — Whole-screen rebuilds for trivial UI
- **Category / Severity:** Performance · **Low**
- **File / Location:** `otp_ver.dart:222–236` (cursor `onEnd: setState` every 600 ms), `:56–63`; `login_screen.dart:408–415`
- **Recommendation:** isolate the cursor in a small widget; avoid empty `setState`.
- **Effort:** Small.

#### PERF-07 — Vendor logos: no disk cache; outside the DNS-fallback client
- **Category / Severity:** Performance/reliability · **Low**
- **File / Location:** `customer_screen.dart:2625` (`Image.network`)
- **Current problem:** logos re-download each session; on networks that cannot resolve `*.supabase.co` the images fail even though the rest of the app now works through the DNS fallback.
- **Recommendation:** a cached image (disk cache) via the shared client or an `HttpOverrides` using the same connection factory.
- **Effort:** Small–Medium.

#### PERF-08 — Oversized bundled images
- **Category / Severity:** Size · **Low**
- **File / Location:** `assets/images/chinar.png` 2.1 MB, `konnectkashmir.png` 1.36 MB (both decoded at ≤ 900/384 px)
- **Recommendation:** re-encode (WebP/optimised PNG) to a few hundred KB each, or use vector.
- **Expected benefit:** ≈ 3 MB smaller install (estimate). **Effort:** Small.
- **Validation:** `flutter build apk --analyze-size`.

#### PERF-09 — Eager lead rendering (Potential)
- **File / Location:** `my_business_tab.dart` `_leadsPanel` builds every lead in a `Column`.
- **Recommendation:** lazy list or "show more" when a business has many leads. **Effort:** Small. **Severity:** Low.

#### PERF-10 — Request latency is dominated by distance to the backend (infra)
- **Category / Severity:** Performance · **Medium** · Observed in an earlier session (not re-measured here)
- **Evidence:** ~0.35–0.4 s per request with ~3 ms database time was measured earlier in this project.
- **Recommendation:** evaluate moving the Supabase project to the Mumbai region; combine requests (PERF-03).
- **Risk:** migration planning/downtime (backend). **Effort:** Medium–Large.
- **Validation:** same request timing before/after from a phone in Kashmir.

---

### Architecture & Code Quality

#### ARCH-01 — ≈4,700 lines of unreachable screens
- **Category / Severity:** Maintainability · **Medium** · Confirmed (code + analyzer)
- **File / Location:** `dashboard_screen.dart` (1,306), `vendor_dashboard.dart` (1,716), `profile2.dart` (667), `home_screen.dart` (586), `role_selection.dart` (341), `transaction_history_screen.dart` (100)
- **Evidence:** `HomeScreen` and `TransactionHistoryScreen` are imported nowhere; `RoleSelectionScreen` is only an *unused import* in `main.dart`; `DashboardScreen`/`VendorDashboardScreen`/`profile2.ProfileScreen` are reachable only from `_handleNavTap`/`_buildBottomNavBar` (`customer_screen.dart:1086–1170`, flagged unused by the analyzer) and from routes (`/dashboard`, `/customer`, `/vendors`, `/jobs`, `/register-vendor`) that **no code navigates to** (all named navigation in the app is `/login` and `/home`). They also carry 50+ hard-coded English strings, duplicated anon keys and body logging.
- **Recommendation:** delete after one more reachability check (history keeps them); remove the dead routes from `main.dart`.
- **Expected benefit:** ≈ 19.5 % less code to read/ship; fewer false findings; `share_plus` becomes removable.
- **Risk:** low (verify with analyzer + a build + a smoke run). **Effort:** Small–Medium.
- **Validation:** `flutter analyze`, `flutter build apk`, manual walk of every tab.

#### ARCH-02 — `ApiService`: 93 of 116 public methods are unused
- **Category / Severity:** Maintainability/attack surface · **Medium** · Confirmed (code)
- **File / Location:** `services/api_service.dart`
- **Evidence:** a scan of all of `lib/` (also following calls between methods) finds only 23 of 116 public methods reachable from live code; the other 93 (about 1,320 lines, 66 % of the 2,012-line file) are not (e.g. `approveVendor`, `deleteAdminUser`, `blockUser`, `updateUserCredits`, `deleteSelf`, `syncToSheets`, `adminPinAuth`, `phoneAuthFix`, all job/report/admin helpers); `setSession()` in `AuthProvider` has no callers and defaults `role = 'admin'`.
- **Current problem:** admin-style operations ship in every consumer binary. The backend must (and probably does) refuse them for normal users, but dead privileged client code is a risk and a distraction.
- **Recommendation:** delete unused methods; split the remainder by domain (auth, vendors, credits/ads, leads) returning a small typed `ApiResult`. Keep `ApiService` as the concept — no new architecture.
- **Effort:** Medium. **Risk:** low.
- **Validation:** analyzer + tests.

#### ARCH-03 — Very large files and classes
- **Severity:** Maintainability · **Medium** (do incrementally)
- **File / Location:** `customer_screen.dart` 3,450 lines / ~70 fields in one `State`; `vendor_screen.dart` 1,241; `deen_tab.dart` 1,143.
- **Recommendation:** only when touching them: extract `VendorCard`, filter sheet, report dialog and the reveal flow into separate files/classes (also enables PERF-02). Keep Provider + `ChangeNotifier`.
- **Effort:** Large (spread out). **Risk:** medium per step.

#### ARCH-04 — Untyped maps; `json_serializable` toolchain unused
- **Severity:** Maintainability · **Low**
- **Evidence:** `dynamic vendor`, `Map<String,dynamic>` everywhere; `json_annotation`, `json_serializable`, `build_runner` declared with no generated code.
- **Recommendation:** optional small hand-written models for vendor, lead, ad, transaction; or drop the unused toolchain (DEP-01).

#### ARCH-05 — Errors as strings
- **Severity:** Maintainability · **Low**
- **Evidence:** `err.contains('(401)')`, `ErrorRetry.isOfflineError` text matching.
- **Recommendation:** typed failures (status, kind) from the API layer.

#### ARCH-06 — Analyzer debt (mechanical)
- **Severity:** Low · Confirmed (analyzer)
- **Evidence:** 353 issues: 254 `deprecated_member_use` (mostly `withOpacity`), 38 `curly_braces_in_flow_control_structures`, 10 `unused_import`, 9 `use_build_context_synchronously`, 9 `unused_element`, 5 `unused_local_variable`, `main.dart:61` unused global `supabase`, deprecated `textScaleFactor`, `Share`, `Form value`, `anonKey`.
- **Recommendation:** fix after ARCH-01 removes most of them; replace `withOpacity` with `withValues(alpha:)`.

#### ARCH-07 — Minimal lint set, no CI
- **Severity:** Low · Confirmed
- **Evidence:** `analysis_options.yaml` only includes `flutter_lints`; no `.github`/CI config.
- **Recommendation:** add `flutter analyze` + `flutter test` on every push; enable `avoid_print`, `unawaited_futures`, `use_build_context_synchronously` as warnings→errors.

---

### UI/UX

#### UX-01 — "Saved providers only" cannot be used
- **Severity:** Medium · Confirmed (code + analyzer)
- **File / Location:** `customer_screen.dart:1247` (`_toggleFavorite` unreferenced), `:2529` (`isFav` unused local), filter sheet `SwitchListTile(title: savedProvidersOnly)`
- **Current problem:** the filter exists but nothing can add a provider to "saved", so enabling it returns an empty list.
- **Recommendation:** restore a save control on the vendor card, or remove the filter and `_favorites*` state.
- **Effort:** Small. **Validation:** save two providers → filter shows exactly those.

#### UX-02 — Add-credit area hides failures
- **Severity:** Medium · Confirmed (code)
- **File / Location:** `widgets/add_credit_section.dart:49–70`
- **Current problem:** `catch (_) {}`; `getAvailableAds()` returns `[]` on error, so offline looks like "No ads right now"; `_credits = credits` may be `null` and the balance skeleton never resolves.
- **Recommendation:** error state with `ErrorRetry`; keep the previous balance.
- **Effort:** Small.

#### UX-03 — Notification permission asked right after sign-in
- **Severity:** Medium · Confirmed (code)
- **File / Location:** `notification_service.dart:189` (`requestPermission()` inside `_register`)
- **Recommendation:** ask in context (e.g. after the first unlock/business listing) with a one-line explanation; on iOS a refusal cannot be re-asked.
- **Effort:** Small–Medium.

#### UX-04 — Accessibility is thin
- **Severity:** Medium · Confirmed (code, counts) + Device-verify
- **Evidence:** 1 `Semantics(`, 0 `semanticLabel`, 5 `tooltip:` versus 36 `GestureDetector(` and 34 `InkWell(`; the phone field has only a visual label; secondary text uses 55–70 % opacity at 12–13 sp; several fixed heights (`SizedBox(height: 44)` chips, card header estimates, a deprecated `textScaleFactor > 1.2` check at `customer_screen.dart:1126`).
- **Recommendation:** give every icon-only/tap-only control a label/role (≥ 48 dp targets), use `labelText` on fields, test at 200 % text scale and with TalkBack/VoiceOver, check light-mode contrast ≥ 4.5:1 for body text.
- **Effort:** Medium. **Validation:** Accessibility Scanner (Android), Xcode Accessibility Inspector, font-scale 2.0 run.

#### UX-05 — Phone entry polish
- **Severity:** Low · Confirmed (code)
- **Recommendation:** digits-only formatter, `maxLength: 10`, `textInputAction: done` + submit, `autofillHints: [telephoneNumber]`, optionally require a 6–9 first digit.
- **Effort:** Small.

#### UX-06 — Language picker after every sign-in
- **Severity:** Low · Confirmed (by earlier request)
- **File / Location:** `otp_ver.dart:144–148`
- **Note:** this was a requested behaviour; consider skipping when `LocaleProvider.hasChosen` is true to save a step.

#### UX-07 — Orientation is inconsistent
- **Severity:** Low · Confirmed (code) + Device-verify
- **File / Location:** manifest/plist allow rotation; `ad_watch_dialog.dart:65` sets `portraitUp` on dispose, so after the first ad the whole app is portrait-locked.
- **Recommendation:** decide once: lock portrait in `main()` (and manifest/plist) or support landscape properly.
- **Effort:** Small.

#### UX-08 — Legal text is English-only
- **Severity:** Low · Content decision.

#### UX-09 — Fixed splash length — see PERF-04.

#### UX-10 — Token drift on the login screen
- **Severity:** Low · Confirmed (code)
- **Evidence:** `login_screen.dart:138–150` defines ~8 local colours (dark palette used even in light mode) rather than theme tokens. **Recommendation:** map to `AppColors`/`ColorScheme`.

#### UX-11 — Prayer times not recomputed after midnight
- **Severity:** Low · Potential
- **File / Location:** `deen_tab.dart` (`_day` fixed after bootstrap; `_now` ticks)
- **Recommendation:** re-bootstrap when the date changes.

#### UX-12 — Misleading district fallback
- **Severity:** Low · Confirmed (code)
- **File / Location:** `customer_screen.dart:552` (`_loadDistricts` catch uses fake ids `'sr'`, `'br'`…; `getDistricts()` swallows errors so the catch is unreachable).
- **Recommendation:** delete the fallback.

---

### Platform (Android / iOS)

#### PLT-01 — iOS: `tel:`/`mailto:` guarded by `canLaunchUrl` without declared schemes
- **Severity:** Medium · Potential — **Device-verify (iOS)**
- **File / Location:** `my_business_tab.dart:101`, `customer_screen.dart:2815`, `static/contact_screen.dart:277,282`, `widgets/lead_contact_sheet.dart:84`; `ios/Runner/Info.plist` `LSApplicationQueriesSchemes` lists only Facebook schemes.
- **Current problem:** on iOS `canLaunchUrl` returns `false` for schemes not listed in `LSApplicationQueriesSchemes`, so Call and e-mail buttons silently do nothing.
- **Recommendation:** add `tel` and `mailto` (and `sms` if used) to the plist, or call `launchUrl` directly inside `try/catch`. (Android already declares them in `<queries>`.)
- **Effort:** Small. **Validation:** tap Call/e-mail on a physical iPhone.

#### PLT-02 — iOS foreground pushes may appear twice
- **Severity:** Medium · Potential — **Device-verify (iOS)**
- **File / Location:** `notification_service.dart:147–149` (`setForegroundNotificationPresentationOptions(alert: true …)` **and** `onMessage.listen(_showLocal)`)
- **Current problem:** on iOS the system banner and the app's local notification can both show for one message. Android is correct (the system shows nothing in foreground).
- **Recommendation:** on iOS either set presentation `alert:false` or skip `_showLocal` for foreground messages that have a `notification` part.
- **Effort:** Small. **Validation:** send one push to an iPhone with the app open (needs the APNs key uploaded).

#### PLT-03 — `aps-environment = development` in the shared entitlements file
- **Severity:** Medium · Confirmed (config) — **Device-verify**
- **File / Location:** `ios/Runner/Runner.entitlements` (used by Debug/Release/Profile)
- **Recommendation:** inspect the archived IPA (`codesign -d --entitlements :-`) and confirm `production`; if not, use per-configuration entitlements.
- **Effort:** Small.

#### PLT-04 — `Podfile`/`Podfile.lock` not in the repository; deployment target 13.0
- **Severity:** Medium · Confirmed (config) — **Device-verify**
- **Evidence:** no `ios/Podfile` tracked; `IPHONEOS_DEPLOYMENT_TARGET = 13.0`. Current Firebase iOS SDK majors likely require iOS 15 (confirm in the plugin docs).
- **Recommendation:** commit `Podfile` and `Podfile.lock`; set the platform to the highest minimum required by the pods; run `pod install` on a clean Mac.
- **Effort:** Small.

#### PLT-05 — Android build files are machine-specific
- **Severity:** Low · Confirmed
- **File / Location:** `android/gradle.properties` is tracked and sets `org.gradle.java.home=C:/Program Files/Java/jdk-17`; `android.enableJetifier=true` is probably unnecessary.
- **Recommendation:** remove the hard-coded path (use `JAVA_HOME`); test disabling Jetifier.
- **Effort:** Small.

#### PLT-06 — Meta SDK auto-initialises on both platforms
- **Severity:** Low · Confirmed — see SEC-08.

#### PLT-07 — Desktop/web scaffolding present
- **Severity:** Low · `web/ windows/ linux/ macos/` (66 files) while the app targets Android/iOS and uses plugins that do not support all of them. Remove or keep deliberately.

#### PLT-08 — Android/iOS parity notes
- Android: min SDK 24, target 36, permissions minimal (internet, coarse/fine location, notifications), no deep links, rotation allowed.
- iOS: iOS 13 target in the project, `remote-notification` background mode present, location usage string present, no tracking-transparency prompt (only matters if the IDFA is used).

---

### Dependencies & Maintainability

#### DEP-01 — Unused packages
- **Severity:** Low · Confirmed (imports)
- `firebase_auth` (0 imports; links the native Firebase Auth SDK on both platforms although the app uses its own token flow), `json_annotation`/`json_serializable`/`build_runner` (no generated code), `cupertino_icons` (0), `share_plus` (only in the unreachable dashboards → removable with ARCH-01). **Do not remove `flutter_secure_storage`** — it should be *used* (SEC-01).
- **Recommendation:** remove after ARCH-01; rebuild both platforms. **Effort:** Small. **Validation:** clean build + size comparison.

#### DEP-02 — Version drift (do not upgrade blindly)
- **Severity:** Low · Confirmed (`flutter pub outdated`)
- Behind: `flutter_local_notifications` 20.1 → 22.x, `facebook_app_events` 0.28 → 0.30, `share_plus` 12 → 13, `youtube_player_flutter` 9.1.3 → 10.0.1, `flutter_secure_storage` 10.3 → 11.2, `flutter_lints` 5 → 6; `supabase_flutter` 2.18.0 → 2.18.3 (patch, low risk). `intl: any` in `pubspec.yaml` should be pinned (`^0.20.2`).
- **Recommendation:** patch-level updates now; majors one at a time with release notes and a device run.

#### DEP-03 — `pubspec.lock` is git-ignored
- **Severity:** Low · Confirmed (`.gitignore` has `*.lock`)
- **Recommendation:** commit `pubspec.lock` for an application so builds are reproducible.

#### DEP-04 — Tracked IDE files
- **Severity:** Low · `konnect_kashmir.iml`, `android/konnect_kashmir_android.iml`, `devtools_options.yaml`. Add to `.gitignore`.

#### TEST-01 — Thin automated tests
- **Severity:** Medium · Confirmed
- **Evidence:** 2 meaningful files (Qibla maths, prayer settings, audio URLs, language-picker behaviour; 21 tests) + a placeholder asserting `true`. Nothing covers sign-in/session refresh, credits, unlock, ad claim, vendor submit, pagination or response parsing. `sharedHttp` is a global, which makes the API layer hard to test.
- **Recommendation:** make the client injectable (constructor parameter, default `sharedHttp`) and add tests for: `AuthProvider` (single-flight refresh, restore, expiry), credit fallback (API-01), vendor submit steps (API-02), `LegalBody` accordion, `ErrorRetry`.
- **Effort:** Medium.

#### REL-01 — New DNS-fallback client is untested
- **Severity:** Low · Confirmed
- **File / Location:** `services/shared_http.dart` (added during this working session)
- **Note:** it falls back to Cloudflare/Google DNS-over-HTTPS only when the phone's DNS fails, then makes the TLS handshake against the real host name. It was verified on a phone on mobile data, but it has no unit tests and `Image.network` does not use it (PERF-07). Hostnames are revealed to the DoH resolver only in the failure case.
- **Recommendation:** add tests (DNS success, DNS failure → DoH, proxy), keep the 5-minute cache.

---

## E. Prioritized Improvement Table

| Order | ID | File | Severity | Effort | Expected benefit |
|---|---|---|---|---|---|
| 1 | SEC-02 | `providers/auth_provider.dart` | High | S | Stop logging credentials/PII |
| 2 | API-01 | `services/api_service.dart`, `live_sync.dart` | High | S | No false "0 credits" |
| 3 | API-06 | `auth_provider.dart`, `otp_ver.dart`, `login_screen.dart` | Medium | S | No stuck sign-in / dispose errors |
| 4 | API-04 | `services/shared_http.dart` | Medium | S | Every call ends (timeout) |
| 5 | PERF-01 | `customer_screen.dart`, `api_service.dart` | Medium | S | −3 requests / ~100 KB per Home load |
| 6 | SEC-01 | `auth_provider.dart`, manifest | High | M | Encrypted tokens, no backup leak |
| 7 | API-02 | `vendor_screen.dart` | High | M | No silent category loss |
| 8 | PERF-04 | `main.dart`, `splash_screen.dart` | Medium | S–M | Faster time-to-interactive |
| 9 | UX-02 | `add_credit_section.dart` | Medium | S | Honest loading/error states |
| 10 | UX-01 | `customer_screen.dart` | Medium | S | Remove dead-end filter |
| 11 | PLT-01 | `ios/Runner/Info.plist` | Medium | S | iOS Call/e-mail work |
| 12 | SEC-08 | `privacy_screen.dart`, consent | Medium | S–M | Store/DPDP alignment |
| 13 | API-05 | new request helper | Medium | M | Consistent 401 recovery |
| 14 | PERF-02 | `customer_screen.dart` | Medium | M | Cost independent of pages loaded |
| 15 | ARCH-01/02, DEP-01 | legacy screens, `api_service.dart`, `pubspec.yaml` | Medium | M | −~6k lines, fewer deps |
| 16 | API-03 | `vendor_screen.dart` | Medium | M | Locality list always current |
| 17 | PERF-03 | `customer_screen.dart` | Medium | M | Fewer/lazier startup requests |
| 18 | SEC-03/04/05 | backend | Medium (may be High) | M | Verify server-side protections |
| 19 | PLT-02/03/04 | iOS config/code | Medium | S | iOS release correctness |
| 20 | UX-04, UX-03 | many | Medium | M | Accessibility, permission timing |
| 21 | TEST-01, ARCH-07, DEP-03 | tests/CI | Medium | M | Regression safety |
| 22 | PERF-05/07/08/09, SEC-06/09/10, PLT-05, remaining Low | various | Low | S | Polish and hygiene |

---

## F. Quick Wins (safe, small, meaningful)

1. Remove or `kDebugMode`-guard the logs in `auth_provider.dart:144,187` and `notification_service.dart:227` (SEC-02).
2. Return `null` from `getUserCredits` on failure (API-01).
3. Replace `on Exception` with `catch (e)` and move `mounted` checks before `setState` (API-06).
4. Add a default timeout inside `shared_http.dart` (API-04).
5. Delete the `getPlatformStats` call from Home (PERF-01).
6. Add `tel` and `mailto` to `LSApplicationQueriesSchemes` (PLT-01).
7. Import `kSupabaseUrl`/`kSupabaseAnonKey` everywhere (SEC-06).
8. Commit `pubspec.lock`; pin `intl`; remove `org.gradle.java.home` (DEP-03, DEP-02, PLT-05).
9. Add `TickerMode` around non-active tabs (PERF-05).
10. Show an `ErrorRetry` state in `AddCreditSection` (UX-02).
11. Remove the "Saved providers only" switch (or restore saving) (UX-01).
12. Re-encode `chinar.png` and `konnectkashmir.png` (PERF-08).

---

## G. Architectural Recommendations

**Keep as is (it works well):**
- Provider + `ChangeNotifier` (`AuthProvider`, `ThemeProvider`, `LocaleProvider`, `LiveSync`). Do **not** introduce BLoC/Riverpod/Clean Architecture.
- Theme tokens (`AppColors`, `AppText`, `AppButtons`, `AppRadius`) and the shared widgets.
- Single-flight token refresh, `LiveSync` credit de-duplication, the unlock reconcile logic, request sequencing (`reqId`) on the Home list, `IndexedStack` with lazily built tabs, `ForceLtr`/`EnglishOnly` handling, the Deen compass isolation, the localization workflow (all keys present).

**Refactor with a clear benefit:**
- Delete unreachable screens and unused API methods (ARCH-01/02).
- One authenticated-request helper with default timeout + one 401 refresh (API-04/05).
- Extract `VendorCard` and the reveal/unlock flow from `customer_screen.dart` (ARCH-03/PERF-02).
- Make the HTTP client injectable for tests (TEST-01).

**Do not refactor without stronger evidence:**
- Adding repositories/use-case layers, replacing `Map<String,dynamic>` wholesale, replacing `supabase_flutter` (decide only after PERF-04 measurement), restructuring Deen (it is already clean).

---

## H. Testing and Verification Plan

**Automated**
- Unit: `AuthProvider` (restore, expiry, single-flight refresh, error shapes), `ApiService` with a fake `http.Client` (credits fallback, listing parse, error mapping), credit/unlock reconcile, vendor submit with a failing third call.
- Widget: login validation, OTP unmount-during-request, `AddCreditSection` error state, `LegalBody` accordion, `ErrorRetry`.
- CI: `flutter analyze`, `flutter test` on every push; fail on warnings.

**Performance (profile mode, release-like device)**
- Startup: `flutter run --profile --trace-startup` → `timeToFirstFrameMicros`; stopwatch from icon tap to interactive Home.
- Home: DevTools Performance — frame build/raster time while scrolling to ~200 vendors; "Track widget rebuilds"; network tab for request count/bytes on a cold Home load (target: remove stats, defer ads).
- Memory: DevTools Memory after 5 minutes switching tabs; confirm no growth; check hidden-tab animation cost with the Performance overlay.
- Size: `flutter build apk --analyze-size` before/after asset and dependency changes.

**Security/reliability**
- Release build + `adb logcat` after sign-in: no credentials/phones.
- Device file check: tokens absent from `shared_prefs` after SEC-01; `adb backup` empty.
- Airplane-mode and 0 kbps runs of: sign-in, Home, unlock, claim, business save (spinners must end; no "0 credits").
- Backend (two accounts): cross-read/cross-write attempts (SEC-04), OTP attempt limit (SEC-05), direct `claim-ad-credits` call (SEC-03).

**Platform**
- iPhone: Call/e-mail buttons, foreground push duplication, archived-IPA entitlements, clean `pod install`.
- Android: rotation, 200 % font scale, TalkBack walk of sign-in → unlock.

---

## I. Implementation Plan (independent phases)

| Phase | Content | Depends on | Risk |
|---|---|---|---|
| 0 | CI (analyze + test), commit `pubspec.lock`, pin `intl`, ignore IDE files | — | Low |
| 1 | SEC-02, API-01, API-06, API-07, SEC-06 (constants), SEC-09 mapper | 0 | Low |
| 2 | API-04 timeout wrapper, API-05 401 helper, UX-02 error state | 1 | Low–Med |
| 3 | PERF-01 remove stats, PERF-04 adaptive splash/lazy Supabase init, PERF-05 TickerMode, PERF-06 cursor, PERF-08 images | 0 | Low–Med |
| 4 | API-02 + API-03 vendor save (client checks first; transactional RPC needs backend) | 2 | Medium |
| 5 | ARCH-01/02 delete dead code, DEP-01 remove packages | 0 | Low–Med |
| 6 | PERF-02/03 Home list virtualization and request trimming (profile before/after) | 5 | Medium |
| 7 | PLT-01..05 iOS/Android config pass | — | Low |
| 8 | SEC-01 secure token storage + `allowBackup` (with migration) | 1, 2 | **Higher** |
| 9 | Backend verification & hardening: SEC-03/04/05, API-08/09, PERF-10 | — | Medium |
| 10 | UX-04 accessibility pass, UX-03 permission timing, UX-01/05/07 | 6 | Low–Med |
| 11 | Optional: ARCH-03/04 incremental refactors | 6 | Medium |

High-risk steps: Phase 8 (user sessions), Phase 6 (list behaviour), Phase 9 (policy changes can break the app's own writes — test on a staging copy).

---

## J. Overall Assessment

**Top 10 improvements worth making**
1. Stop logging credentials/PII (SEC-02).
2. Never show a failed request as "0 credits" (API-01).
3. Make business save safe and complete (API-02, API-03).
4. Encrypt stored tokens and disable backup of them (SEC-01).
5. Remove the unused stats calls and trim the Home startup (PERF-01, PERF-03).
6. Shorten and de-block startup (PERF-04).
7. Default timeouts and one 401 policy (API-04, API-05).
8. Virtualize the Home list and extract `VendorCard` (PERF-02, ARCH-03).
9. Delete ≈4.7k lines of unreachable screens, ~1.3k lines (93 methods) of unused API code and 5 unused packages (ARCH-01/02, DEP-01).
10. iOS correctness pass (PLT-01..04) and verify server protections (SEC-03/04/05).

**Most likely to make the app noticeably faster:** PERF-04 (≥ 1 s at launch), PERF-01 + PERF-03 (fewer requests per Home load), PERF-02 (smoothness after many pages), and — largest if latency dominates — PERF-10 (backend region).

**Screens needing the most UI/UX attention:** Home (`customer_screen.dart`), Add-credit/ads, Business registration (`vendor_screen.dart`), Sign-in/OTP (input handling, accessibility), then My Business (lead attribution, error text).

**Fix before the next release:** SEC-02, API-01, API-02, API-06; SEC-01 (or at least `allowBackup`) if sessions are a concern; PLT-01 if iOS ships; SEC-08 wording before any store review; and confirm SEC-03/04/05 with the backend owner.

**Optional:** ARCH-03/04 refactors, UX-05..UX-12 polish, PERF-07/09, DEP-02 upgrades, PLT-07.

**Leave alone — it already works well:** the theme/token system, localization completeness, lifecycle hygiene (controllers/timers disposed), `AuthProvider` refresh design, `LiveSync`, the unlock reconcile flow, the Deen compass/caching approach, `ErrorRetry`, the legal accordion/shared chrome, and the no-cleartext, anon-RLS-locked backend surface.

---

*End of report. No code was changed. Waiting for your approval and a choice of phases before implementing anything.*
