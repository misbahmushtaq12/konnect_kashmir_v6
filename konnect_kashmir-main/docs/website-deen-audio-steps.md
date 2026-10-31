# Website: using the same Deen audio as the mobile app - exact steps

Written 2026-10-29. For the website developer. Everything marked **Verified** was read in the app source or
in the live website's public scripts, or checked with a read-only request on that date. Nothing was written to
any database.

## 1. What is already true (verified)

1. The website and the app use the **same Supabase project** (`fmmpsqnpezjofsluirrv`; the live site's
   scripts call it, and so does the app).
2. The mobile app plays **Quran recitation only**: 6 reciters x 114 surahs, streamed from
   `https://download.quranicaudio.com/quran/<slug>/<NNN>.mp3` (NNN = 001..114). The app stores none of it and
   keeps the 6 reciters in a hard-coded list (`lib/screens/deen/deen_data.dart`).
3. The website's Deen page (`/deen`, scripts `Deen-*.js` and `deenAudio-*.js`) already has the right design:
   * reciters from table **`audio_reciters`**: columns it reads are `id, name, source_base_url, is_active,
     sort_order`;
   * it builds the file URL as **`<source_base_url without trailing slash>/<surah number padded to 3 digits>.mp3`**
     - exactly the app's pattern;
   * the 114 surah names come from `https://api.alquran.cloud/v1/surah` - the same API the app uses;
   * other audio (quran / dua / naat / nasheed / lecture / other) from table `audio_tracks` (`id, title,
     description, category, storage_path, external_url, is_active, sort_order`; private files in bucket
     `deen-audio` via signed URL, valid 6 hours);
   * plays go to table `audio_play_events` (`event_type`, `track_id`, `reciter_id`, `surah_number`,
     `listened_seconds`, `source` = `"website"`, `session_id`, `user_id`) and page views to `deen_events`
     (`event_type`, `meta`, `session_id`, `user_id`).
4. **Why the page says "Audio will appear here soon":** `audio_reciters` and `audio_tracks` exist, and a
   read-only request with the public key (the same access the website has) returned **0 rows** from both on
   2026-10-29. Lovable's own answer says the tables are empty until reciters are added, which fits. (A public
   request cannot tell "empty" from "rows hidden by the read policy"; the `select` in step 2 tells which.)
   Nothing is wrong with the code; the six reciters were never entered.

## 2. What the developer must do

### Step 1 - put the six reciters into `audio_reciters` (this alone makes the website play the same audio)

Use exactly these names, order and base URLs. They are the app's list, character for character. Note the third
one contains a slash - that is correct. Run in the Supabase SQL editor (safe to run twice):

```sql
INSERT INTO public.audio_reciters (name, source_base_url, is_active, sort_order)
SELECT v.name, v.base, true, v.ord
FROM (VALUES
  ('Mishary Rashid Alafasy',      'https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee',         1),
  ('Abdurrahmaan As-Sudais',      'https://download.quranicaudio.com/quran/abdurrahmaan_as-sudays',               2),
  ('Maher Al-Muaiqly',            'https://download.quranicaudio.com/quran/maher_almu3aiqly/year1440',            3),
  ('Mahmoud Khalil Al-Husary',    'https://download.quranicaudio.com/quran/mahmood_khaleel_al-husaree',           4),
  ('Muhammad Siddiq Al-Minshawi', 'https://download.quranicaudio.com/quran/muhammad_siddeeq_al-minshaawee',       5),
  ('Abdullah Awad Al-Juhany',     'https://download.quranicaudio.com/quran/abdullaah_3awwaad_al-juhaynee',        6)
) AS v(name, base, ord)
WHERE NOT EXISTS (SELECT 1 FROM public.audio_reciters r WHERE r.name = v.name);
```

(The five columns are the ones the website code reads. If the table has another NOT NULL column without a
default, the insert will say which; fill it in.) Do not put a trailing slash on the base URL and do not add
`/001.mp3` - the page adds the number itself.

### Step 2 - check it works (all must pass before calling it done)

