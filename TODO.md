# TODO

Open work on Tessera Studio, in priority order within each section.
Tick items as they land; once releases start, a feature commit also
adds its bullet under `## Unreleased` in `CHANGELOG.md`. Rules and
conventions live in `CLAUDE.md`, not here.

## Viewer flow

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
- [ ] After tessera_pdf 0.2.1 is out (the page header/footer colour fix,
      `PdfCubeExporter.pageTextColor`, under Unreleased in
      `../tessera`): bump the constraint and drop `pdfExportTheme`, so
      the PDF gets the same green headers as the other formats.
- [ ] Charts pane: `ChartData` / `ScatterData` + `fl_chart`, exportable
      as SVG/PDF/PNG.
- [ ] Entry points beyond the desktop argument, Android intents, the
      clipboard and drag and drop: a web `?open=<url>` query parameter,
      Windows and Linux file associations with packaging (below), drag
      and drop on macOS once that target exists (`desktop_drop` has the
      plugin; enable it in `HomePage.dropSupported`).
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
      only; Play and App Store uploads manual at first.
- [ ] Windows, Microsoft Store first and a portable zip besides (owner,
      2026-10-10; CI builds both, see CLAUDE.md): a Partner Center
      account, reserve "Tessera Studio", put its three identity values
      into the repository variables `MSIX_IDENTITY_NAME`,
      `MSIX_PUBLISHER`, `MSIX_PUBLISHER_DISPLAY_NAME` (CI then builds
      the Store package instead of the test one) and into
      `msix_config` in place of the placeholders; Store listing, upload
      by hand at first. Try on a Windows machine: the test MSIX
      (installing needs its test certificate trusted), the file
      associations, the portable zip on a Windows without the Visual
      C++ runtime. Decide on signing the portable exe (unsigned means
      SmartScreen's "Windows protected your PC" → More info → Run
      anyway; a code-signing certificate or service costs money).
- [ ] Linux: `.desktop` file, icon, MIME types (`text/csv`, XLSX, ODS,
      JSON, `application/vnd.tessera.snapshot`).
- [ ] Store listing and README: free, ad-free, no telemetry, the 14
      languages, screenshots from the Xvfb recipe.
- [ ] After the first release: register `application/vnd.tessera.snapshot`
      with IANA naming Tessera Studio as the application (form and field
      values in `../tessera/TODO.md`), then claim the type in the file
      associations of every platform, including the Android manifest.
- [ ] iOS and macOS on the owner's Mac (the folders, names, icons and
      CI builds exist; bundle id `eu.nagylzs.tessera-studio`): register
      the id with Apple; run on a device and a Mac;
      `CFBundleDocumentTypes` and opening a file from Finder / the Files
      app ("Open with" hands a URL to the app delegate — a channel like
      Android's `OpenRequests`); share
      needs `sharePositionOrigin` on the iPad (the share button's
      rect); try drag and drop on macOS (enabled, untested).

## Done

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
