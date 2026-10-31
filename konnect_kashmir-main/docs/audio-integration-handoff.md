# Audio integration handoff (Konnect Kashmir app -> website)

Prepared 2026-10-27 from the app repository (`konnect_kashmir-main/`, version 1.0.5+7).
Nothing was changed in the code or in any backend for this report. Every statement in
section 1 and 2 was read in the code or checked live; section 5 onwards are **recommendations**
and are labelled as such. No credentials, keys or signed URLs are included.

> **Update 2026-10-29.** The website now has its own audio catalog in the same Supabase project as the app
> (tables `audio_reciters`, `audio_tracks`, `audio_play_events`, `deen_events`; found in the live website's
> public scripts; a public-key request returns **no rows** from `audio_reciters` and `audio_tracks`). That changes
> section 5/6: the catalog exists, it only needs the six reciters in it, and the app can read it later.
> The exact steps are in **`website-deen-audio-steps.md`**; where the two documents differ, use that one.

## 0. The short version

* The only audio *content* in the app is **Quran recitation**: full-surah MP3 files for **6 reciters x
  114 surahs = 684 files**, **streamed from a third-party host, `download.quranicaudio.com`**.
* **Konnect Kashmir stores none of it.** No audio file, no audio table, no storage bucket and no
  audio API of its own exists - not in the repository, not in the app bundle, not in Supabase, not in
  Firebase. The list of reciters is a hard-coded list in the Dart source.
* The "Duas" feature is **text only** (12 duas, Arabic + meaning in English/Hindi/Urdu); it has no audio.
  There are **no** naats, nasheeds, lectures or other Islamic audio in the app today.
* So there is **no shared backend audio source today**. The website can, however, use the **same public
  files and the same public surah-list API right now**, directly from the browser (checked: HTTP 200,
  `audio/mpeg`, range requests supported, `Access-Control-Allow-Origin: *`).
* The app records **no** audio statistics (no plays, no listening time, no completion).

## 1. Verified facts: what exists in the app

### 1.1 Audio files in the repository

Searched the whole repository for audio/video file types (mp3, m4a, aac, wav, ogg, flac, opus, mp4,
m3u8, caf, aiff, amr). The only two files found are **UI/alarm sounds, not content**:

| File | Purpose |
|---|---|
| `android/app/src/main/res/raw/prayer_beep.wav` | The prayer-time alarm beep (Android). 0.87 s, mono, 44.1 kHz. |
| `ios/Runner/prayer_beep.wav` | The same beep (iPhone). |

`pubspec.yaml` declares only `assets/images/` as assets (lines 94-95): **no audio is bundled in the app.**

### 1.2 Packages

* `just_audio: ^0.10.6` - the only audio player (`pubspec.yaml:57`).
* `youtube_player_flutter: ^9.1.1` - used only for **rewarded-ad videos** (`lib/screens/ad_watch_dialog.dart`),
  not for Deen audio.
* Not present: `audio_service`, `just_audio_background`, `audioplayers`, `audio_session`. So **no
  background playback, lock-screen controls or media notification**. (iOS `Info.plist` lists only
  `remote-notification` in `UIBackgroundModes`; Android has no foreground-service permission.)

### 1.3 Where audio appears in the app

One entry point: **Deen tab -> "Audio" tile** (`lib/screens/deen/deen_tab.dart:897-898`) ->
`AudioScreen` (`lib/screens/deen/audio_screen.dart`) -> `NowPlayingScreen`
(`lib/screens/deen/now_playing_screen.dart`). The l10n string `deenIslamicAudio` exists but is not used
anywhere in the code.

### 1.4 Where the audio comes from

**Metadata (what is listed)**

| Item | Source | Code |
|---|---|---|
| The 114 surahs (number, Arabic name, English name, translation, verse count) | Public API `https://api.alquran.cloud/v1/surah` (third party). Cached on the phone in SharedPreferences key `quran_surahs` after the first load. | `lib/screens/deen/quran_service.dart:6-29, 46-67` |
| The 6 reciters (display name + URL slug) | **Hard-coded** list `kReciters` | `lib/screens/deen/deen_data.dart:15-22` |
| Artwork | **None.** A generated pattern with the surah number is drawn instead ("Recitations have no cover") | `lib/screens/deen/now_playing_screen.dart:428` |
| Category / description | **None** in the app (everything is "Quran recitation") | - |

