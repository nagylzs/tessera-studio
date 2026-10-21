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
      release means a new submission and certification: 1.0.0.0 from
      2026-10-11 predated the xlsx/ods 0.2.2 fix, so 1.0.6.0 (`1.0.0+6`)
      replaced it and was resubmitted 2026-10-21, held for Publish now
      as before. Package versions are `major.minor.N.0` since
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
      (2026-10-20). Still to do: before the release tag, the version
      and date into `releases` in `tool/linux_metadata.dart` (AppStream
      wants a dated release, and the metainfo's screenshots are fetched
      from the tag); the GTK file chooser's filter is named "Custom",
      hardcoded in `file_picker_linux` (an upstream issue).
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
