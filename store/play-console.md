# Google Play Console: what to enter

The answers for every Play Console form of the first release, in the
order the console asks for them. They follow from what the app does
(nothing collected, no ads, the internet permission only); keep them
true together with `privacy/index.html`: a change to data handling, a
new permission or a dependency that talks to a server updates the
privacy policy, the Data safety form and the content rating at once.
Labels are the English ones (the console follows the Google account's
language). The account steps (identity, phone, device verification)
are logged in the owner's vault, `Projektek/fejlesztoi_fiokok`.

Written 2026-10-14, from the repository and Google's help pages; the
exact wording of a question may differ, the answer by topic holds.

## The bundle

- From CI: a manual run ("Run workflow") on `main` keeps the
  `android` artifact with `app-release.aab`, signed with the upload key
  (the "Signer" step prints "CN=László Zsolt Nagy, O=nagylzs.eu,
  C=HU").
- `version: 1.0.0+N` is version code N. Every upload needs a higher
  build number, on any track; promoting a release from one track to
  another needs none. `1.0.0 (1)` (2026-10-11) went to internal
  testing only; `1.0.0 (2)` (2026-10-15, tessera_flutter 0.2.3: the
  pickers on a phone in landscape) is the one for the closed test.
- Checked 2026-10-14 on the 2026-10-11 bundle: target SDK 36 (Flutter's
  default), the 64-bit native libraries aligned to 16 KB or more (Play
  requires 16 KB page support), and the merged release manifest asks
  for `INTERNET` only (plus AndroidX's app-internal
  `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`); no `AD_ID`.

## 1. Create app

Home → Create app:

| Field | Answer |
|---|---|
| App name | Tessera Studio |
| Package name | `eu.nagylzs.tessera_studio` (final; the `applicationId`) |
| Default language | English (United States) – en-US |
| App or game | App |
| Free or paid | Free (final: a free app can never become paid) |
| Declarations | Developer Program Policies ✓, Play App Signing terms ✓ (required for app bundles; Google keeps the app signing key, CI signs with the upload key), US export laws ✓ (the app's only encryption is the platform's HTTPS) |

## 2. Store settings

Grow users → Store presence → Store settings:

- **App category:** Productivity (as in the Microsoft Store; in the
  Hungarian console "Irodai alkalmazások").
- **Tags:** up to five from Play's list, the ones about spreadsheets,
  office documents, data and file viewing.
- **Contact details:** email `apps@nagylzs.eu` (public); no phone;
  website `https://github.com/nagylzs/tessera-studio`.

## 3. Main store listing

Grow users → Store presence → Main store listing:

- **App name, Short description, Full description:** `name`, `short`
  and `description` of `listing/en.yaml`.
- **App icon:** `screenshots/play-icon.png`; **Feature graphic:**
  `screenshots/play-feature-graphic.png`.
- **Phone screenshots:** `screenshots/play-phone/1-…` to `6-…`, in
  order.
- **7-inch and 10-inch tablet screenshots:** `screenshots/play-tablet/`
  1 to 5, the same images for both.
- No video, no Chromebook screenshots.
- **Translations:** Manage translations → Add your own translation
  text, the 13 other languages with the Play codes of
  `listing/README.md`; name, short and full description from each
  `<code>.yaml`. The graphics stay the English ones (Play shows them
  for every language without its own).

## 4. App content

Policy and programs → App content:

- **Privacy policy:** `https://nagylzs.eu/tessera-studio/privacy/`
- **App access** (also called Sign-in details): all functionality is
  available without special access.
- **Ads:** No, the app contains no ads.
- **Content rating:** email `apps@nagylzs.eu` (IARC writes there, the
  certificate and any appeal link come there). Category: **All Other
  App Types** (a utility: not a game, social, communication,
  reference/news/educational, entertainment or store app). Every
  question **No**:
  - violence, fear, sexuality or nudity, language, controlled
    substances, crude humour, gambling, hate symbols: none;
  - users interacting or exchanging content with each other: no (an
    export leaves through the system share sheet to an app the user
    picks; there is no communication inside the app);
  - sharing the user's location: no; digital purchases: no;
  - a web browser or unrestricted internet access: no. The app
    downloads one data file from an address the user types and shows
    it as a table; it renders no web pages and follows no links.
  Expected result: the lowest rating everywhere (IARC 3+, PEGI 3,
  ESRB Everyone, USK 0). Anything higher means a wrong answer.
- **Target audience and content:** **Ages 18 and over** only. The app
  is a work tool for spreadsheets; the groups 13–15 and 16–17 "may be
  considered to include children in some locales" and bring the
  Families policy into play. The target audience does not restrict who
  can install it (the content rating does), so teenagers can still use
  it. Restrict Minor Access: off. Does the store listing unintentionally
  appeal to children: no.
- **Data safety:** "Does your app collect or share any of the required
  user data types?" **No**. The follow-up questions (encryption in
  transit, deletion requests) are then not asked, and the listing shows
  "No data collected" and "No data shared with third parties". Why, in
  Google's terms ("collect" = transmitting data off the device, to the
  developer or anyone else):
  - opened files, the clipboard (read only on "Open from clipboard"),
    the settings and the stored schemas and pivots are processed and
    kept on the device only;
  - exports go where the user picks (a folder, an app in the share
    sheet), a user-initiated action;
  - opening a URL sends one HTTP request to the server the user named;
    the developer receives nothing. It is the case of Google's FAQ on
    uploads to the user's own cloud storage, where "your app never
    collects or accesses the data in question";
  - no dependency sends anything (`file_picker`, `share_plus`,
    `url_launcher`, `shared_preferences`, `package_info_plus`,
    `desktop_drop`, `http`, the tessera packages); crash reports come
    from Android and Play, not from the app.
