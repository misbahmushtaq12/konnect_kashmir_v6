# Firebase Analytics

What the app sends to Firebase Analytics, and how to read it. The code is
`lib/services/app_analytics.dart`; it is started in `main.dart` right after the first
screen is shown.

(`lib/services/analytics_service.dart` is a different thing: it records searches in the
backend's own tables, as the website does. Both run.)

## One thing to switch on first

Google Analytics must be **enabled for the Firebase project** (`konnect-kashmir1`),
otherwise Firebase accepts the events and throws them away. Today the config files say it
is off: `GoogleService-Info.plist` has `IS_ANALYTICS_ENABLED = false` and
`google-services.json` has no `analytics_service` block.

1. Firebase console -> Project settings -> Integrations -> Google Analytics -> Enable
   (create or choose a GA4 property).
2. Download the new `google-services.json` and `GoogleService-Info.plist` and replace
   `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
   (`IS_ANALYTICS_ENABLED` must then be `true`.)
3. Build and ship a new app version. Data starts to arrive from that version only.

## What is sent

| Event / property | When | Fields |
|---|---|---|
| `screen_view` | A screen comes into view (the user journey), including going back to the one underneath. Named after the route or the widget: `login`, `business_details`, `home`, `my_business`, `deen`, `profile`, ... | `screen_name` |
| `app_open` | Every start, and coming back after 30+ minutes away | `how`: `launch` or `resume` |
| `daily_open` | **Once per calendar day** (the phone's day), however often the app is opened | `streak` (days in a row), `days_since_first` (age of the install) |
| `login` / `sign_up` | After the OTP is accepted (`sign_up` for a new account) | `method`: `phone_otp` |
| `logout` | Signed out (also when the session expired) | - |
| `view_business` | A business page opened (card, or a shared link) | `business_id`, `category` |
| `contact_business` | Call or WhatsApp tapped | `method`, `business_id` |
| `unlock_contact` | A contact was unlocked with credits | `business_id` |
| `share` | The share sheet was opened for a business | `content_type`, `item_id`, `method` |
| `search` | A search ran | `category`, `results_count`, `has_text` |
| `prayer_alarm_toggle` | The prayer beep was switched on or off | `enabled` (1/0) |
| user id | Signed in | the account's id (no name, phone or e-mail) |
| user property `user_role` | Signed in | `customer`, `vendor`, `admin`, ... |
| user property `app_language` | Start and on change | `en`, `hi`, `ur` |

Firebase also records on its own: `first_open`, `session_start`, `user_engagement`,
`app_update`, active users (daily/weekly/monthly) and retention.

**Never sent:** names, phone numbers, e-mail addresses, the words typed in search, or
anything else a person wrote.

## Reading it in the Firebase console

* **Daily opens / daily users:** Analytics -> Dashboard (active users), or Reports ->
  Engagement -> Events -> `daily_open` (count per day). Retention: Reports -> Retention.
* **User journey:** Analytics -> Explore -> *Path exploration* (start from `screen_view`
  -> *Screen name*), or Reports -> Engagement -> Pages and screens. For a funnel (for
  example `view_business` -> `contact_business` -> `unlock_contact`), use Explore ->
  *Funnel exploration*.
* **Mark a parameter as reportable:** to break events down by `category`, `method` or
  `screen_name`, register them as custom dimensions (Admin -> Custom definitions). Only
  `screen_name` is available without that.
* **Checking it works, live:** DebugView. On Android:
  `adb shell setprop debug.firebase.analytics.app com.mediamosiac.konnect_kashmir`,
  then open the app and watch Analytics -> DebugView. Switch off with
  `adb shell setprop debug.firebase.analytics.app .none.`
  On the phone itself, `adb shell setprop log.tag.FA VERBOSE` and
  `adb logcat -s FA` shows each event as it is logged.

## Adding another event

`AppAnalytics.instance.event('name', {'field': value})` - names in `snake_case`, at most
40 characters, at most 25 fields, text at most 100 characters (longer is cut). Prefer a
small named helper in `AppAnalytics` for anything used in more than one place, and
never put a person's own words in a field.

## Notes

* Screen names for pages without a route name are read from the widget's class name
  (`BusinessDetailsScreen` -> `business_details`): only names ending in `Screen`, `Tab`
  or `Page` are used. An obfuscated build (`--obfuscate`) cannot be read this way; such a
  screen is skipped, not logged as rubbish. Name the class normally, or give its route a
  name, to be sure.
* Store listings: collecting analytics must be reflected in the privacy policy, Google
  Play's Data safety form and Apple's App Privacy answers.