**The audio file**: built in code, never fetched from a Konnect API:

```dart
// lib/screens/deen/deen_data.dart:5-13
class Reciter {
  final String name;
  final String slug;
  const Reciter(this.name, this.slug);
  /// The files are numbered with three digits: 001.mp3 ... 114.mp3.
  String surahUrl(int surah) =>
      'https://download.quranicaudio.com/quran/$slug/${surah.toString().padLeft(3, '0')}.mp3';
}
```

| # | Reciter (as shown in the app) | slug (`kReciters`) | Example URL (surah 1) |
|---|---|---|---|
| 1 | Mishary Rashid Alafasy | `mishaari_raashid_al_3afaasee` | `https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee/001.mp3` |
| 2 | Abdurrahmaan As-Sudais | `abdurrahmaan_as-sudays` | `.../quran/abdurrahmaan_as-sudays/001.mp3` |
| 3 | Maher Al-Muaiqly | `maher_almu3aiqly/year1440` (contains a slash) | `.../quran/maher_almu3aiqly/year1440/001.mp3` |
| 4 | Mahmoud Khalil Al-Husary | `mahmood_khaleel_al-husaree` | `.../quran/mahmood_khaleel_al-husaree/001.mp3` |
| 5 | Muhammad Siddiq Al-Minshawi | `muhammad_siddeeq_al-minshaawee` | `.../quran/muhammad_siddeeq_al-minshaawee/001.mp3` |
| 6 | Abdullah Awad Al-Juhany | `abdullaah_3awwaad_al-juhaynee` | `.../quran/abdullaah_3awwaad_al-juhaynee/001.mp3` |

**Live check (2026-10-27, headers only, 18 of the 684 files: surahs 001, 036 and 114 for each reciter):**
all HTTP 200, `Content-Type: audio/mpeg`, `Accept-Ranges: bytes`, `Access-Control-Allow-Origin: *`.
Sizes in the sample: 0.4 MB (short surahs) to 21.8 MB (surah 36, Husary). The code comment says every entry
was checked for all 114 surahs; I did not re-check all 684. Total size was not measured.

The surah-list API (`https://api.alquran.cloud/v1/surah`) also answered HTTP 200 with
`Access-Control-Allow-Origin: *` and `Cache-Control: max-age=86400`; it returns 114 records.

### 1.5 How playback works (UI -> data -> player)

1. `AudioScreen` creates `QuranAudioController(JustAudioBackend())` and calls `load()`, which calls
   `QuranService.surahs()` (cache first, then the API). (`audio_screen.dart:34-35, 46`)
2. Tapping a surah calls `controller.toggle(n)` -> `play(n)`, which sets
   `kReciters[reciter].surahUrl(n)` on the `just_audio` player (25-second timeout) and then plays.
   (`audio_controller.dart:195-212`)
3. Pause/resume: `togglePlayPause()`. Stop: `stop()` when the last surah ends, and the player is disposed
   when the Audio screen is left (**playback stops when the user leaves the Audio screen**).
4. When a surah ends the next one plays; with *repeat* the same one repeats; with *shuffle* a random
   other one plays; after surah 114 it stops. (`audio_controller.dart:163-193`)
5. Also: previous (restarts the surah if more than 3 s in), next, seek bar, changing reciter mid-surah
   (the same surah continues with the new voice). A failed load shows the message `deenAudioError`.
6. The full-screen player (`NowPlayingScreen`) shares the same controller; the "Read" button opens the
   Quran text reader (`quran_screens.dart`), whose text also comes from alquran.cloud
   (`/surah/{n}/editions/quran-uthmani,en.sahih`).

### 1.6 Access, caching, tracking

| Question | Answer (verified in code) |
|---|---|
| Login required? | **No.** Audio is public; the URLs are plain `https` links with no token or header. |
| Signed or expiring URLs? | **No.** Static, unsigned, permanent URLs built from the pattern above. |
| Cached or downloaded? | **No audio caching and no downloads** (plain `setUrl`; no caching audio source). Only the surah *list* is cached. |
| Play counts, listening time, completion, unique listeners? | **None.** No audio code records anything, locally or remotely. The app's search analytics (`lib/services/analytics_service.dart`) covers searches only; the newer Firebase Analytics layer (`lib/services/app_analytics.dart`, not yet released) does not track audio either. |
| Tests | `test/audio_controller_test.dart` (controller logic with a fake player). |

