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

* Android: verified link filter for `konnectkashmir.com` / `www.konnectkashmir.com`
  on `/go` and `/vendor/dashboard`.
* iPhone: Associated Domains entitlement for the same two hosts.
* The app turns `/go?utm_campaign=new_lead` into "open My Business"; any other `/go`
  link just opens the app. If the user is signed out, My Business opens right after
  sign-in.

## What is left

### 1. Proof files on the website (so the phone opens the app, not the browser)

The phone only opens the app after the website proves the app belongs to it, with two
small files. Today both return 404 on `konnectkashmir.com`.

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
        "PUT:THE:APP:SIGNING:KEY:SHA-256:HERE"
      ]
    }
  }
]
```

The fingerprint is **not** in the code. Copy it from Google Play Console: the app →
Test and release → App integrity → App signing →
**App signing key certificate → SHA-256 certificate fingerprint**.
(The *upload* key fingerprint can be added as a second entry; the app signing key is
the one that matters for the Play Store version.)

**iPhone — `/.well-known/apple-app-site-association`** (no file extension),
Content-Type `application/json`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["5VTU5RA37T.com.mediamosiac.konnectkashmirapp"],
        "components": [
          { "/": "/go", "comment": "get-the-app / new-lead SMS link" },
          { "/": "/vendor/dashboard*" }
        ]
      }
    ]
  }
}
```

(`5VTU5RA37T` is the Apple Team ID, `com.mediamosiac.konnectkashmirapp` the bundle id.
App Store page: `https://apps.apple.com/in/app/konnect-kashmir/id6795522749`.)

On the Mac, before the iPhone build: Xcode → Runner → Signing & Capabilities → check
that **Associated Domains** lists `applinks:konnectkashmir.com` and
`applinks:www.konnectkashmir.com`. If Xcode complains, add the capability once with
"+ Capability"; it also needs to be enabled for the app id in the Apple Developer
account (Xcode does this itself with automatic signing and a paid team).

### 2. New app builds

Both platforms need a **new app build** (the Android manifest and the iPhone
entitlements changed). Phones with an older app keep going to the store page. Android
checks the files when the app is installed or updated, so publish the website files
**before** the build reaches users.

### 3. Check it

* Link in a browser: goes to the store page (not a 404).
* Android: `adb shell pm get-app-links com.mediamosiac.konnect_kashmir` should say
  `verified` for `konnectkashmir.com`. Then
  `adb shell am start -a android.intent.action.VIEW -d "https://konnectkashmir.com/go?utm_campaign=new_lead"`
  should open the app on My Business.
* Google's checker:
  `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://konnectkashmir.com&relation=delegate_permission/common.handle_all_urls`
  must list the app.
* iPhone: `https://app-site-association.cdn-apple.com/a/v1/konnectkashmir.com` must
  return the JSON above. Apple caches it, so test with a fresh install on a real
  iPhone, and open the link from Messages or Notes (typing it in Safari's address bar
  does not open the app).

## Why no `www`

`www.konnectkashmir.com` redirects (302) to `konnectkashmir.com`. Phones do not follow
redirects when they check the proof files, so a `www` link would never be verified and
would open in the browser. Using the address without `www` avoids that. If the SMS
provider/DLT needs the new address approved, that is the one template change; after it
nothing else in the SMS needs to change.
