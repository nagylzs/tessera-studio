# TODO

Open work on Tessera Studio, in priority order within each section.
Tick items as they land; once releases start, a feature commit also
adds its bullet under `## Unreleased` in `CHANGELOG.md`. Rules and
conventions live in `CLAUDE.md`, not here.

## Viewer flow

- [ ] On the Mac the window's title bar follows the system appearance,
      not the app's Theme setting: Light in the app on a dark Mac gives a
      dark title bar over a light window (found 2026-10-20 taking the
      Mac shots, which were therefore taken with the Mac's appearance
      matching). Set the window's `NSAppearance` from `AppSettings.themeMode`
      (aqua / darkAqua / nil for System) through a small channel. Polish,
      not a release blocker.
- [ ] Cube page follow-ups: a "Settings" entry to restore the automatic
      layout after an explicit choice; the charts pane beside/below the
      grid as in the example.
- [ ] Save/load a pivot layout as a `.json` file (`CubeConfig` /
      `CubeJson`, through the file picker), e.g. to apply one pivot to
      another file of the same structure on another device. Less urgent
      since pivots are remembered per structure and snapshots carry
      theirs. The same item sits in `../tessera/TODO.md` for the example
      app; whichever lands first, keep the example minimal.
- [ ] **Question for the owner: Japanese and Chinese in the PDF export?**
      The bundled Noto Sans has no CJK glyphs, so Japanese and Chinese
      text — in the data, or the ja/zh tessera strings such as the total
      — comes out as stray marks in a PDF (the other formats are fine).
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
- [ ] Charts pane: `ChartData` / `ScatterData` + `fl_chart`, exportable
      as SVG/PDF/PNG.
- [ ] Entry points beyond the desktop argument, Android intents, the
      clipboard and drag and drop: a web `?open=<url>` query parameter,
      Windows and Linux file associations with packaging (below).
- [ ] Idea (owner, 2026-10-19; not decided for the first release): a
      file dropped on the cube page opens it, as viewers do (mpv, Eye of
      GNOME). Today only the home screen is a drop target. Replace the
      file in place, or ask first when the pivot differs from its
      default? The schema and layout are remembered either way.
- [ ] Idea (owner, 2026-10-15; not decided for the first release):
      choose the sheet of an .xlsx / .ods file. Today the first sheet is
      read; offer the non-empty ones when there are several (a short
      list before the schema page, remembered with the layout by
      structure key). Library work first: `XlsxWorkbook.sheets` is
      public, but `OdsDocument.sheetNames` is internal, and neither
      package has a cheap "is this sheet empty" check (`sheetDimension`
      trusts a `<dimension>` element that may be stale or missing).
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

## Packaging and release

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
      release means a new submission and certification; the certified
      one is 1.0.0.0 from 2026-10-11 (before the xlsx/ods 0.2.2 fix), so
      the release needs one. Package versions are `major.minor.N.0` since
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
- [ ] Linux: `.desktop` file, icon, MIME types (`text/csv`, XLSX, ODS,
      JSON, `application/vnd.tessera.snapshot`).
- [ ] Store screenshots: shot list and demo data in `store/screenshots/`;
      the desktop (README), Google Play phone and tablet, and Microsoft
      Store sets, the Play feature graphic and 512 px icon are done.
      Still to do: Apple's on the Mac. The README is rewritten
      (2026-10-11): what the app does, the promise, screenshots, the
      platforms' state — update its "Not released yet" note and the
      platform table at the release. The listing texts are done
      (`store/listing/`); a native speaker's read of the translations
      would not hurt, the owner reviews Hungarian.
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
