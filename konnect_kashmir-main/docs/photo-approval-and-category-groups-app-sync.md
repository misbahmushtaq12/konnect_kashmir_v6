# Photo approval, notifications and category groups: what the app does, and what is still on the server

Written 2026-11-06. **Verified** = read-only requests with the public key on that date, or the app source.
**Not verified** = could not be checked from the app project (no admin or service-role access; nothing was
written to the live database; there is no website code here).

## 1. What the live backend already has (verified)

* `business_photos` has `status`, `reviewed_at`, `reviewed_by`, `rejection_reason`, `auto_check`,
  `auto_check_scores`, `auto_checked_at`. With the public key only `approved` photos come back (23 rows;
  `pending` and `rejected` give none).
* A `notifications` table exists with `id, user_id, vendor_id, type, title, body, is_read, created_at`
  (the public key reads nothing from it, as it should).
* `service_categories` has `group_key` (79 active rows: 19 home_repair, 10 health_education, 5 food_grocery,
  7 fashion_shopping, 10 business_professional, 7 events_travel, 1 other, **20 still NULL**), `display_order`
  and `is_pinned` (only `instagram-shops`).
* The Edge Function `send-push` answers (403 to a bare OPTIONS request: it exists and is closed to the public).

## 2. What the app does now (needs an app release)

**Photos**
* The public (business page, anyone) gets **approved photos only**: the request asks for `status=eq.approved`,
  and the app drops anything else it is handed. A status it cannot read counts as waiting, never as live.
* The owner (Edit Business) sees every photo: "Under review" (pending), "Not approved: {reason}" (rejected,
  tap for the whole reason), a coloured frame, and "Photos are shown after admin review." under the block.
* `Photos (n/20)` counts waiting and approved photos; a rejected one does not use a place (as the database
  trigger does). The owner can delete a pending or rejected photo. Buttons have 44 px touch areas.
* New photos come back `pending` from the server (the app sends no status).

**Notifications**
* A bell with the unread count in the Home and My Business headers; a list (newest first, tap or "Mark all as
  read" marks read). The text is what the server wrote (it names the business); it is shown as it is.
* It asks `notifications` with the user's own token; with no table, or no access, the bell is not drawn.
  The count is refreshed when the app opens, comes back to the front, a push message arrives, and after the
  list is closed (at most once in 20 s otherwise).
* A tapped push whose `type` contains "photo" opens My Business.

**Category groups**
* The group of a category is `group_key`, the order inside a group `display_order` (then name), Featured is
  `is_pinned` (ordered by `display_order`). A pinned category is in Featured **and** in its own group. A NULL or
  unknown `group_key` is shown under Other. Empty groups, and Featured when nothing is pinned, are not shown.
  The nine groups and their order are fixed in the app (they are the same on the website); no category is
  named in the app any more.
* The last list is kept on the phone, so Home shows the groups (with Featured) at once and the live list
  replaces it; until either is known there is a placeholder, and after 6 s without an answer the built-in
  list is shown as one plain list.

## 3. Not done / not verified

* **Website and admin**: the admin pages (Photo approvals, Categories board), the web bell and every width
  and light/dark test of them are in the website project, not here. The app has no admin screens.
* **Automatic pre-screen**: no Edge Function for it was found (404 for `photo-precheck` and nine other plausible
  names; a function with another name would not show up here). Check that one runs after each upload, that it
  never sets `approved`, and that a missing moderation key is added in the secrets form.
* **Server-made notifications and push**: not checked (nothing can be uploaded or reviewed from here). Check
  that an upload, an approval, a rejection and an auto-rejection each create the row (a database trigger, so it
  cannot be skipped) and call `send-push`; the app does not call `send-push` itself.
* **Storage**: the bucket is private, but the public key can sign any `{vendor}/public/...` path that exists.
  Please check the Storage policy so that a pending or rejected photo's `public/` file cannot be signed by
  anyone but its owner and admins (not testable without a pending photo).
* Nothing was tried on a phone, and no test photo, category or notification was created, so there is nothing to
  delete.