### 1.7 The existing backend, and whether it holds audio

The app talks to one Supabase project (URL in `lib/services/backend_config.dart`). The REST tables / RPCs /
functions / storage paths the app code uses (full list from the source):

* Tables: `profiles`, `vendors`, `vendors_public`, `districts`, `localities`, `vendor_categories`,
  `service_categories`, `jobs`, `job_applications`, `vendor_reviews`, `vendor_reviews_public`, `reports`,
  `ads`, `ad_views`, `user_device_tokens`, `user_roles`, `unlocked_vendor_contacts`, `credit_transactions`,
  `call_clicks`, `activity_logs`, `referrals`.
* RPCs: `track_search`, `user_owns_vendor`, `is_super_admin`, `is_admin`, `has_role`, `has_unlocked_vendor`,
  `get_user_credits`, `can_access_vendor_contact`.
* Edge functions: `send-otp`, `verify-otp`, `unlock-vendor-contact`, `claim-ad-credits`, `send-lead-sms`,
  `send-whatsapp-msg91`, `delete-my-account`, and others for admin/referral/sync work.
* Storage: `/storage/v1/object/public/vendor-images/` (vendor photos) is the only bucket the code uses.

**None of these is an audio table, bucket or endpoint.** Firebase: the project has a Storage bucket name in
its settings (`konnect-kashmir1.firebasestorage.app`) but the app code never uses Firebase Storage or
Firestore. `activity_logs` is an admin activity log (action / performer), not audio data.
(I did not probe the live database for tables the app does not use; I only report what the app code
references.)

## 2. Audio inventory

| Field | Details |
|---|---|
| Audio title | "Surah N - <English name>", e.g. "Al-Faatiha" with the Arabic name; full list in Appendix A (114 titles, from the API the app uses) |
| Category | None in the app. All items are Quran recitation by a chosen reciter |
| File name | `001.mp3` ... `114.mp3` per reciter |
| File location | **Not in the repo or any Konnect storage.** Third-party: `https://download.quranicaudio.com/quran/<slug>/<NNN>.mp3` |
| Audio source | External URL (quranicaudio.com), built in code from `kReciters` |
| Metadata source | Surahs: `api.alquran.cloud/v1/surah` (cached in SharedPreferences `quran_surahs`). Reciters: `lib/screens/deen/deen_data.dart` (`kReciters`) |
| Playback implementation | `just_audio` via `JustAudioBackend` in `lib/screens/deen/audio_controller.dart`; screens `audio_screen.dart`, `now_playing_screen.dart` |
| Web accessibility | **Yes, today**: public, CORS `*`, range requests OK. The website can stream the same files directly |
| Recommended integration | Reuse the existing public source now (no copy). Add a Konnect-owned catalog only when Konnect wants its own audio (see section 5) |

Rows by item type:

| Item | Count | Is it audio content? | Where it lives | Website can reuse? |
|---|---|---|---|---|
| Quran recitation (6 reciters x 114 surahs) | 684 files | **Yes** | quranicaudio.com (third party) | Yes, directly |
| Surah names / verse counts | 114 records | Metadata | alquran.cloud API | Yes, directly |
| Reciter list | 6 entries | Metadata | Dart source `kReciters` | Copy the 6 rows (section 6) |
| Duas | 12 entries | **No** (text only) | Dart source `kDuas` (`deen_data.dart:37-158`) | Copy the text if wanted |
| Prayer-time beep | 1 sound (2 copies) | **No** (alarm sound) | `res/raw/prayer_beep.wav`, `ios/Runner/prayer_beep.wav` | Not needed |
| Rewarded-ad videos | n/a | **No** (YouTube video) | `ads` table, played by `youtube_player_flutter` | Out of scope |
| Naats, nasheeds, lectures, other | 0 | - | Do not exist in the app | - |

## 3. Existing metadata structures (real field names)