- **Advertising ID:** No (no `AD_ID` permission in the merged
  manifest).
- **Government apps:** No.
- **Financial features:** the app provides no financial features.
- **Health apps:** the app has no health features.
- **News and magazine apps:** No.
- **COVID-19 contact tracing and status apps** (if still listed): not
  such an app.
- **Permissions declaration:** not needed, `INTERNET` is not a
  sensitive permission.

## 5. Countries and devices

- Countries / regions: all of them, on every track (each track has its
  own list): nothing in the app is regional.
- Devices: whatever Play derives from the manifest (phones, tablets,
  Chromebooks); nothing to exclude.

## 6. Testing

A new personal account may publish to production only after a closed
test with at least **12 testers opted in for 14 days in a row** (a drop
below 12 restarts the count; recruit 15–20 for a margin).

1. **Internal testing first** (no review, ready in minutes): Test and
   release → Testing → Internal testing → Testers: an email list
   "owner" with the owner's Google account → Create new release →
   upload the bundle (Play App Signing: accept, Google keeps the app
   signing key) → release name `1.0.0 (1)` → the release notes below →
   Next → Save and publish (the review page and the rollout are one
   button). Until the app has been reviewed, testers see it in Play as
   "eu.nagylzs.tessera_studio (unreviewed)"; installed, it is called
   Tessera Studio. On the Xiaomi pad: the opt-in link, install from
   Play, open a CSV through "Open with". Released 2026-10-14 with
   `1.0.0 (1)`; `1.0.0 (2)` the same way (Create new release on the
   same track, notes as below), as the release to promote.
2. **Check the signing:** Test and release → Setup → App signing: the
   upload key certificate's SHA-256 must be the CI key's,
   `A7:92:EE:A7:E5:6F:76:74:93:0C:A4:12:C6:91:E8:A4:FF:16:56:87:68:6D:41:24:53:CC:11:F6:7C:05:2D:0D`.
3. **Closed testing:** Test and release → Testing → Closed testing →
   the track Play creates, "Closed testing - Alpha" (Hungarian console:
   "Zárt tesztelés - Alpha"; no need for "Create track") → Manage
   track → Testers: an email list "testers" (their Google
   accounts), feedback URL or email `apps@nagylzs.eu` → Countries: all
   → promote `1.0.0 (2)` from internal testing → Send changes for
   review (closed releases are reviewed, a few days). Being on the
   list does nothing by itself, and nobody can join or install before
   the approval. After it, send the testers the opt-in link (Testers
   tab): opened in a browser with the Google account of their phone,
   it shows "Become a tester" — that tap is the opt-in — and then a
   link to install from Play. Each tester's 14 days count from their
   own opt-in.
4. **Keep a record of the feedback** (date, tester, what, what changed):
   the production application asks for a summary. In the vault, next
   to the Play Console log.

Release notes for `1.0.0 (1)` and `(2)`:

```
<en-US>
First test release. Please open a few of your own CSV, Excel or JSON files, try the pivot and export something. Feedback: apps@nagylzs.eu
</en-US>
<hu-HU>
Az első tesztkiadás. Kérlek, nyiss meg néhány saját CSV-, Excel- vagy JSON-fájlt, próbáld ki a kimutatást, és exportálj valamit. Visszajelzés: apps@nagylzs.eu
</hu-HU>
```

Message to the testers (Hungarian; most are the owner's acquaintances):

> Szia! Egy ingyenes Android-alkalmazást, a Tessera Studiót
> (CSV-, Excel- és JSON-fájlok kimutatásként) tesztelem a Google Play
> zárt tesztjében. A Google csak akkor engedi nyilvánosan kiadni, ha
> legalább 12 tesztelő 14 napig folyamatosan benne van. 1) Ezen a
> linken csatlakozz ugyanazzal a Google-fiókkal, amelyik a telefonodon
> van: <opt-in link>. 2) Telepítsd a Google Playről. 3) Két hétig ne
> lépj ki a tesztből és ne töröld az appot; nyisd meg néhányszor egy
> saját táblázattal. Ha valami nem működik vagy furcsa, írj az
> apps@nagylzs.eu-ra. Köszönöm!

## 7. Apply for production

After 14 days with 12 or more testers: Dashboard → Apply for
production. Three parts; fill in parts 1 and 3 at the end of the test,
from the feedback record:

1. **About your closed test:** how the testers were recruited
   (acquaintances, colleagues), whether they used every feature (open,
   pivot, filter, export, share), whether their use matched what
   production users will do, a summary of the feedback and how it was
   collected (email, in person).
2. **About your app:**
   - Audience: adults who work with tabular data (office workers,
     analysts, students, small businesses) and want to look at a CSV,
     Excel, OpenDocument or JSON file as a pivot table on a phone or a
     tablet.
   - Value: opens a file straight into a pivot table, with nothing to
     set up; no account, works offline, no ads, nothing collected;
     exports to Excel, OpenDocument, PDF, HTML and more; open source;
     14 languages.
   - First-year installs: the lowest range offered.
3. **About your production readiness:** what changed after the
   feedback; readiness from the automated tests (`flutter test`), CI
   release builds on every platform, the runs on the owner's tablet and
   on phone and tablet emulators, and the closed test.

The application's review takes up to about a week. Once production is
open, for the joint release: turn on **Managed publishing** (Test and
release → Publishing overview) before sending the production release
for review, so the approved release waits for "Publish" on the release
day, like the Microsoft Store's hold.

## Sources

- [Prepare your app for review](https://support.google.com/googleplay/android-developer/answer/9859455)
- [Content ratings](https://support.google.com/googleplay/android-developer/answer/9859655)
- [Target audience and content](https://support.google.com/googleplay/android-developer/answer/9867159)
- [Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
