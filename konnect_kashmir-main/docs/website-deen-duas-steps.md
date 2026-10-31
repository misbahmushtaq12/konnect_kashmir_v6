# Website: the Duas section - exact steps

Written 2026-10-29, for the website developer. **Verified** = read in the app source or in the live
website's public scripts on that date.

## 1. What is true now (verified)

* **The mobile app has 12 everyday duas**, text only (no audio). They are written directly in the app's
  source (`lib/screens/deen/deen_data.dart`, `kDuas`); there is no database table for them. Each has:
  the Arabic text, a **title** and a **meaning** in English, Hindi and Urdu, and a **source** line
  (for example "Sahih al-Bukhari", "Quran 2:201"). The app shows them as cards: title, the Arabic large and
  right-to-left, the meaning in the user's language (English if that language is missing), and
  "Source: ...".
* **The website has no Duas section and no duas table.** The live site's scripts contain no dua page and
  no dua table. The only "dua" in the website is the word in the list of categories for *audio*
  (`audio_tracks.category`: quran, dua, naat, nasheed, lecture, other). So nothing is "broken" - the Duas
  feature was never built on the website, or in the admin panel.
* So the web developer has to **create one table, fill it with the app's 12 duas, show them on the Deen
  page, and add a Duas manager to the admin panel** (like the Deen Audio manager).

## 2. What to give the developer

| File | What it is |
|---|---|
| `docs/deen-duas-seed.sql` | Creates the table `deen_duas`, turns on row-level security with public read of active rows, and inserts the 12 duas. Generated from the app's source - nothing retyped. |
| `docs/deen-duas-seed.json` | The same 12 duas as JSON (for importing, or for the developer to read the exact field names). |
| This document | The steps and the prompt below. |

The table (columns): `id` (uuid), `sort_order`, `arabic`, `title_en`, `title_hi`, `title_ur`, `meaning_en`,
`meaning_hi`, `meaning_ur`, `source`, `is_active`, `created_at`, `updated_at`.

## 3. Steps

### A. Database
1. Run `deen-duas-seed.sql` in the Supabase SQL editor (the same Supabase project the app and the
   website already share). It is safe to run twice. (It was not run on a database here: if it reports an
   error, send the message back.)
2. Add the **admin-only write policies** by copying the ones on `audio_reciters` (same admin check). Do not
   invent a new admin check, and never use the service-role key in the browser.
3. Check: `GET /rest/v1/deen_duas?select=*&is_active=eq.true&order=sort_order` with the **public (anon) key**
   returns **12 rows**, in order, with all three languages filled in.

### B. Website: the Duas section (public)
1. On the Deen page add a **Duas** section (a tab or a card list next to Listen / Prayer times).
2. Read the active rows ordered by `sort_order`. For each show: the title, then the **Arabic** (use
   `dir="rtl"`, `lang="ar"`, a large readable font and generous line height), then the meaning, then
   "Source: ..." in small grey text.
3. **Language:** use the site's current language for `title_*` / `meaning_*` (en, hi, ur). If that
   language's text is empty, fall back to English - like the app does.
4. Mobile first, light and dark themes; keep the Arabic text selectable (people copy it).
5. Nothing is saved about the visitor; no login needed (same as the app).

### C. Website admin panel: Duas manager
Same pattern as the Deen Audio manager. For admins only:
* a list (all rows, including inactive) with the Arabic's first words and the English title;
* **add / edit**: Arabic (required), titles and meanings in en / hi / ur (English required, the other
  two optional), source, order, active on/off;
* **reorder** (changes `sort_order`), **hide** (`is_active = false`) and **delete** with a confirmation;
* save errors shown to the admin, never silently.

### D. Keep the app and the website in step
* The app **currently ships its own copy** of the 12 duas. Until the app is updated to read `deen_duas`
  (the same way it now reads `audio_reciters`, with its built-in list as the fallback), an admin's edit
  appears on the website at once but **not in the app**. That app change is the app owner's job and needs an
  app release.
* Do not delete or rewrite the original 12 without telling the app owner, or the two will disagree.

### E. Analytics (optional, later)
The Deen Analytics dashboard has no dua numbers today, and the database may only accept the event names the
website already uses. Do not send new event names such as `dua_view` until the database and the dashboard
are changed to accept and show them.

## 4. Check it is done

1. `select count(*) from deen_duas where is_active;` is 12, and the public (anon) request in step A.3
   returns the same 12.
2. The Deen page on the website shows the 12 duas in the app's order, Arabic right-to-left and readable,
   with English / Hindi / Urdu text switching with the site's language.
3. An admin can add a 13th dua, hide it, edit it and delete it; the public page follows each change.
4. A signed-out visitor cannot add, change or delete anything (try it with the public key: expect a
   permission error).

## 5. Prompt for Lovable (copy and paste)

> The website has no Duas section yet. Build it on the existing Deen page and in the admin panel, reusing the
> existing Supabase project, patterns and styling. Do not create a separate system.
>
> 1. Database: use the SQL in `docs/deen-duas-seed.sql` (table `deen_duas`: id, sort_order, arabic, title_en,
>    title_hi, title_ur, meaning_en, meaning_hi, meaning_ur, source, is_active, created_at, updated_at). Public
>    read of active rows only; insert/update/delete and reading inactive rows for admins only, using the same
>    admin check as `audio_reciters`. Insert exactly the 12 duas from the file, unchanged.
> 2. Public Deen page: a Duas section listing the active duas in `sort_order`: title, the Arabic (right-to-left,
>    large, readable), the meaning, and "Source: ...". Show the language the site is in (en/hi/ur), falling back
>    to English when empty. Mobile first, light and dark.
> 3. Admin panel: a Duas manager like the Deen Audio manager - list, add, edit (Arabic, en/hi/ur titles and
>    meanings, source, order, active), reorder, hide, delete with confirmation.
> 4. Do not change the existing UI or other features. Do not add analytics event names the database does not
>    already accept.
> 5. Test with the public key (12 rows readable, writes refused) and as an admin (add, edit, hide, delete).
>    Report anything not tested and anything that still needs a manual step.

## 6. Notes

* The Arabic text, translations and sources are exactly what the released app already shows. They were not
  re-checked here; have them reviewed by a scholar before they are published more widely or edited.
* The audio category `dua` in the Deen Audio manager is for *recordings* of duas. The app has none, so nothing
  from it is needed for this feature.