```dart
// lib/screens/deen/quran_service.dart  (Surah, built from the alquran.cloud JSON)
// JSON keys read: number, name, englishName, englishNameTranslation, numberOfAyahs
// (the API also sends revelationType, which the app does not use)
{"number":1,"name":"سُورَةُ ٱلْفَاتِحَةِ","englishName":"Al-Faatiha",
 "englishNameTranslation":"The Opening","numberOfAyahs":7,"revelationType":"Meccan"}

// lib/screens/deen/deen_data.dart  (Reciter)  - hard-coded, not from any API
Reciter(name: 'Mishary Rashid Alafasy', slug: 'mishaari_raashid_al_3afaasee')

// lib/screens/deen/deen_data.dart  (Dua)  - text only, no audio field
Dua(arabic, title: {'en','hi','ur'}, meaning: {'en','hi','ur'}, source)
```

## 4. What the website can reuse immediately

Nothing needs to be built on the Konnect backend to play the same audio on the website:

```js
// All public, no key, CORS-enabled (verified 2026-10-27).
const reciters = [
  { name: 'Mishary Rashid Alafasy',      slug: 'mishaari_raashid_al_3afaasee' },
  { name: 'Abdurrahmaan As-Sudais',      slug: 'abdurrahmaan_as-sudays' },
  { name: 'Maher Al-Muaiqly',            slug: 'maher_almu3aiqly/year1440' },   // slash is part of the slug
  { name: 'Mahmoud Khalil Al-Husary',    slug: 'mahmood_khaleel_al-husaree' },
  { name: 'Muhammad Siddiq Al-Minshawi', slug: 'muhammad_siddeeq_al-minshaawee' },
  { name: 'Abdullah Awad Al-Juhany',     slug: 'abdullaah_3awwaad_al-juhaynee' },
];
const surahUrl = (slug, n) =>
  `https://download.quranicaudio.com/quran/${slug}/${String(n).padStart(3, '0')}.mp3`;
