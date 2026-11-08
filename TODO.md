# TODO

Open work on Tessera Studio, in priority order within each section.
Tick items as they land; once releases start, a feature commit also
adds its bullet under `## Unreleased` in `CHANGELOG.md`. Rules and
conventions live in `CLAUDE.md`, not here.

## Next device round

What only real devices can check, collected on `dev` and tested in one
round when a batch of features is ready (`CLAUDE.md`, "Branches and
releases"). The iPhone and the pad take one TestFlight and one Play
internal testing build; the Mac and Windows sessions build from `dev`.

- Charts on the iPhone 14, the Xiaomi pad and a phone: the chart button
  in each placement (beside the grid from 840 × 480 dp, above it from
  600 × 600, instead of it on a phone, and back), full screen and out
  again (back, the button), the five kinds, a cell's breakdown, both
  orientations, the system's larger text sizes.
- Chart exports on the devices: PNG, SVG and PDF through the share sheet
  and Save as… (Android, iOS), in every look; open them in the
  platform's viewers. On the Mac, Share beside Save as….
- The group header cell as the tap target (tessera_flutter 0.2.7): on the
  iPhone and the pad a tap on a region's name expands or collapses it, a
  swipe across it scrolls without toggling, and "Total" folds everything
  only through its `−`.
- Whole numbers in XLSX and ODS (tessera_xlsx and tessera_ods 0.2.4):
  counts and integer sums without decimals in Excel (Windows has none;
  LibreOffice is checked) and in Numbers on the Mac or the iPhone.

## Viewer flow

- [ ] "Expression help" in the app menu, perhaps later (left over from
      the help for expressions, Done): tessera_flutter's `ExpressionHelp`
      on a page of its own, without insertion, to read before opening an
      editor; with the open file's columns where there is one.
- [ ] On the Mac the window's title bar follows the system appearance,
      not the app's Theme setting: Light in the app on a dark Mac gives a
      dark title bar over a light window (found 2026-10-20 taking the
      Mac shots, which were therefore taken with the Mac's appearance
      matching). Set the window's `NSAppearance` from `AppSettings.themeMode`
      (aqua / darkAqua / nil for System) through a small channel. Polish,
      not a release blocker.
- [ ] Cube page follow-ups: a "Settings" entry to restore the automatic
      layout after an explicit choice.
- [ ] Save/load a pivot layout as a `.json` file (`CubeConfig` /
      `CubeJson`, through the file picker), e.g. to apply one pivot to
      another file of the same structure on another device. Less urgent
      since pivots are remembered per structure and snapshots carry
      theirs. The same item sits in `../tessera/TODO.md` for the example
      app; whichever lands first, keep the example minimal.
- [ ] **Question for the owner: Japanese and Chinese in the PDF export?**
      The bundled Noto Sans has no CJK glyphs, so Japanese and Chinese
      text — in the data, or the ja/zh tessera strings such as the total
      — comes out as stray marks in a pivot's PDF and as `?` in a chart's
      (the other formats are fine).
      Prerequisite for every option but the last: per-character font
      fallback in tessera_pdf (in `../tessera/TODO.md`), because the CJK
      fonts lack ő, ű and Cyrillic, and one PDF may need both.
      Measured 2026-10-09 (Noto Sans JP/SC/TC from google/fonts, static
      instances; today's arm64 APK 20.5 MB, Play download about 8–9 MB;
      "Play" = brotli, close to what Play delivers):

      | Fonts (TrueType, as dart_pdf needs)        | APK      | Play     |
      |--------------------------------------------|----------|----------|
      | JP + SC complete, regular + bold           | +18.5 MB | +14.6 MB |
      | JP + SC, standard sets, regular + bold     |  +6.0 MB |  +5.1 MB |
      | JP + SC, standard sets, regular only       |  +3.0 MB |  +2.5 MB |
      | TC (Traditional), Big5 set, regular + bold |  +5.9 MB |  +4.7 MB |

      Standard sets: JIS X 0208 (6 879 characters) for Japanese, GB2312
      (7 445) for Simplified Chinese — everyday text; rare characters
      (names, places) still fail. Japanese and Chinese need separate
      fonts: shared characters are drawn differently. Regular only: bold
      cells (totals, headers) fall back to regular for CJK.
      Which way?
      1. Bundle for everyone (one of the rows above).
      2. Only for those who need it: on Android as language-qualified
         Android resources (`res/raw-ja`, `res/raw-zh`), which Play
         delivers only to devices with that language (to verify with
         bundletool); the in-app language menu then needs an on-demand
         language download through Play (Play Core), or falls back to
         case 1. Web: lazy assets, fetched only by a PDF export that
         needs them. Desktops: bundled.
      3. Leave it: say so in the store listing, revisit on demand.
      (Installed system fonts are no way out: Noto CJK on Linux is
      OpenType/CFF, which dart_pdf cannot embed.)
- [x] Charts (`lib/charts/`, 2026-11-07, branch `charts`, `dev` since
      2026-11-08, in no build yet): the pivot or the current cell's breakdown as bars, stacked bars,
      a line, a pie or a scatter chart; beside the grid, above it, or on a
      phone in its place; remembered per structure; PNG export. The owner
      chose the data, the phone's switch and PNG only on 2026-11-06; the
      tablet rule and the defaults were proposed then, without objection.
- [ ] Charts, before they ship: the real devices of "Next device round";
      so far Linux under Xvfb, the API 36 phone and tablet emulators, the
      Mac and Windows (2026-11-07 at `23f84fa`) and the web (2026-11-08 at
      `eb04313`, Chrome under Xvfb: a snapshot through the file chooser, a
      group toggled by its label, the chart beside the grid, full screen and
      Esc, at 500 px in the grid's place and back, a pie, and PNG, SVG and PDF
      downloaded and right). Then the README's feature list, the store
      listings in 14 languages and the screenshots, and publish the privacy
      page with its new date.
- [ ] A chart's legend that does not fit scrolls inside its 76 px with no
      sign that it does (found on the web, 2026-11-08: a pie of 12 slices at
      500 px wide listed 11, Singapore hidden below). A visible scrollbar,
      a fade at the edge, or more room before it scrolls.
- [ ] Charts, later: the chart's own dimensions independent of the pivot
      (`ChartData.fromFacts`), a scatter of single facts
      (`ScatterData.ofFacts`), values on a pie's slices when touched.
- [ ] A raw date on a pivot axis reads as a whole timestamp in the grid,
      "2025-01-01 00:00:00.000Z" (`Dimension.formatValue` in tessera, found
      2026-11-07). The charts shorten it themselves; the grid, the
      current-cell line and the exports do not. Library work.
- [x] Share on the Mac, beside Save as… (owner, 2026-11-07). Tried at
      `d01669a`: `share_plus`'s menu opens at the button, Mail gets the
      attachment under its real name, accents too, in the sandbox and the
      release build (`~/transfer/tessera-studio/reports/20261107-0945-mac.md`).
- [ ] Sending a file on Linux, for later (owner, 2026-11-07): `share_plus`
      refuses files there, so it takes our own code, the desktop portal's
      email call or `xdg-email --attach`; not tried.
- [ ] Sending a file on Windows: not through `share_plus`. Its mixed path makes
      the dialog fail, and with a native path it stays loading, cannot be
      selected from or closed, and outlives the app until Explorer restarts
      (`~/transfer/tessera-studio/reports/20261107-1034-windows.md`). It would
      not reach the owner's Betterbird anyway, and neither would MAPI while
      the PC's default mail client points at a missing Thunderbird. No plan.
- [ ] A grid narrower than its row headers shows no values: the pinned
      columns fill it (`TableView` warns "pinned columns ... exceeds the
      viewport width"). Found on the Mac on 2026-11-07, dragging the chart's
      divider to its limit, with headers of 235 px in 200. The app cannot
      know that width, so `SplitView` cannot stop there; the grid could stop
      pinning what does not fit. Library work (`CubeView`). A phone with
      several row dimensions probably meets it too; not tried.
      The same happens in height: with "Editors on top" a low window leaves
      the grid less than its two header rows ("pinned rows with a total height
      of 56.0, which exceeds the viewport height of 20.0"; the Mac, 2026-11-07).
- [ ] Large text outside the charts (found 2026-11-07 while testing them;
      fine at the owner's 1.5, debug builds show it, release builds cut it
      quietly): at 2 a 17 px overflow to the right before the cube opens, on
      a phone either way up, not pinned down; at 3 the schema page's bar by
      349 px and the editors by 850 px in a 900 × 500 window.
- [ ] Entry points beyond the desktop argument, Android intents, the
      clipboard and drag and drop: a web `?open=<url>` query parameter,
      Windows and Linux file associations with packaging (below).
- [ ] Idea (owner, 2026-10-19; not decided for the first release): a
      file dropped on the cube page opens it, as viewers do (mpv, Eye of
      GNOME). Today only the home screen is a drop target. Replace the
      file in place, or ask first when the pivot differs from its
      default? The schema and layout are remembered either way.
- [ ] Idea (owner, 2026-10-15; not decided for the first release): an
      opt-in "Esc closes the app" setting for desktops (Windows, Linux,
      macOS), off by default, for use as the viewer of a file manager:
      Double Commander's F3 with an external viewer → look → Esc → next
      file → F3 (IrfanView has the same option). Esc keeps closing
      menus, dialogs, the editors sheet and full screen first; only an
      Esc nothing else takes exits, through
      `ServicesBinding.exitApplication` (no `dart:io` in `lib/`). A
      checkable menu entry like "Editors on top", key
      `settings:escClosesApp`, the label in all 14 languages. Worth
      measuring the time from launch to the first pivot for this use.
- [ ] Clipboard: files copied as file objects (Explorer, Finder, GNOME
      Files) are not text, so Flutter's `Clipboard` cannot see them;
      `super_clipboard` (all platforms, iOS and macOS included) reads
      `text/uri-list` and file items and would let "Open from
      clipboard" take them too. Also HTML tables copied from a browser
      (`text/html`) could be parsed into rows.
- [ ] Old Excel files (`.xls`, the binary BIFF8 format of Excel 97–2003;
      a closed-test user had some, 2026-10-21): today "Unsupported file
      type". Library work first: tessera has no reader for it, and BIFF8
      lives in an OLE2 compound file, so a reader is a package of its
      own (`tessera_xls`), unless a maintained pure-Dart reader exists
      to build on. Then `FileFormat.xls`, the media type
      `application/vnd.ms-excel` in the Android intent filters and the
      Apple document types, the MSIX file types and the Linux desktop
      entry, and the store listings' format lists.

## App

- [ ] Later release (owner, 2026-10-09): a curated theme gallery — more
      grid styles than the six of "Grid style…", picked and named with
      care, shown as previews of a sample cube, each with its export
      theme and checked in light and dark.
- [ ] Settings persistence beyond theme and language (last export
      format…) — `SettingsStore` is the place.
- [ ] Other text encodings: a CSV or JSON in Latin-1 / Windows-125x
      (Excel's plain "CSV" on Windows) now gets the failure page's
      advice. Offer "Read as…" there instead: tessera's sources take an
      `encoding:`; Dart has `latin1` built in, Windows-1250 (Central
      Europe) and the others need a codec package (check iOS/macOS
      support first).
- [ ] Lower priority (owner, 2026-10-22): survive the system killing
      the app in the background (MIUI does it readily; iOS too). The
      task comes back with a recreated activity and a fresh Dart
      isolate, so the home screen shows: `MainActivity.onCreate` skips
      the intent when `savedInstanceState` is set and empties
      `cacheDir/open` either way. Keep the open file's cache copy
      across a recreation (empty the folder on a fresh start only),
      remember its path and name (Flutter's state restoration, or
      `onSaveInstanceState` on Android), and reopen it; the pivot then
      comes back by itself from `LayoutStore`, unsaved schema edits
      only if they are restored too. Test with `adb shell am kill
      eu.nagylzs.tessera_studio` while the app is in the background.

## Packaging and release

- [ ] Release store by store (owner, 2026-10-30), replacing the joint
      release planned 2026-10-23: the reviews took over a week (macOS 8
      days; iOS still waiting after 10), and a final build for every
      store would have meant one more round of them. 1.0.0 goes out in
      each store as it is approved; the first update, 1.1.0, brings the
      same code to every store; the announcement waits for Android.
      Before each publishing step, the open bugs in this file.
      - Microsoft Store: 1.0.6.0 published 2026-10-30 ("Publish now";
        Store ID `9PB0S6Q0K039`).
      - macOS: `1.0.0 (5)`, approved 2026-10-28, released 2026-10-30
        ("Ready for Distribution"; App Store ID 6824598370).
      - iOS: `1.0.0 (5)`, approved and released 2026-10-31 (the same
        App Store ID).
      - Then 1.1.0 (`1.1.0+N`) from main, with the workbook sheets,
        computed dimensions and the fixes since build 5 (one is a macOS
        bug: a file opened from Finder while the schema page was up kept
        the old file's columns): a new App Store version for iOS and
        macOS once their 1.0.0 is out, the MSIX 1.1.N.0 in a new
        submission. Android's production release and the GitHub Release
        (Linux, the Windows zip: `releases` in
        `tool/linux_metadata.dart`, the tag `v1.1.0`, CI's draft) start
        at 1.1.0, Android once production access is granted (the 14
        days end around 2026-11-03/04, then Google decides within about
        7 days). CHANGELOG.md starts with it. 2026-11-01: `1.1.0 (10)`
        (`1ffd640`) in review for iOS and macOS, the MSIX 1.1.10.0 in
        certification, the GitHub Release `v1.1.0` made; Android waits
        for production access.
      - 1.2.0 (`1.2.0+11`, 2026-11-06), the help for expressions, goes
        to Android's closed test first, while Google reviews the
        production application (sent 2026-11-06, whose answers say the
        help comes in the next build); the owner tried it on the pad and
        the phone and sent it there the same day.
      - 1.2.1 (`1.2.1+12`, 2026-11-07): Google granted production access
        on 2026-11-07, and Android's production release starts here, with
        1.2.0 and the PDF font fix from the `charts` branch (`0d783e6`:
        the no-break space, the thousands separator in cs, fr, hu, pl
        and ru, printed as "¡"; reported upstream as DavBfr/dart_pdf#2003).
        The released 1.1.0 has that bug in every store. Sent to Google's
        production review 2026-11-07 (managed publishing off). The owner
        decided on 2026-11-08 that the other stores follow with the same
        1.2.1, and the charts come later as 1.3.0. On 2026-11-08: the
        GitHub Release `v1.2.1` published (Linux packages, the Windows
        zip); iOS and macOS `1.2.1 (12)` tested through TestFlight and
        submitted (automatic release); the MSIX 1.2.12.0 submitted
        (published as soon as it is certified). Each store's 1.2.1 goes
        live on its approval; tick this item when all four are out.
      - The README's "Not released yet" note gave way to the store
        links (2026-11-01); Google Play's joined them on 2026-11-08,
        while its production release was still in review.
- [ ] Release signing in CI: the Android upload key, Apple
      certificates and profiles, Windows code signing — as CI secrets
      only; Play and App Store uploads manual at first. Android done
      (2026-10-11): `key.properties`, the secrets
      `ANDROID_UPLOAD_KEYSTORE` / `ANDROID_UPLOAD_PASSWORD`, the
      owner's upload key (kept in the owner's password manager),
      "CN=László Zsolt Nagy, O=nagylzs.eu, C=HU", SHA-256
      `A7:92:EE:A7:E5:6F:76:74:93:0C:A4:12:C6:91:E8:A4:FF:16:56:87:68:6D:41:24:53:CC:11:F6:7C:05:2D:0D`
      — CI run 38131897750 signed the bundle with it. Apple and Windows
      remain.
- [ ] Windows, Microsoft Store first and a portable zip besides (owner,
      2026-10-10; CI builds both, see CLAUDE.md). Done 2026-10-10: the
      Partner Center account, "Tessera Studio" reserved, its identity in
      the repository variables and `msix_config`, CI builds the Store
      package. 2026-10-11: submission 1 prepared — pricing (free),
      properties (Productivity, the privacy policy, apps@nagylzs.eu),
      age ratings, the CI's 1.0.0.0 package (validated), the listings in
      all 14 languages imported with `tool/ms_listing.dart`, testing
      notes; submitted 2026-10-11, **certified 2026-10-12, "Ready to
      publish"**, held "until I select Publish now": on the joint release
      day, Partner Center → Tessera Studio → Publish now. Store ID
      `9PB0S6Q0K039` (`https://apps.microsoft.com/detail/9PB0S6Q0K039`
      once published; then into the README). A newer package before the
      release means a new submission and certification: 1.0.0.0 from
      2026-10-11 predated the xlsx/ods 0.2.2 fix, so 1.0.6.0 (`1.0.0+6`)
      replaced it, resubmitted and **certified 2026-10-21**, held for
      Publish now as before (`1.0.0+7` changed Android only), and
      **published 2026-10-30**. Package versions are `major.minor.N.0` since
      2026-10-20 (CI's `--version`, N the build number: `1.0.0+4` →
      `1.0.4.0`), always above the last. Upload by hand at first. Account log: the owner's vault,
      `Projektek/fejlesztoi_fiokok`. Tried on the owner's Windows (2026-10-10, CI's
      manual-run build): the portable zip runs; the test MSIX installs
      once its certificate is in Local Machine → Trusted People, and
      Explorer offers Tessera Studio under "Open with" for a CSV, which
      opens on the file (and on its remembered pivot the second time).
      Decide on signing the portable exe (unsigned means
      SmartScreen's "Windows protected your PC" → More info → Run
      anyway; a code-signing certificate or service costs money).
- [ ] Google Play: the account exists (2026-10-12), identity verified
      2026-10-14; phone and device verification are the owner's. Then
      the app, the listing, the App content forms, internal testing and
      a closed test of 12+ testers for 14 days before production can be
      applied for: every answer in `store/play-console.md`. Account
      log: the owner's vault. Internal testing released 2026-10-14
      (`1.0.0 (1)`); `1.0.0 (2)` (2026-10-15, the landscape pickers fix)
      is the build for the closed test.
- [ ] Linux (owner, 2026-10-20): a tarball and a `.deb` for x64 and
      arm64, built by CI and attached to the GitHub Release; later our
      own Flatpak repository (next item); not Flathub (below). On the
      `linux-packaging` branch since 2026-10-20: `linux/packaging/` (the
      desktop entry, the snapshot MIME type with its `TSNP` magic, the
      AppStream metainfo and the `.deb` control template, all written
      by `tool/linux_metadata.dart` from `store/listing/` and the ARB
      files and checked by `test/linux_metadata_test.dart`; the icon on
      a rounded tile; the tarball's `install.sh` and README),
      `tool/linux_package.sh` (both packages), `tool/linux_smoke_test.sh`;
      CI builds in an `ubuntu:22.04` container (glibc 2.35 and later) on
      x64 and arm64 runners, tests in fresh Ubuntu 22.04 / 24.04 and
      Debian 12 containers, and drafts the release on `v*` tags (with
      the Windows portable zip); Flutter is pinned CI-wide (3.47.7).
      Without xdg-desktop-portal "Open file…" now says what is missing
      (`PickerUnavailable`), and the dialog has a localized title
      (2026-10-20). Before each release tag, the version and date go
      into `releases` in `tool/linux_metadata.dart` (AppStream wants a
      dated release, and the metainfo's screenshots are fetched from
      the tag); first for `v1.1.0`. Still to do: the GTK file chooser's
      filter is named "Custom", hardcoded in `file_picker_linux` (an
      upstream issue).
- [ ] Our own Flatpak repository (owner, 2026-10-20: yes, after the
      first release): built by CI from the tarball, hosted as static
      files (nagylzs.eu or GitHub Pages), GPG-signed, a `.flatpakref`
      for a one-click install, the runtime from Flathub; it gives the
      menu entry, the MIME types, the sandbox and `flatpak update` like
      a Flathub app. finish-args: `--share=ipc --socket=wayland
      --socket=fallback-x11 --device=dri --share=network` (URLs the user
      opens) and no filesystem access: `file_picker_linux` uses the
      FileChooser portal, "Open with" Flatpak's file forwarding.
- Flathub: not, by decision (2026-10-20). Its requirements
      (`https://docs.flathub.org/docs/for-app-authors/requirements`,
      read 2026-10-20; the generative AI policy was amended on
      2026-09-04) rule this app out: "Flathub manifests must not contain
      AI-generated or AI-assisted content. Disclosure does not exempt
      manifests from this restriction."; "AI tools or agents must not
      open or automate Flathub submission pull requests, or generate
      their commit messages, descriptions, review comments, or
      replies."; AI-generated code must be disclosed ("The disclosure
      must identify the affected parts and approximate extent") and
      "Reviewers may reject a submission … based on the extent or role
      of generated material"; "Low quality, automated or machine-
      generated or mixed translations cannot be used." (the interface,
      the desktop file and the metainfo); "Applications that have only
      existed for a very short period of time will generally not be
      accepted." The id `eu.nagylzs.tessera_studio` would have been
      valid, verified through `https://nagylzs.eu/.well-known/
      org.flathub.VerifiedApps.txt`.
- [ ] Store screenshots: shot list and demo data in `store/screenshots/`;
      the desktop (README), Google Play phone and tablet, and Microsoft
      Store sets, the Play feature graphic and 512 px icon are done.
      Still to do: Apple's on the Mac. The README is rewritten
      (2026-10-11): what the app does, the promise, screenshots, the
      platforms' state — update its "Not released yet" note and the
      platform table at the release. The listing texts are done
      (`store/listing/`); a native speaker's read of the translations
      would not hurt, the owner reviews Hungarian.
- [ ] GitHub issue forms (`.github/ISSUE_TEMPLATE/*.yml` and a
      `config.yml`), since the App Store's support URL points at the
      issues: a bug report (platform, the version from About, steps,
      what happened; a warning not to attach confidential files, with an
      offer to describe the data instead), a translation correction
      (language, where the text appears, current and suggested wording;
      the README's Translations section says where the texts live), and
      a question (the user guide linked first). `config.yml` adds
      apps@nagylzs.eu as the contact for anything else.
- [ ] After the release: a line in About saying that the languages
      other than English and Hungarian are AI translations and inviting
      corrections, linking the README's Translations section (a new
      string in all 14 languages).
- [ ] App Store: iPhone Duo screenshots (outer 1398 × 2034, inner
      2007 × 2853) become required in April 2027 for apps built with the
      iOS 27.1 SDK or later (Apple's screenshot specifications, checked
      2026-10-20); a simulator for it, once Xcode has one.
- [ ] After the first release: register `application/vnd.tessera.snapshot`
      with IANA naming Tessera Studio as the application (form and field
      values in `../tessera/TODO.md`), then claim the type in the file
      associations of every platform, including the Android manifest.
- [ ] iOS and macOS on the owner's Mac (the folders, names, icons and
      CI builds exist; bundle id `eu.nagylzs.tessera-studio`, registered
      with the team 2026-10-19; runs on the Mac mini and the iPhone 14
      since 2026-10-15). "Open with" from Finder and the Files app,
      `.tsnp` as the app's own type, the iPad share origin and the
      export-compliance key landed 2026-10-19 (`CLAUDE.md`). Drag and
      drop onto the home screen works on the Mac (2026-10-19). Still to
      do: the share sheet on an iPad (an iPad simulator); JSON Lines for "Open with"
      (needs an imported type: there is no system one).

- [ ] Idea (owner, 2026-10-15; not decided for the first release): a
      web demo on GitHub Pages (`https://nagylzs.github.io/tessera-studio/`,
      or under nagylzs.eu next to the privacy policy), deployed by CI on
      `v*` tags with the matching `--base-href`, linked from the README,
      the store listings and the tessera guide; with the `?open=<url>`
      parameter (Viewer flow) a link could open the demo files directly.
      Check first, for the web target as a whole: Flutter's web build
      by default loads CanvasKit from gstatic.com and missing glyphs'
      fonts from fonts.gstatic.com — requests the user did not start,
      against the privacy promise. `--no-web-resources-cdn` bundles
      CanvasKit; verify the rest in the browser's network tab.

## Done

- [x] The stores' pivot PDFs printed the thousands separator as "¡" in cs,
      fr, hu, pl and ru ("1¡771¡020"), since at least 1.1.0. Fixed in the
      bundled fonts (`0d783e6` here, `64bdf09` on `main`) and shipped as
      1.2.1 to every store (2026-11-08; see the release item). The cause is
      in `package:pdf` (3.13.0 and 3.13.1, `TtfParser.readGlyph`): reported
      as DavBfr/dart_pdf#2003, and the open #1980 holds the same check
      among much else; the one-point glyphs can go once it is fixed there.
- [x] Number formats in XLSX and ODS pivot exports (found 2026-11-08 by
      the Windows test of 1.2.1): every value cell got the export
      theme's one format, `CubeExportTheme.numberFormat`, two decimals
      by default, so a count read "1 014,00" in Excel and LibreOffice
      while the grid and the PDF say "1 014"; exports had done this
      since 1.0. Fixed in tessera_xlsx and tessera_ods 0.2.4 (owner,
      2026-11-08, before the charts): a whole number gets the theme's
      format without decimals, as the grid and the text formats show
      it, the others keep it; tested there through LibreOffice's "as
      shown" csv.
- [x] Help for expressions (a closed-test user, 2026-11-04, could not
      write a formula without knowing the syntax and the functions, and
      the app has no help offline). The help is tessera_flutter's
      (agreed with the owner; 0.2.5): a ? at the end of every expression
      field opens a reference — what the expression does there, examples
      with the file's own columns, the columns, operators, values, empty
      values, the functions — where a tap inserts at the cursor; full
      screen on a phone, offline, in the app's language. Checked on the
      Android emulator and the Linux build from the owner's laptop,
      which found what 0.2.6 fixed: on desktop every return from the
      help selected the whole expression; on a phone in landscape with
      the keyboard up the filter dialog had no room for its rows and the
      dimension picker's form hid its field; a rotation mid-edit lost
      the forms' labels and the help's insert.

- [x] Sheets of .xlsx / .ods files (a tester, 2026-10-23: only the first
      sheet could be opened; his workbook starts with a README sheet).
      A workbook opens on the sheet it was saved on, as Excel and
      LibreOffice do (owner's choice), else on its first sheet with a
      value; a sheet with a heading and no rows gives way to the next.
      With several sheets, the title of the schema and cube pages shows
      the sheet with a ▾ and opens the list (hidden and empty sheets
      left out); each sheet is read like a new file, with its own stored
      schema and pivot, and exports are named "<file> - <sheet> …".
      Library work: `sheets()` in tessera_xlsx and tessera_ods 0.2.3.
      The schema page is keyed by document now, as the workbench was: a
      file arriving while it was up kept the old file's columns.
      Checked with the tester's file under Xvfb and on the API 36
      emulator.
- [x] Computed dimensions (owner, 2026-10-22: a list of movies, the
      average rating per decade of the integer `year`): the dimension
      picker's "Expression…" entry, pinned under the list, adds an
      `ExpressionDimension` such as `floor(year / 10) * 10` with an
      optional label ("Decade"). Library work, tessera_flutter 0.2.4;
      the engine already grouped, saved and restored them, so the
      layout store brings them back with the file. Checked under Xvfb
      against the local packages (decades with the average rating,
      restored after a restart; `rating >= 8`; the full-screen picker).
      Follow-ups in tessera's TODO.md: editing from the chip, localized
      true/false.
- [x] Android: a file opened from Telegram showed the schema page, but
      after a screenshot the launcher icon brought back the home screen
      and the page seemed lost (owner, Xiaomi pad, 2026-10-22). Telegram
      starts viewers without `FLAG_ACTIVITY_NEW_TASK`, so the
      `singleTop` activity ran in Telegram's task (Telegram's icon on
      the recents card), and the launcher started a second, empty
      instance. `MainActivity` is `singleTask` now: one instance in its
      own task, a file arriving through `onNewIntent`. Verified on the
      API 36 emulator from the Files app, which starts viewers the same
      way: the launcher returns to the schema page, back twice returns
      to Files, a second file reaches the running instance, the in-app
      picker still returns its file.
- [x] Android's "Open file…" greyed out files the app opens: the picker
      filters by the media type the system has on record for a file, and
      `file_picker` builds that filter from the device's extension table,
      dropping the extensions it does not know — so `.tsnp` (the app's
      own snapshots; confirmed by the owner on the Xiaomi pad),
      `.jsonl` and `.ndjson` could never be picked, nor a CSV that a
      website served as Excel or as binary data (a closed-test user's
      screenshot, 2026-10-21). On Android the picker now shows every
      file (`FileType.any`), and a name without a known extension is
      judged by its first 64 KB before the whole file is read, so a film
      picked by mistake is turned down as "Unsupported file type"
      without filling the memory (`test/file_opener_test.dart`,
      2026-10-21). The other platforms filter by extension, which works.
- [x] A 1-point black square at the top-left corner of the iOS screen in
      the simulator's screenshots (debug build). Not on the device: a
      screenshot of the TestFlight release build on the owner's iPhone 14
      has no such pixel (iOS rounds all four corners of its screenshots
      transparent), so a debug or simulator artefact, not the app's
      drawing; the store shots cover it (2026-10-20).
- [x] A file opened from outside ("Open with", the share sheet, a drop)
      left the old page's sheets and dialogs on top of the new file's
      page, still showing — and acting on — the old file (found on the
      iPhone simulator with the editors sheet open, 2026-10-20; Android,
      the desktops and the Mac alike). `app.dart` now closes every route
      above the root whenever the document, the failure or the page
      changes (a navigator key, `popUntil(isFirst)` in an effect); a
      widget test opens a dialog, delivers an open request and expects
      the dialog gone (2026-10-20).
- [x] The dimension picker, the aggregate picker and the filter's
      value list on a phone in landscape: the search field opened the
      keyboard at once and the fixed-size dialog left the list no room
      (owner, iPhone 14). tessera_flutter 0.2.3 opens them full screen
      under 480 dp of height, without opening the keyboard (2026-10-15).
- [x] Android back with one of tessera's menus open (a value chip's
      "Show values as", "Rows ▾", a dimension's `▾`, the filter
      editor's add menu) closes only the menu; it used to close the
      editors sheet on a phone and the whole file on a tablet. Flutter's
      `MenuAnchor` ignores back (flutter#80052): tessera_flutter 0.2.2
      menus hold a local history entry while open, and the cube page's
      `PopScope` lets that pop through (2026-10-11).
- [x] tessera_pdf 0.2.1: the PDF's page title, date and page numbers in
      the cell text colour, so the standard style's PDF has the same
      green headers as the other formats; the light PDF variant is gone
      (2026-10-11).
- [x] Store listing texts in all 14 languages (`store/listing/`): the
      English master reviewed by the owner (American English), 13
      translations with the app's own terms, every store's fields within
      its limits (`test/store_listing_test.dart`) (2026-10-10).
- [x] Privacy policy (`store/privacy/index.html`, English and Hungarian)
      published at `https://nagylzs.eu/tessera-studio/privacy/`, checked
      identical to the repository's (2026-10-10).
- [x] "Tessera snapshot" in the export dialog ("To reopen in Tessera
      Studio"): the facts with the pivot and expanded groups in one
      `.tsnp`, named like the source, which reopens as it was
      (2026-10-09).
- [x] Failure page for a file that was read but cannot be opened: what
      went wrong in words (not UTF-8, damaged, syntax error, empty,
      headings only, other), the technical detail folded away, the rows
      read before an import error, "Open another file…", "Schema…" on
      the cube page; over the previous document, which close returns
      to (2026-10-09).
- [x] CI: analyze, format, tests and unsigned builds of all six
      platforms on every push (GitHub's Windows and macOS runners for
      those); downloadable builds for tags and manual runs; iOS and
      macOS folders added for it (2026-10-09).
- [x] About in the overflow menu: version and build, copyright and
      licence, the "free and ad-free, forever" promise, links to the
      tessera guide and the source, the licences page with Noto Sans
      (2026-10-09).
- [x] Grid styles: "Grid style…" in the menu with six styles (standard,
      spreadsheet, gradient, hue levels, high contrast, compact), each
      with a matching export theme the exports follow; remembered;
      checked in light and dark (2026-10-09).
- [x] The pivot is remembered per source structure (spec, expanded
      groups, shown aggregates; `LayoutStore`), so a known file opens on
      last time's pivot without the schema page; the banner says so and
      offers "Default pivot" (2026-10-09).
- [x] Export: Share (phones, tablets) or Save as… opens a dialog with
      the cube in every format tessera writes (xlsx, ods, html, svg,
      pdf, csv, json, jsonl; the aggregates the grid shows) and the
      facts as a table (xlsx, ods, csv, jsonl); `FilePicker.saveFile`
      and `share_plus`; the tessera green theme; Noto Sans embedded in
      the PDF (2026-10-09).
- [x] Full screen on phones, like a video player: in the grid-alone
      layout a finger tap on a value hides the app bar and the system
      bars (sticky immersive), the next tap or back brings them back;
      the grid keeps its scroll position (2026-10-09).
- [x] Cube page: import in an isolate with progress and report, axis
      and aggregate editors, filter, `CubeView`, current-cell line;
      editors inline from 840 dp or in a bottom sheet below, switchable
      from the overflow menu and persisted (2026-09-15).
- [x] Overflow menu on every app bar with Language… and Theme… dialogs
      (system / light / dark; system + the 14 languages by endonym),
      persisted, system default for both (2026-09-15).
- [x] Drag and drop a file onto the home screen (Windows, Linux, web)
      with a highlight while dragging (2026-09-15).
- [x] "Open from clipboard": a URL, a file path or URL, or tabular text
      (cells from a spreadsheet, CSV text); disabled while the clipboard
      is empty. Formats are also detected from a URL's
      Content-Disposition and Content-Type and from the bytes (snapshot
      magic, zip contents, JSON, delimited text with a sniffed
      delimiter), so semicolon CSVs and extension-less downloads open
      (2026-09-15).
- [x] Schema page with the column editor, and schema edits remembered
      per source structure (`Schema.structureKey` in tessera) and
      restored automatically with a banner (2026-09-15).
- [x] Home screen with the logo and the "Open file…" picker (2026-09-15).
- [x] Command-line argument (path or URL) with progress (2026-09-15).
- [x] Android "Open with…" and share sheet through a hand-written
      channel, verified on a device (2026-09-15).
