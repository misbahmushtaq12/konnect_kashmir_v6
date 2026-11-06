# Opening the app from the new-lead SMS link — setup

## The link for the SMS template

```
https://konnectkashmir.com/go?utm_campaign=new_lead
```

(No `www.` — see "Why no www" below. Optionally add `&utm_source=sms`; the website
logs `utm_source`, `utm_medium` and `utm_campaign` for every click.)

`/go` is a page that already exists on the website. It looks at the phone and
sends it to the App Store (iPhone) or Google Play (Android), and records the click.

| Situation | What the link does |
|---|---|
| **Today** (before the steps below) | Android → Google Play page, iPhone → App Store page (it shows **Open** if the app is installed). Desktop → the website home. No 404. |
| **After the steps below** | A phone that has the app opens the **app directly, on My Business** (where the leads are). A phone without the app still goes to the store. |

So the template can be changed now, and it keeps working and gets better when the
rest is done: the SMS never has to change again.

The older link `https://www.konnectkashmir.com/vendor/dashboard` is not a page on
the website (it shows the site's 404), so it should not be used in the SMS.

## What is already done in the app

* Android: verified link filter for `konnectkashmir.com` on `/go`, `/vendor/dashboard` and `/business/`.
* iPhone: Associated Domains entitlement for `konnectkashmir.com`.
* Someone who is **signed in**: `/go?utm_campaign=new_lead` opens **My Business**
  (where the leads are). Any other `/go` link just opens the app.
* Someone who is **signed out**: the app opens on the sign-in screen, and after signing
  in they see **Home** as usual. Nothing about the link is kept for after sign-in.
  (By decision of the app owner; the original request was My Business after sign-in.)
* **Shared businesses.** The share icon on a business card shares
  `https://konnectkashmir.com/business/<id>`. That is a real page on the website (its
  `/business/:id` route loads the business whose `vendors_public.id` is in the address), so
  someone without the app sees the business there. A phone that has the app opens the **app
  on that business's details screen** (the same screen a business card opens). Someone who is
  signed out signs in first and then sees it. Android needs nothing more from the website; **iPhone
  needs one line added to the apple-app-site-association file** (below).

## Status on 6 Nov 2026 (checked over the network and on an Android 14 emulator)

| Piece | State |
|---|---|
| `https://konnectkashmir.com/.well-known/assetlinks.json` | **Live and correct**: HTTP 200, `application/json`, no redirect, package `com.mediamosiac.konnect_kashmir`, both fingerprints (Play app signing `21:FA:63:…` and upload key `F3:FA:B6:…`). Google's Digital Asset Links API lists both. |
| `https://konnectkashmir.com/.well-known/apple-app-site-association` | Live (HTTP 200, `application/json`, no redirect, Apple's CDN has it) **but it does not contain `/business/*`**: it only lists `/go` and `/vendor/dashboard*`. So **an iPhone never opens the app for a shared business**. The file in `docs/well-known/` already has the line; the website still serves the older copy. **This is the one thing left to publish.** |
| Android app (manifest, build 13 and later) | Has the verified `/business/` filter. Build 13 (upload-key signed) installed on an Android 14 emulator: `pm get-app-links` says `konnectkashmir.com: verified`, and the link opens the app (no chooser). |
| Flutter | Cold start and warm start both open the exact business (tested on the emulator, below). |

### Why a shared business link opened the website

* **Android, any build not signed by a key in `assetlinks.json`** (the debug build from VS Code /
  Android Studio / `flutter run`, signed `08:F9:18:0B…`, or anything else): Android marks the domain
  `1024` (verification failed) and hands the link to the browser. Reproduced on the emulator and the
  same state is on the phone that has the debug build. The same build signed with the upload key is
  `verified` and opens the app.
* **Android, a phone that installed the app while `assetlinks.json` was not on the website yet (it was
  404 in October), or has a build older than the `/business/` filter**: it stays unverified until the app is
  updated (Android only re-checks at install / update). Update the app from Play.
* **iPhone**: the website's `apple-app-site-association` has no `/business/*` entry (above).
* A link typed or pasted into a browser's address bar never opens the app on either platform; it must be
  tapped in a message / chat / note (see "Check it").

## What is left

### 1. Proof files on the website (so the phone opens the app, not the browser)

The phone only opens the app after the website proves the app belongs to it, with two
small files. `assetlinks.json` is live; `apple-app-site-association` is live but needs the
`/business/*` line (replace it with the copy below).

**Ready to upload, in this repository:**
`docs/well-known/assetlinks.json` and `docs/well-known/apple-app-site-association`.
Put them on the website at `/.well-known/assetlinks.json` and
`/.well-known/apple-app-site-association` (in most website projects that is the
`public/.well-known/` folder, whose files are served as they are).
`assetlinks.json` already holds both fingerprints it needs:

* `21:FA:63:…:F4:29` — the **Play app signing key** (Google's key, which signs every
  version installed from Google Play). Read from the Play-installed APK on 16 Oct 2026
  with `apksigner verify --print-certs` (certificate `CN=Android, O=Google Inc.`). It
  can also be checked in Play Console → Test and release → App integrity → App signing.
* `F3:FA:B6:…:F8:B0` — the **upload key** (read from the local keystore), for release
  builds signed with it directly.

A build run from VS Code / Android Studio is signed with a debug key and will not
verify (see "Check it").

Phones do **not** follow redirects when they check these files. They must be served
directly (HTTPS, status 200, no redirect, no login) on the host the SMS link uses,
**`konnectkashmir.com`**. Serve them as static files before the site's catch-all page.

**Android — `/.well-known/assetlinks.json`**, Content-Type `application/json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.mediamosiac.konnect_kashmir",
      "sha256_cert_fingerprints": [
        "21:FA:63:64:EC:30:1E:E2:73:61:12:2A:7C:FC:E5:2E:8A:F7:5D:28:8D:B0:4C:A1:69:48:1F:02:D5:CD:F4:29",
        "F3:FA:B6:77:96:51:C6:FD:8D:E6:4F:A0:C1:35:7D:D8:CB:60:3D:77:01:9E:28:B5:09:8E:33:DB:99:21:F8:B0"
      ]
    }
  }
]
```

This is exactly what the website serves today (same two fingerprints; order does not matter), so
nothing needs to change for Android. Do not "improve" it: a wrong or missing fingerprint makes
Android treat the link as unverified and open the browser. To re-check the Play key:
Play Console → the app → Test and release → App integrity → App signing →
**App signing key certificate → SHA-256 certificate fingerprint**. If the app is ever signed
with another key (a new upload key, a different distribution), add that SHA-256 as another
entry **before** shipping it (`keytool -list -v -keystore <file>` or
`apksigner verify --print-certs <apk>`).

**iPhone — `/.well-known/apple-app-site-association`** (no file extension),
Content-Type `application/json`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["5VTU5RA37T.com.mediamosiac.konnectkashmirapp"],
        "components": [
          { "/": "/go" },
          { "/": "/vendor/dashboard*" },
          { "/": "/business/*" }
        ]
      }
    ]
  }
}
```

(`5VTU5RA37T` is the Apple Team ID, `com.mediamosiac.konnectkashmirapp` the bundle id.
App Store page: `https://apps.apple.com/in/app/konnect-kashmir/id6795522749`.)