const surahs = (await (await fetch('https://api.alquran.cloud/v1/surah')).json()).data; // 114 items
new Audio(surahUrl(reciters[0].slug, 1)).play();
```

Points to keep identical to the app so both platforms stay consistent: the 3-digit file numbering; the same
6 reciters in the same order; next-surah-on-finish; shuffle / repeat-this-surah; "previous" restarts the
surah if more than 3 seconds in.

## 5. What is missing for shared web + mobile audio management (verified gaps)

1. **No Konnect-owned audio catalog** (table) - the reciter list lives only in app source, so a change
   needs an app release.
2. **No Konnect-owned storage** for audio files (the only bucket used is `vendor-images`).
3. **No admin screen** to add or edit audio (none in the app code).
4. **No fields** for description, category, artwork or ordering anywhere.
5. **No audio analytics** on any platform (plays, listening time, completion, unique listeners).
6. **Dependence on a third party**: quranicaudio.com availability, terms and URL layout are outside Konnect's
   control; if a slug or path changes, every installed app breaks until updated.

## 6. Recommendations (not implemented; they are proposals)

### 6.1 Step 1 - no migration: one shared *catalog*, same files

Keep playing the existing quranicaudio.com files; do **not** copy or re-upload them. Put the *list* in one
place both clients read:

* Proposed table `audio_reciters` (**does not exist today**): `id`, `name`, `slug`, `base_url`, `sort_order`,
  `is_active`. Public read of active rows; writes only for admins.
* App and website read this table (the app keeps today's built-in list as a **fallback**, so old app versions
  and offline starts keep working unchanged).
* Adding/removing a reciter then needs no app release.

### 6.2 Step 2 - only if Konnect wants its own audio (naats, lectures, nasheeds ...)

Proposed (none of this exists today):

* Storage bucket `audio` (public read, admin-only write) and, if artwork is wanted, `audio-artwork`.
* Table `audio_items`: `id`, `title`, `category`, `description`, `artwork_path`, `storage_path`
  (or `source_url` for external files), `duration_seconds`, `language`, `sort_order`, `is_published`,
  `created_at`, `created_by`.
* One **admin upload/edit page** (website admin) that writes the file to the bucket and the row to the table;
  the mobile app and the website both read `audio_items`.
* Access: public playback matches today's behaviour (no login). If some audio must be members-only, use
  signed URLs for those rows only; today nothing is signed.
* Security: row-level security with public `SELECT` where `is_published`, and write policies limited to
  admins. The app already calls `is_admin`, `is_super_admin` and `has_role` RPCs, so an admin check exists to
  build on (confirm they exist in the live database before relying on them; I only saw them in app code).

### 6.3 Shared analytics (proposal)

* One event set on both platforms: `audio_play_start`, `audio_progress` (e.g. every 30 s or at 25/50/75 %),
  `audio_complete`, each with `audio_id` (or `reciter` + `surah`), platform, and listened seconds.
* Where to store: (a) **Firebase/Google Analytics** - the app now has Firebase Analytics wired for other
  events (`lib/services/app_analytics.dart`, unreleased) and the website can use GA4 in the same property;
  or (b) a Supabase table `audio_plays` filled by an RPC like the existing `track_search` (which already
  accepts anonymous calls) - gives SQL-level totals.
* Aggregates to publish: total plays, plays per audio, unique listeners (measurable per signed-in user id
  or per app/browser instance only), most-played, average listening time, completion rate.

### 6.4 Safe order of work (does not break existing mobile playback)

1. Website developer: use section 4 now (no backend change).
2. Create `audio_reciters` and fill it with the six rows above; website reads it.
3. Ship an app update that reads the table with the built-in list as fallback. Old app versions keep using
   their built-in list and the same URLs - nothing breaks.
4. Add audio analytics events to both clients.
5. Only then, if wanted, add the bucket + `audio_items` + admin page for Konnect's own audio.

## 7. Access and security notes for the website developer

* Today's audio and surah APIs are **public and unauthenticated**; no API key is needed. Do not put
  Konnect credentials in the website for this.
* The audio host is a **third party**. Before mirroring or re-hosting any file, check quranicaudio.com's
  terms; the app only streams from it. (I did not review their terms.)
* The `<audio>` element and `fetch` both work cross-origin (CORS `*`). Range requests are supported, so
  seeking works without downloading the whole file.
* The Konnect Supabase project is shared with the mobile app; use the **anon (public) key only** in the
  browser and rely on row-level security for any new tables. Never use the service-role key in the website.
* The app's current release has no audio code that depends on any Konnect backend, so adding the new
  tables/buckets cannot affect the released apps.

## 8. Relevant source files

| Purpose | Path (under `konnect_kashmir-main/`) |
|---|---|
| Reciters, URL pattern, duas | `lib/screens/deen/deen_data.dart` |
| Surah list + Quran text API client | `lib/screens/deen/quran_service.dart` |
| Player + queue logic | `lib/screens/deen/audio_controller.dart` |
| Audio list screen | `lib/screens/deen/audio_screen.dart` |
| Full-screen player, reciter picker | `lib/screens/deen/now_playing_screen.dart` |
| Entry point (Deen tab tile) | `lib/screens/deen/deen_tab.dart` (lines ~897-898) |
| Tests | `test/audio_controller_test.dart` |
| Package list | `pubspec.yaml` |
| Backend base URL | `lib/services/backend_config.dart` |

## Appendix A - the 114 surah titles (snapshot of what the app lists)

Taken on 2026-10-27 from `https://api.alquran.cloud/v1/surah`, the same call the app makes.

