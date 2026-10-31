# Blocked users: what the app does, and what the server must still do

Written 2026-10-30 for the website / backend developer. **Verified** = read in the app source or in the live
website's public scripts, or checked with a read-only request on that date. **Not verified** = could not be
checked from here (I have no access to the live database's policies or the edge functions' code).

## 1. How a block works today (verified)

* **Admin block:** the website admin (User Manager) runs
  `profiles.update({ is_blocked: true, blocked_at: <now>, blocked_reason: <text or null> }).eq("id", userId)`.
  **Unblock** sets `is_blocked: false, blocked_at: null, blocked_reason: null`. It is a plain table update from
  the browser; nothing else happens (no session is revoked, no auth ban).
* **Website enforcement (client-side only):** after sign-in and on page load the website reads
  `profiles.is_blocked, blocked_reason` for the user and, if blocked, shows the "Account Blocked" page instead
  of the app. A user who is already signed in keeps using the site until the page is reloaded.
* **The mobile app did not check the flag at all** (nothing in the app read `is_blocked`; it only contained two
  unused admin helpers that set it). That is why a block on the website had no effect in the app.
* The columns `profiles.is_blocked` and `profiles.blocked_reason` exist (a request selecting them is accepted;
  an unknown column is refused).

## 2. What the app does now (implemented 2026-10-30, needs an app release)

* Reads `profiles.is_blocked, blocked_reason` for the signed-in user, with the user's own token (the same query
  the website makes): after sign-in, when the app starts with a saved session, whenever the app comes back to
  the front (at most once a minute), and each time the session token is refreshed (about hourly).
* A blocked account sees a full-screen **Account Blocked** page instead of the whole app: "Your account has been
  blocked for misuse or policy violation.", the admin's reason, "Contact support" (mail to
  info@konnectkashmir.com) and **Sign out** (English, Hindi, Urdu). Unblocking removes the page at the next check.
* **A failed check never blocks or unblocks anyone** (fail-open, like the website) and is retried after 30, 60
  and 90 seconds.
* **Before the important actions** the app asks again (at most every 10 seconds, never waiting more than 3
  seconds) and stops a blocked account with "Your account has been blocked.": unlock contact, claim ad credits,
  create / update a business, post a review, create a job, apply to a job, submit a report.
* Tested with 20 automated tests. **Not tried on a phone with a really blocked account**: to try it, block a
  spare account in the admin panel, then open the app on that account.

## 3. What is still missing: the server (the most important part)

Everything above is client-side. Anyone who calls the backend directly (not through the app or the website) is
not stopped. I did not find, and could not check, any server-side rule that uses `is_blocked`.
**Not verified:** the live RLS policies and the edge functions' code. Check what is there first, test on a
copy or branch, and keep a way back.

### 3.1 One helper and restrictive policies

Restrictive policies are *added to* the existing ones (both must allow), so they cannot open anything up; they
only close it for blocked users.

```sql
create or replace function public.is_user_blocked(uid uuid)
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((select is_blocked from public.profiles where id = uid), false) $$;

revoke all on function public.is_user_blocked(uuid) from public;
grant execute on function public.is_user_blocked(uuid) to anon, authenticated, service_role;
```

For each table where a blocked user must not write (the tables the app writes to: `vendor_reviews`,
`reports`, `job_applications`, `jobs`, `vendors`, `call_clicks`, `ad_views`, `referrals`; decide per table):

```sql
create policy "blocked users cannot insert" on public.vendor_reviews
  as restrictive for insert to authenticated
  with check (not public.is_user_blocked(auth.uid()));

create policy "blocked users cannot update" on public.vendor_reviews
  as restrictive for update to authenticated
  using (not public.is_user_blocked(auth.uid()))
  with check (not public.is_user_blocked(auth.uid()));
```

**Do not** add a restrictive policy to `SELECT` on `profiles`: the blocked user must still be able to read
their own row, otherwise neither the website nor the app can tell them they are blocked.

### 3.2 Edge functions
At the top of every function that spends or gives credits or reveals data (the app calls
`unlock-vendor-contact`, `claim-ad-credits`, `process-referral`; also any register / write function the website uses),
after the user is identified from the JWT:

```ts
const { data: p } = await admin.from("profiles").select("is_blocked").eq("id", user.id).maybeSingle();
if (p?.is_blocked) {
  return new Response(JSON.stringify({ error: "account_blocked" }),
    { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
```

Also make the contact-reveal path (the RPC `can_access_vendor_contact`, `has_unlocked_vendor`) return false
for a blocked user, so a blocked user cannot read a contact that is stored behind those checks.

### 3.3 Make the admin's Block button do more than set a flag (recommended)
Move block / unblock into an admin-only edge function that, besides the `profiles` update, bans the account in
Supabase Auth (service role: `auth.admin.updateUserById(id, { ban_duration: "876000h" })`; unblock:
`"none"`). A banned user cannot refresh a token or sign in again, so the block applies on the next token
refresh even to a client that never reads the flag. (Not verified how the current admin panel and the OTP
login would behave with a banned user: test it.)

## 4. How to test the server side
With a **test user's own token** (never the service key) after blocking that user:

1. `insert` a review / report / application → refused (RLS error).
2. `unlock-vendor-contact` and `claim-ad-credits` → 403 `account_blocked`.
3. `select` the user's own `profiles` row → still allowed (so the Blocked page can show the reason).
4. Unblock the user → all of the above work again.
5. A normal (not blocked) user is unaffected everywhere.

## 5. Notes
* The reason text is shown to the blocked user: write it for them.
* The app's check is a courtesy and a first line of defence; the server rules are what makes a block real.