1. `select name, source_base_url, sort_order from audio_reciters where is_active order by sort_order;` shows
   the six rows (run it in the SQL editor as an admin). Then check the **public** can read them: with the
   public (anon) key, `GET /rest/v1/audio_reciters?select=id,name,source_base_url&is_active=eq.true` must also
   return the six rows - if it returns nothing, the read policy is hiding them; fix the policy (public read of
   active rows).
2. Open the website Deen page: the message "Audio will appear here soon" is gone; the Quran tab shows a
   reciter picker and the 114 surahs.
3. For **each** of the 6 reciters play surah **1**, **36** and **114**: audio starts, you can seek, and
   "This audio couldn't be loaded" never appears. (Files for these exist: checked HTTP 200 `audio/mpeg`,
   range requests, CORS `*`.)
4. In `audio_play_events` a `play` row appears when playback starts and a `complete` row when a surah ends,
   with the right `reciter_id` and `surah_number`.

### Step 3 - keep one source of truth

* `audio_reciters` is now the list for **both** platforms. **Do not rename these six, change their base URLs
  or reorder them** without telling the app owner: already-installed apps still use their built-in copy of
  the list and would no longer match the website.
* New reciters or other audio are added in the website admin only (they go to `audio_reciters` /
  `audio_tracks`); the app will pick them up once its next version reads the same tables (section 3).
* Keep the policies: **public read of active rows; write for admins only** (today's reading works, so the read
  policy is already right).

### Step 4 - make the analytics usable for both platforms (gaps found in the website code)

1. **`deen_events` has no source column in what the site inserts** (`event_type, meta, session_id, user_id`).
   To report app vs website, add `source text not null default 'website'` and allow the value `'app'`.
   (`audio_play_events` already has `source`.)
2. **Check that the app is allowed to write.** The app will insert into `audio_play_events` and `deen_events`
   with the public key (signed-in or not) and `source = 'app'`. Confirm the insert policies allow
   both roles, and that no check constraint on `source` or `event_type` rejects `'app'` or the event names
   below.
3. **Listening time for plays that do not finish is not recorded today.** The site sends `play` (no seconds)
   and `complete` (`listened_seconds` = duration minus the start position), nothing on pause or leaving the
   page. Add `pause` / `stop` (and on page hide) events with `listened_seconds`, so average listening time and
   "stopped early" can be reported.
4. Event names to use on **both** platforms: audio `play`, `pause`, `complete` (fields as in
   `audio_play_events`); Deen `page_view`, `prayer_times_view`, `quran_open`, `dua_view`, `qibla_view`
   with `meta` for details. (The app has Prayer times, Qibla, Quran reader, Audio and Duas - no tasbeeh.)
5. The admin dashboard must read these tables and show **App / Website / Total** from `source`. Do not mark it
   complete until real events from a real play are visible in it.

## 3. What the app owner will do (not the website developer)

After step 1, the app is changed to read the same table, so both platforms share one list:

* `GET /rest/v1/audio_reciters?select=id,name,source_base_url&is_active=eq.true&order=sort_order.asc,name.asc`
  (public key, like the site), then build each file URL as `<source_base_url>/<NNN>.mp3`.
* The built-in six stay in the app as a **fallback** when the request fails, so playback never breaks; old app
  versions keep working unchanged.
* The app sends the same audio and Deen events with `source = 'app'`.

This needs an app release; until then the app keeps playing the same six files from its own list, which are
the same files the website will now play.

## 4. Prompt to give Lovable (copy and paste)