| # | English name | Translation | Arabic name | Verses | Revelation |
|---|---|---|---|---|---|
| 1 | Al-Faatiha | The Opening | سُورَةُ ٱلْفَاتِحَةِ | 7 | Meccan |
| 2 | Al-Baqara | The Cow | سُورَةُ البَقَرَةِ | 286 | Medinan |
| 3 | Aal-i-Imraan | The Family of Imraan | سُورَةُ آلِ عِمۡرَانَ | 200 | Medinan |
| 4 | An-Nisaa | The Women | سُورَةُ النِّسَاءِ | 176 | Medinan |
| 5 | Al-Maaida | The Table | سُورَةُ المَائـِدَةِ | 120 | Medinan |
| 6 | Al-An'aam | The Cattle | سُورَةُ الأَنۡعَامِ | 165 | Meccan |
| 7 | Al-A'raaf | The Heights | سُورَةُ الأَعۡرَافِ | 206 | Meccan |
| 8 | Al-Anfaal | The Spoils of War | سُورَةُ الأَنفَالِ | 75 | Medinan |
| 9 | At-Tawba | The Repentance | سُورَةُ التَّوۡبَةِ | 129 | Medinan |
| 10 | Yunus | Jonas | سُورَةُ يُونُسَ | 109 | Meccan |
| 11 | Hud | Hud | سُورَةُ هُودٍ | 123 | Meccan |
| 12 | Yusuf | Joseph | سُورَةُ يُوسُفَ | 111 | Meccan |
| 13 | Ar-Ra'd | The Thunder | سُورَةُ الرَّعۡدِ | 43 | Medinan |
| 14 | Ibrahim | Abraham | سُورَةُ إِبۡرَاهِيمَ | 52 | Meccan |
| 15 | Al-Hijr | The Rock | سُورَةُ الحِجۡرِ | 99 | Meccan |
| 16 | An-Nahl | The Bee | سُورَةُ النَّحۡلِ | 128 | Meccan |
| 17 | Al-Israa | The Night Journey | سُورَةُ الإِسۡرَاءِ | 111 | Meccan |
| 18 | Al-Kahf | The Cave | سُورَةُ الكَهۡفِ | 110 | Meccan |
| 19 | Maryam | Mary | سُورَةُ مَرۡيَمَ | 98 | Meccan |
| 20 | Taa-Haa | Taa-Haa | سُورَةُ طه | 135 | Meccan |
| 21 | Al-Anbiyaa | The Prophets | سُورَةُ الأَنبِيَاءِ | 112 | Meccan |
| 22 | Al-Hajj | The Pilgrimage | سُورَةُ الحَجِّ | 78 | Medinan |
| 23 | Al-Muminoon | The Believers | سُورَةُ المُؤۡمِنُونَ | 118 | Meccan |
| 24 | An-Noor | The Light | سُورَةُ النُّورِ | 64 | Medinan |
| 25 | Al-Furqaan | The Criterion | سُورَةُ الفُرۡقَانِ | 77 | Meccan |
| 26 | Ash-Shu'araa | The Poets | سُورَةُ الشُّعَرَاءِ | 227 | Meccan |
| 27 | An-Naml | The Ant | سُورَةُ النَّمۡلِ | 93 | Meccan |
| 28 | Al-Qasas | The Stories | سُورَةُ القَصَصِ | 88 | Meccan |
| 29 | Al-Ankaboot | The Spider | سُورَةُ العَنكَبُوتِ | 69 | Meccan |
| 30 | Ar-Room | The Romans | سُورَةُ الرُّومِ | 60 | Meccan |
| 31 | Luqman | Luqman | سُورَةُ لُقۡمَانَ | 34 | Meccan |
| 32 | As-Sajda | The Prostration | سُورَةُ السَّجۡدَةِ | 30 | Meccan |
| 33 | Al-Ahzaab | The Clans | سُورَةُ الأَحۡزَابِ | 73 | Medinan |
| 34 | Saba | Sheba | سُورَةُ سَبَإٍ | 54 | Meccan |
| 35 | Faatir | The Originator | سُورَةُ فَاطِرٍ | 45 | Meccan |
| 36 | Yaseen | Yaseen | سُورَةُ يسٓ | 83 | Meccan |
| 37 | As-Saaffaat | Those drawn up in Ranks | سُورَةُ الصَّافَّاتِ | 182 | Meccan |
| 38 | Saad | The letter Saad | سُورَةُ صٓ | 88 | Meccan |
| 39 | Az-Zumar | The Groups | سُورَةُ الزُّمَرِ | 75 | Meccan |
| 40 | Ghafir | The Forgiver | سُورَةُ غَافِرٍ | 85 | Meccan |
| 41 | Fussilat | Explained in detail | سُورَةُ فُصِّلَتۡ | 54 | Meccan |
| 42 | Ash-Shura | Consultation | سُورَةُ الشُّورَىٰ | 53 | Meccan |
| 43 | Az-Zukhruf | Ornaments of gold | سُورَةُ الزُّخۡرُفِ | 89 | Meccan |
| 44 | Ad-Dukhaan | The Smoke | سُورَةُ الدُّخَانِ | 59 | Meccan |
| 45 | Al-Jaathiya | Crouching | سُورَةُ الجَاثِيَةِ | 37 | Meccan |
| 46 | Al-Ahqaf | The Dunes | سُورَةُ الأَحۡقَافِ | 35 | Meccan |
| 47 | Muhammad | Muhammad | سُورَةُ مُحَمَّدٍ | 38 | Medinan |
| 48 | Al-Fath | The Victory | سُورَةُ الفَتۡحِ | 29 | Medinan |
| 49 | Al-Hujuraat | The Inner Apartments | سُورَةُ الحُجُرَاتِ | 18 | Medinan |
| 50 | Qaaf | The letter Qaaf | سُورَةُ قٓ | 45 | Meccan |
| 51 | Adh-Dhaariyat | The Winnowing Winds | سُورَةُ الذَّارِيَاتِ | 60 | Meccan |
| 52 | At-Tur | The Mount | سُورَةُ الطُّورِ | 49 | Meccan |
| 53 | An-Najm | The Star | سُورَةُ النَّجۡمِ | 62 | Meccan |
| 54 | Al-Qamar | The Moon | سُورَةُ القَمَرِ | 55 | Meccan |
| 55 | Ar-Rahmaan | The Beneficent | سُورَةُ الرَّحۡمَٰن | 78 | Medinan |
| 56 | Al-Waaqia | The Inevitable | سُورَةُ الوَاقِعَةِ | 96 | Meccan |
| 57 | Al-Hadid | The Iron | سُورَةُ الحَدِيدِ | 29 | Medinan |
| 58 | Al-Mujaadila | The Pleading Woman | سُورَةُ المُجَادلَةِ | 22 | Medinan |
| 59 | Al-Hashr | The Exile | سُورَةُ الحَشۡرِ | 24 | Medinan |
| 60 | Al-Mumtahana | She that is to be examined | سُورَةُ المُمۡتَحنَةِ | 13 | Medinan |
| 61 | As-Saff | The Ranks | سُورَةُ الصَّفِّ | 14 | Medinan |
| 62 | Al-Jumu'a | Friday | سُورَةُ الجُمُعَةِ | 11 | Medinan |
| 63 | Al-Munaafiqoon | The Hypocrites | سُورَةُ المُنَافِقُونَ | 11 | Medinan |
| 64 | At-Taghaabun | Mutual Disillusion | سُورَةُ التَّغَابُنِ | 18 | Medinan |
| 65 | At-Talaaq | Divorce | سُورَةُ الطَّلَاقِ | 12 | Medinan |
| 66 | At-Tahrim | The Prohibition | سُورَةُ التَّحۡرِيمِ | 12 | Medinan |
| 67 | Al-Mulk | The Sovereignty | سُورَةُ المُلۡكِ | 30 | Meccan |
| 68 | Al-Qalam | The Pen | سُورَةُ القَلَمِ | 52 | Meccan |
| 69 | Al-Haaqqa | The Reality | سُورَةُ الحَاقَّةِ | 52 | Meccan |
| 70 | Al-Ma'aarij | The Ascending Stairways | سُورَةُ المَعَارِجِ | 44 | Meccan |
| 71 | Nooh | Noah | سُورَةُ نُوحٍ | 28 | Meccan |
| 72 | Al-Jinn | The Jinn | سُورَةُ الجِنِّ | 28 | Meccan |
| 73 | Al-Muzzammil | The Enshrouded One | سُورَةُ المُزَّمِّلِ | 20 | Meccan |
| 74 | Al-Muddaththir | The Cloaked One | سُورَةُ المُدَّثِّرِ | 56 | Meccan |
| 75 | Al-Qiyaama | The Resurrection | سُورَةُ القِيَامَةِ | 40 | Meccan |
| 76 | Al-Insaan | Man | سُورَةُ الإِنسَانِ | 31 | Medinan |
| 77 | Al-Mursalaat | The Emissaries | سُورَةُ المُرۡسَلَاتِ | 50 | Meccan |
| 78 | An-Naba | The Announcement | سُورَةُ النَّبَإِ | 40 | Meccan |
| 79 | An-Naazi'aat | Those who drag forth | سُورَةُ النَّازِعَاتِ | 46 | Meccan |
| 80 | Abasa | He frowned | سُورَةُ عَبَسَ | 42 | Meccan |
| 81 | At-Takwir | The Overthrowing | سُورَةُ التَّكۡوِيرِ | 29 | Meccan |
| 82 | Al-Infitaar | The Cleaving | سُورَةُ الانفِطَارِ | 19 | Meccan |
| 83 | Al-Mutaffifin | Defrauding | سُورَةُ المُطَفِّفِينَ | 36 | Meccan |
| 84 | Al-Inshiqaaq | The Splitting Open | سُورَةُ الانشِقَاقِ | 25 | Meccan |
| 85 | Al-Burooj | The Constellations | سُورَةُ البُرُوجِ | 22 | Meccan |
| 86 | At-Taariq | The Morning Star | سُورَةُ الطَّارِقِ | 17 | Meccan |
| 87 | Al-A'laa | The Most High | سُورَةُ الأَعۡلَىٰ | 19 | Meccan |
| 88 | Al-Ghaashiya | The Overwhelming | سُورَةُ الغَاشِيَةِ | 26 | Meccan |
| 89 | Al-Fajr | The Dawn | سُورَةُ الفَجۡرِ | 30 | Meccan |
| 90 | Al-Balad | The City | سُورَةُ البَلَدِ | 20 | Meccan |
| 91 | Ash-Shams | The Sun | سُورَةُ الشَّمۡسِ | 15 | Meccan |
| 92 | Al-Lail | The Night | سُورَةُ اللَّيۡلِ | 21 | Meccan |
| 93 | Ad-Dhuhaa | The Morning Hours | سُورَةُ الضُّحَىٰ | 11 | Meccan |
| 94 | Ash-Sharh | The Consolation | سُورَةُ الشَّرۡحِ | 8 | Meccan |
| 95 | At-Tin | The Fig | سُورَةُ التِّينِ | 8 | Meccan |
| 96 | Al-Alaq | The Clot | سُورَةُ العَلَقِ | 19 | Meccan |
| 97 | Al-Qadr | The Power, Fate | سُورَةُ القَدۡرِ | 5 | Meccan |
| 98 | Al-Bayyina | The Evidence | سُورَةُ البَيِّنَةِ | 8 | Medinan |
| 99 | Az-Zalzala | The Earthquake | سُورَةُ الزَّلۡزَلَةِ | 8 | Medinan |
| 100 | Al-Aadiyaat | The Chargers | سُورَةُ العَادِيَاتِ | 11 | Meccan |
| 101 | Al-Qaari'a | The Calamity | سُورَةُ القَارِعَةِ | 11 | Meccan |
| 102 | At-Takaathur | Competition | سُورَةُ التَّكَاثُرِ | 8 | Meccan |
| 103 | Al-Asr | The Declining Day, Epoch | سُورَةُ العَصۡرِ | 3 | Meccan |
| 104 | Al-Humaza | The Traducer | سُورَةُ الهُمَزَةِ | 9 | Meccan |
| 105 | Al-Fil | The Elephant | سُورَةُ الفِيلِ | 5 | Meccan |
| 106 | Quraish | Quraysh | سُورَةُ قُرَيۡشٍ | 4 | Meccan |
| 107 | Al-Maa'un | Almsgiving | سُورَةُ المَاعُونِ | 7 | Meccan |
| 108 | Al-Kawthar | Abundance | سُورَةُ الكَوۡثَرِ | 3 | Meccan |
| 109 | Al-Kaafiroon | The Disbelievers | سُورَةُ الكَافِرُونَ | 6 | Meccan |
| 110 | An-Nasr | Divine Support | سُورَةُ النَّصۡرِ | 3 | Medinan |
| 111 | Al-Masad | The Palm Fibre | سُورَةُ المَسَدِ | 5 | Meccan |
| 112 | Al-Ikhlaas | Sincerity | سُورَةُ الإِخۡلَاصِ | 4 | Meccan |
| 113 | Al-Falaq | The Dawn | سُورَةُ الفَلَقِ | 5 | Meccan |
| 114 | An-Naas | Mankind | سُورَةُ النَّاسِ | 6 | Meccan |

