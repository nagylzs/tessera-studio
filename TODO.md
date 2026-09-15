# TODO

Open work on Tessera Studio, in priority order within each section.
Tick items as they land; once releases start, a feature commit also
adds its bullet under `## Unreleased` in `CHANGELOG.md`. Rules and
conventions live in `CLAUDE.md`, not here.

## Viewer flow

- [ ] Workbench: `loadFactsInIsolate` with the sample app's progress
      block, axis and aggregate editors, filter editor, `CubeView`,
      current-cell info line, "Schema…" back to the schema page with a
      re-import only when the parse-relevant parts changed.
- [ ] Save/load a pivot layout (`CubeConfig` / `CubeJson`, a `.json`
      file through the file picker) and "Save snapshot…". The same two
      items sit in `../tessera/TODO.md` for the example app; whichever
      lands first, keep the example minimal.
- [ ] Remember the pivot layout per structure next to the schema
      (`SchemaStore` → a per-structure settings store), so a known file
      opens on last time's pivot; the banner then says so too.
- [ ] Export menu: every format (`ExportFormat`-style enum, with
      `CubeExportTheme` chosen by the app's theme), through
      `FilePicker.saveFile`; a share action on Android.
- [ ] Charts pane: `ChartData` / `ScatterData` + `fl_chart`, exportable
      as SVG/PDF/PNG.
- [ ] Entry points beyond the desktop argument and Android intents: a
      web `?open=<url>` query parameter, drag and drop on desktop,
      Windows and Linux file associations with packaging (below).
- [ ] Clipboard: files copied as file objects (Explorer, Finder, GNOME
      Files) are not text, so Flutter's `Clipboard` cannot see them;
      `super_clipboard` (all platforms, iOS and macOS included) reads
      `text/uri-list` and file items and would let "Open from
      clipboard" take them too. Also HTML tables copied from a browser
      (`text/html`) could be parsed into rows.

## App

- [ ] Language menu (override the system locale; persisted), an About
      page (version, licence, the "free and ad-free forever" statement,
      link to the tessera guide).
- [ ] Settings persistence (theme mode, language, last export format).
- [ ] Error page for a file that fails to parse, with the report from
      the import.

## Packaging and release

- [ ] CI: GitHub Actions building web, Linux and Windows binaries and an
      Android app bundle per tag; Play upload manual at first. Signing
      keys and store credentials as CI secrets only.
- [ ] Linux: `.desktop` file, icon, MIME types (`text/csv`, XLSX, ODS,
      JSON, `application/vnd.tessera.snapshot`); Windows: file
      associations in the installer.
- [ ] Store listing and README: free, ad-free, no telemetry, the 14
      languages, screenshots from the Xvfb recipe.
- [ ] After the first release: register `application/vnd.tessera.snapshot`
      with IANA naming Tessera Studio as the application (form and field
      values in `../tessera/TODO.md`), then claim the type in the file
      associations of every platform, including the Android manifest.
- [ ] iOS and macOS, if a Mac or a macOS CI runner becomes available:
      `flutter create --platforms ios,macos .`, names, icons,
      `CFBundleDocumentTypes`.

## Done

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