> Do not create another audio system. The Deen audio tables already exist: `audio_reciters`, `audio_tracks`,
> `audio_play_events`, `deen_events`. They are empty, which is why the Listen card shows "Audio will appear here
> soon".
>
> 1. Insert exactly these six rows into `audio_reciters` (name, source_base_url, is_active=true, sort_order),
>    with no changes to names, URLs or order, and no trailing slash:
>    1 Mishary Rashid Alafasy -> https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee
>    2 Abdurrahmaan As-Sudais -> https://download.quranicaudio.com/quran/abdurrahmaan_as-sudays
>    3 Maher Al-Muaiqly -> https://download.quranicaudio.com/quran/maher_almu3aiqly/year1440
>    4 Mahmoud Khalil Al-Husary -> https://download.quranicaudio.com/quran/mahmood_khaleel_al-husaree
>    5 Muhammad Siddiq Al-Minshawi -> https://download.quranicaudio.com/quran/muhammad_siddeeq_al-minshaawee
>    6 Abdullah Awad Al-Juhany -> https://download.quranicaudio.com/quran/abdullaah_3awwaad_al-juhaynee
>    The existing page already builds `<source_base_url>/<surah padded to 3 digits>.mp3` and takes the 114
>    surahs from https://api.alquran.cloud/v1/surah. Keep that.
> 2. Test playback of surahs 1, 36 and 114 for every reciter in a browser and report the result of each.
> 3. Add a `source` column (text, not null, default 'website', accepts 'app') to `deen_events`. Make sure
>    anonymous and signed-in users can insert into `audio_play_events` and `deen_events` with source 'website'
>    or 'app' and cannot read other people's rows.
> 4. Record `pause`/`stop` events with `listened_seconds`, not only `play` and `complete`.
> 5. Make the admin Deen dashboard show App / Website / Total for audio plays, completed listens, average
>    listening time, plays per reciter and surah, and Deen page views, from real rows only.
> 6. Do not change the existing UI or the six reciters afterwards. Do not report anything as done until a real
>    playback created a visible `audio_play_events` row; list anything not tested.

## 5. Facts to keep in mind

* The audio files belong to **quranicaudio.com**. Konnect only links to them. Check their terms before copying
  or re-hosting any file (not reviewed).
* Never use the service-role key in the browser; the public (anon) key plus row-level security only.
* Surah text, the 114 names and verse counts are public API data and are not stored by Konnect.

## 6. What the mobile app now does (implemented 2026-10-29, not yet released)

* **Reciters:** the Audio screen reads `audio_reciters` (`id, name, source_base_url`, only `is_active`, ordered by
  `sort_order, name`) with the public key, shows the saved copy first, and falls back to the built-in six when
  the table cannot be read. A row is used only if it has an id, a name and an `https` address. Files are
  `<source_base_url>/<NNN>.mp3`, as on the website.
* **Audio events** (`audio_play_events`, `source = 'app'`): `play` (start or resume), `pause`, `stop` (leaving
  the screen, choosing another surah or reciter while playing), `complete`; with `reciter_id` (the table's id;
  null only when the built-in fallback list is in use), `surah_number`, `track_id` null, and
  `listened_seconds` = seconds actually heard in that stretch (jumps in the seek bar are not counted).
* **Deen events** (`deen_events`, `source = 'app'`): `page_view` (the Deen tab is shown), `compass_started`,
  `madhhab_change` (`meta.madhhab` = hanafi / shafi / maliki / hanbali / jafari), `method_change`
  (`meta.method` = the method's name, same text as the website). Only these four are sent because they are the
  ones the website sends and the dashboard (`get_deen_analytics`) reads. There are no events for Quran
  reading, duas or prayer-time views: the dashboard has nothing for them, and the database may not accept new
  event names. If you want them, add the names to the database/dashboard first and tell the app owner.
* **Who:** a signed-in user is sent with their own token and `user_id`; if the database refuses that (401/403)
  the same row is sent once more as anonymous. `session_id` is one random id per app launch.
* **Checked on a real phone (Android, 2026-10-29), every row accepted by the database with HTTP 201 and
  `source = 'app'`:** `page_view`, `compass_started`, `play`, `pause`, `play` (resume), `stop` (switching reciter, and
  leaving the screen), `complete` (a surah that played to its end), and the reciter list loaded from
  `audio_reciters` (6 reciters, same names and order). **Not yet seen by a person:** the numbers in
  Admin -> Deen Analytics (the reports are admin-only; the public key gets "permission denied", as it should)
  and `madhhab_change` / `method_change` from a phone. Please check the dashboard shows App rows.