On the Mac, before the iPhone build: Xcode → Runner → Signing & Capabilities → check
that **Associated Domains** lists `applinks:konnectkashmir.com`. If Xcode complains, add the capability once with
"+ Capability"; it also needs to be enabled for the app id in the Apple Developer
account (Xcode does this itself with automatic signing and a paid team).

### 2. New app builds

Both platforms need a **new app build** that has the `/business/` filter / entitlement
(Android: the filter was added on 26 Oct 2026; the build 13 APK was checked and has it, and
the Play version must be at least that new, see `pubspec.yaml` `version:`).
Phones with an older app keep going to the website. Android checks the files when the
app is installed or updated, so publish the website files **before** the build reaches
users. An iPhone build must be archived from Xcode on a Mac with the **Associated
Domains** capability (the entitlement is already in `ios/Runner/Runner.entitlements`).

### 3. Check it

Use a **release-signed** build for Android (installed from Play, or the signed release APK):
a debug build is signed with another key, is never verified, and always opens the browser.

* Website proof files (any computer):
  * `curl -sSI https://konnectkashmir.com/.well-known/assetlinks.json` and
    `curl -sSI https://konnectkashmir.com/.well-known/apple-app-site-association` must each
    answer `HTTP/… 200`, `content-type: application/json`, and **no** `location:` header.
  * `curl -s https://konnectkashmir.com/.well-known/apple-app-site-association` must contain
    `"/business/*"`.
  * Google's checker:
    `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://konnectkashmir.com&relation=delegate_permission/common.handle_all_urls`
    must list the package with both fingerprints.
  * Apple's CDN copy (what iPhones actually read, refreshed within about 6 hours):
    `curl -s https://app-site-association.cdn-apple.com/a/v1/konnectkashmir.com` must show
    `/business/*` too.
* Android:
  * `adb shell pm get-app-links com.mediamosiac.konnect_kashmir` must say
    `konnectkashmir.com: verified` (`1024` means verification failed: wrong signing key, or
    the files were not on the website when the app was installed; update/reinstall the app, or
    run `adb shell pm verify-app-links --re-verify com.mediamosiac.konnect_kashmir`).
  * App installed: `adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://konnectkashmir.com/business/<id>"`
    opens the app straight on that business, with no "Open with" chooser. Also tap the link
    in WhatsApp (see the steps in the hand-over report).
  * App not installed: the same link opens the website's business page in the browser.
* iPhone (a real iPhone with a build from Xcode / TestFlight; the simulator cannot test the
  CDN): delete and reinstall the app (the association is read at install), then tap the link in
  Messages, Notes or WhatsApp. A link typed or pasted into Safari's address bar, or tapped on a
  page of konnectkashmir.com itself, opens the website; that is how iOS behaves, not a fault.
  Long-press the link: the menu must offer "Open in Konnect Kashmir".

## Why no `www`

The app therefore declares only `konnectkashmir.com` (on Android 11 and older, one host that
fails verification makes the whole filter fail). `www.konnectkashmir.com` redirects (302) to `konnectkashmir.com`. Phones do not follow
redirects when they check the proof files, so a `www` link would never be verified and
would open in the browser. Using the address without `www` avoids that. If the SMS
provider/DLT needs the new address approved, that is the one template change; after it
nothing else in the SMS needs to change.
