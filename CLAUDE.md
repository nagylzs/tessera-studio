# Tessera Studio — project notes for Claude

The end-user application built on the tessera packages: open a CSV,
Excel, ODS or JSON file, pivot it with expandable row and column
hierarchies, filter, calculate, chart, export. Owner: László Zsolt Nagy
(nagylzs@gmail.com). MIT. Targets: Android (Google Play), iOS and
macOS (App Store), Windows, Linux and the web; the first release goes
out on all of them at once. `ios/` and `macos/` exist since 2026-10-09
(made by `flutter create` in a scratch project and copied in) and are
built by CI on GitHub's macOS runners, unsigned. The owner has a Mac
mini (macOS 27, Xcode 27) since 2026-10-12 and an iPhone 14 (iOS 27)
since 2026-10-15; the app has run on both since 2026-10-15 (VS Code's
`macos …` and `iphone … (iPhone 14)` entries). Apple Developer Program:
individual, team `Y8M7VVUK26`, active since 2026-10-18; both Xcode
projects set `DEVELOPMENT_TEAM` with automatic signing, and the Mac
build still signs to run locally. **Ask the owner
before adding a dependency that does not support every one of these
platforms.**

Unlike the library, this app is **opinionated and may take many
dependencies**. The rule for where code goes: if a second app could
want it, it belongs in the tessera packages (generic, released first,
then the constraint here is bumped); if only this app wants it, it
lives here.

## Product principles (non-negotiable)

- **A quick viewer, not an editor.** Tessera Studio is to tabular data
  what mpv is to video or Eye of GNOME to images: the user opens a
  file that already exists (file manager "Open with…", command-line
  argument, Android share sheet / file intent, drag and drop, the
  in-app picker), sees it as a pivot immediately, and then saves or
  sends the cube or a chart in another format. Optimise for
  time-to-first-view: opening a file is the primary entry point, the
  workbench is the main screen, export/share is one tap away and
  offers every format tessera can write. The app never creates or
  edits the source data; the only things it writes are exports,
  saved layouts and snapshots. Register the app as a handler for the
  file types it opens on every platform (Android intent filters, web
  file handling, `.desktop` MIME types on Linux, Windows file
  associations) once packaging starts.
- **The same 14 languages as tessera.** Every user-visible string in
  the app is localised for all locales tessera ships: cs, de, en, es,
  fr, hu, it, ja, nl, pl, pt, ru, tr, zh (`supportedLanguages` in the
  engine, `TesseraLocalizations.supportedLocales` in tessera_flutter).
  A new string lands in all 14 ARB files in the same commit; never
  hardcode English in a widget. If tessera adds a locale, the app
  follows in its next release.
- **Free and ad-free, forever.** No ads, no in-app purchases, no
  subscriptions, no accounts, no telemetry or analytics, no crash
  reporters that phone home. The only network traffic is what the
  user explicitly starts (opening a URL). Never add a dependency that
  does any of these. Store listings and the README state this.

## Relationship to the tessera repository

- The library lives in a sibling checkout: `../tessera` (pub workspace
  with `packages/tessera`, `tessera_flutter`, `tessera_xlsx`,
  `tessera_ods`, `tessera_html`, `tessera_svg`, `tessera_pdf`). Its
  `CLAUDE.md` documents the engine, the widgets and every exporter in
  depth; its `docs/` is the fifteen-chapter user guide — read those
  before touching anything pivot-related, do not re-derive them here.
- The committed `pubspec.yaml` depends on the **published** versions
  (`tessera_flutter ^0.2.4` — menus that close on back, full-screen
  pickers on a phone in landscape, computed dimensions ("Expression…"
  in the dimension picker) —, `tessera_pdf
  ^0.2.1` — page texts in the cell colour —, `tessera_xlsx` and
  `tessera_ods ^0.2.3` — `sheets()`, the sheet list; 0.2.2 brought their
  own zip writer, as LibreOffice refuses what `archive` 4.4+ writes; they pull in `tessera` 0.2.2, the first
  with `Schema.structureKey` — the other exporters `^0.2.0`). For developing both at once, a
  git-ignored `pubspec_overrides.yaml` points all seven packages at
  `../tessera/packages/*`; delete it to build against pub.dev, and never
  commit a `pubspec.lock` resolved through it (it records path sources).
  Pub accepts workspace members as path overrides from
  outside the workspace.
- The example app inside `../tessera/packages/tessera_flutter/example`
  is the deliberately minimal pub.dev demo. Its pieces (`CubeWorkbench`
  = infer → isolate import with progress → editors + `CubeView`,
  `SchemaPage`, `HttpCsvDataSource`, the `ExportFormat` menu, the
  Charts page with `fl_chart`, the language menu) are the natural
  starting material: **copy them in and reshape them**, never depend on
  the example. Do not fork the example wholesale; the app's structure
  should reflect the app.

## State (2026-09-15)

The home screen and the file-open flow exist; the pivot workbench is
the next step.

- `lib/main.dart` registers services (`di.dart`), starts
  `AppState.loadFrom` for the optional command-line argument (a file
  path or http(s) URL; desktop runners pass `argv` through; the web gets
  none yet), subscribes `AppState.handleOpenRequest` to `OpenRequests`
  (Android "Open with…"/share sheet, see below) and runs
  `TesseraStudioApp` (`app.dart`: Material 3 light/dark from the tessera
  green `#00856e`, all localization delegates, root `SignalBuilder`
  switching between `HomePage` and `SchemaPage` on
  `AppState.document`).
- `lib/files/`: `FileFormat` (extensions and media types per format,
  `ofFileName` / `ofMimeType` / `ofBytes` — snapshot magic, zip first
  entry for XLSX vs ODS, `[`/`{` for JSON/JSON Lines, else delimited
  text; `sniffDelimiter` picks tab, `;`, `,` or `|` by consistency
  over the first 20 lines — and `dataSource(bytes, name:, delimiter:)`),
  `OpenedDocument` (name, format, bytes, sniffed delimiter for CSV;
  `OpenedDocument.detect` = name → media type → bytes, throws
  `UnsupportedFileException`; bytes kept in memory because web and
  Android give no path, and `fromData` sources are isolate-sendable),
  `ClipboardReader` (interface; `SystemClipboardReader` over Flutter's
  `Clipboard`, text only, `hasStrings` for the button state, always
  available on web), `FileOpener` (interface) with
  `PickerFileOpener` (`file_picker`, `FileType.custom` with every known
  extension, `readAsBytes`; on Android `FileType.any`, because its
  picker filters by the media type on record and `file_picker` drops
  the extensions the device does not know, `.tsnp` among them — found
  2026-10-21 —, so a name without a known extension is first judged by
  its first 64 KB), `DocumentLoader` (interface) with
  `IoDocumentLoader` (paths through `cross_file`, URLs through
  `package:http` streaming, byte-level `LoadProgress`; a URL's name is
  its `Content-Disposition` file name (`dispositionFileName`, RFC 5987
  form first, paths stripped) else the last path segment, its format
  the name's, else the `Content-Type`'s, else sniffed; an injectable
  `http.Client` for `MockClient.streaming` tests; no `dart:io` in
  `lib/`).
- Android file handling, hand-written (no plugin):
  `android/app/src/main/kotlin/.../MainActivity.kt` takes ACTION_VIEW
  (`intent.data`) and ACTION_SEND (`EXTRA_STREAM`), reads the sender's
  DISPLAY_NAME (content Uris have no extension in their path), copies
  the stream to `cacheDir/open/` on a worker thread while the temporary
  read grant lasts, and reports `started {name}` / `ready {name, path}`
  / `failed {name, error}` maps on the `EventChannel`
  `eu.nagylzs.tessera_studio/open` (queued until Dart listens, flushed
  to the first listener; `onNewIntent` covers a second file while the
  app runs). `singleTask`: one instance, always in its own task. It was
  `singleTop` until 2026-10-22, and apps that start a viewer without
  `FLAG_ACTIVITY_NEW_TASK` (Telegram, the Files app) got it in their own
  task (their icon on the recents card), so the launcher icon then
  started a second, empty instance (owner, Xiaomi pad). The manifest's
  intent filters match by MIME type (CSV, TSV, plain text, JSON,
  NDJSON, XLSX, ODS); `.tsnp` is not
  claimed because it would need application/octet-stream. Dart side:
  `lib/files/open_requests.dart` (`OpenRequests.forPlatform()`,
  `ChannelOpenRequests`, `NoOpenRequests` elsewhere), and
  `DocumentLoader.load(name:)` so the cache copy keeps its real name.
  Verified 2026-09-15 on the owner's Xiaomi pad (Android 16), cold
  start and `onNewIntent` alike. Testing with adb (the shell cannot
  grant access to the documents provider, and files pushed into
  `Android/data/<pkg>/files` are unreadable by the app, so neither of
  those works):
  - a real content Uri: `adb push sales.csv /sdcard/Download/`, find
    the MediaStore id with `adb shell content query --uri
    content://media/external/file --projection _id:_display_name --where
    "\"_display_name='sales.csv'\""`, then `adb shell am start -n
    eu.nagylzs.tessera_studio/.MainActivity -a android.intent.action.VIEW
    -t text/csv --grant-read-uri-permission -d
    content://media/external/file/<id>`;
  - a file Uri (debug builds): `adb shell run-as eu.nagylzs.tessera_studio
    sh -c 'cat > files/sales.csv' < sales.csv`, then the same `am start`
    with `-d file:///data/user/0/eu.nagylzs.tessera_studio/files/sales.csv`.
  Always pass `-n …/.MainActivity`: the tessera example app on the
  device also claims CSV, so a bare VIEW intent opens a chooser.
  `adb shell am force-stop eu.nagylzs.tessera_studio` before an `am
  start` tests the cold-start path; without it `onNewIntent`. `am
  start` always makes a new task; for a start from inside another app's
  task, open the file in the Files app on the emulator (`am start -a
  android.intent.action.VIEW -t vnd.android.document/root -d
  content://com.android.providers.downloads.documents/root/downloads`,
  then tap it at the bounds from `uiautomator dump`), and list the tasks
  with `adb shell dumpsys activity activities | grep -E "^ *\* (Task\{|Hist)"`.
  Screenshots: `adb exec-out screencap -p > shot.png`. `adb shell input
  tap` is silently ignored on the owner's Xiaomi unless "USB debugging
  (Security settings)" is enabled in Developer options — taps must come
  from the owner otherwise; `uiautomator dump` still works for bounds.
  For anything that needs taps, use the SDK's emulator headless and
  read-only (the AVD is left untouched; it accepts `input tap/swipe`):
  `~/Android/Sdk/emulator/emulator -avd Medium_Phone_API_36.1 -read-only
  -no-snapshot-save -no-window -no-audio -no-boot-anim -gpu
  swiftshader_indirect &` (boots in ~40 s; also `Medium_Tablet`), then
  `flutter build apk --debug`, `adb install -r`, the file-Uri recipe
  above; rotate with `adb shell settings put system
  accelerometer_rotation 0` + `user_rotation 1` (0 back); bar
  visibility in `adb shell dumpsys window | grep InsetsSource`. Stop it
  with `adb emu kill`.
- iOS and macOS file handling (2026-10-19), hand-written like
  Android's: both Info.plists declare `CFBundleDocumentTypes` — CSV,
  TSV, JSON, XLSX, ODS as Viewer with `LSHandlerRank` Alternate (Numbers
  and Excel stay the default), `.tsnp` as Owner of the exported type
  `eu.nagylzs.tessera.snapshot` (application/vnd.tessera.snapshot);
  no plain text and no JSON Lines (no system type for it) — and
  `ITSAppUsesNonExemptEncryption` false (HTTPS only). iOS
  (`ios/Runner/AppDelegate.swift`): `LSSupportsOpeningDocumentsInPlace`
  false, so iOS hands over a copy in our container; `OpenRequests`, a
  `FlutterSceneLifeCycleDelegate` added with `addSceneDelegate` on the
  implicit engine's registrar (the selectors pinned with `@objc(…)`: a
  mistyped optional method compiles and is never called), copies it to
  `Caches/open` (emptied at start), deletes iOS's copy and sends the
  Android events; `FlutterDeepLinkingEnabled` false keeps file URLs out
  of the router. AirDrop does not hand documents to an app: it saves
  them in Files → Downloads and previews them, where Share → Tessera
  Studio opens them (owner, iPhone 14, 2026-10-19: with the app
  running and after killing it). macOS
  (`macos/Runner/AppDelegate.swift`, registered in
  `MainFlutterWindow`): `handleOpenURLs` sends `ready` with the file's
  own path, which the sandbox grants for Finder opens. Tested on the Mac
  without clicks: `open -a "build/macos/Build/Products/Debug/Tessera
  Studio.app" <file>` into a `flutter run -d macos` session (warm), and `open -a …
  --stdout out.log <file>` then `flutter attach -d macos --debug-url
  <the VM service URL from out.log>` (cold); `w` in either dumps the
  widget tree, which names the page shown (`SchemaPage`,
  `WorkbenchPage`). Drive both through a fifo on stdin.
- Home screen buttons: "Open file…" (picker) and "Open from clipboard"
  (`AppState.openFromClipboard`: a single line that is an http(s) URL,
  a `file:` URL or an absolute path goes through `loadFrom`, anything
  else is `OpenedDocument.detect`ed as text named "Clipboard" — Excel
  copies as TSV; `NothingToOpen` otherwise). The button follows
  `clipboardAvailable`, refreshed by `HomePage` (stateful for its
  `AppLifecycleListener`) on appearance and on resume. Drag and drop:
  `HomePage` wraps its body in `desktop_drop`'s `DropTarget` where
  `dropSupported` (Windows, Linux, macOS — tried on the owner's Mac
  2026-10-19 with a .tsnp and a .csv —, web; iOS never: the
  plugin has no iOS side, accepted by the owner as a niche), shows a
  highlight overlay while dragging, and hands the first non-directory
  item to `AppState.openDropped` (path → `loadFrom` on desktop; bytes →
  `OpenedDocument.detect` on the web, where the `XFile` has no path;
  the IO `XFile.fromData` ignores `name`, only the web one keeps it).
  `DropTarget.initState` only registers a method-call handler, so it is
  safe in widget tests; a test that flips `debugDefaultTargetPlatformOverride`
  must reset it before the test body ends (the framework checks debug
  variables before tear-downs) and pump a widget with a fresh key (an
  identical instance is not rebuilt). A real drop cannot be driven with
  xdotool; verified by tests and by the plugin compiling on Linux and
  web.
- Settings (`lib/state/settings.dart`): `AppSettings` with the
  `themeMode` and `locale` signals (both default to the system; `null`
  locale lets Flutter resolve; English is the fallback because
  `preferred-supported-locales: [en]` in `l10n.yaml` puts it first —
  without it the alphabetical list made Czech the fallback, found
  2026-10-20), backed by a
  `SettingsStore` (`PreferencesSettingsStore`, keys `settings:*`;
  `MemorySettingsStore` in tests). `main` awaits `AppSettings.load()`
  before `runApp` so there is no flash; `app.dart` wraps the
  `MaterialApp` in a `SignalBuilder` reading both. The UI is the
  overflow menu `AppMenuButton` (`lib/widgets/app_menu.dart`) at the end
  of every app bar: Language… and Theme… open radio dialogs (`RadioGroup`,
  `RadioListTile.groupValue` is deprecated), languages listed by endonym
  from the const `languageNames`; then Grid style… and About… (a
  Settings entry may join later). Dialogs rather than submenus: thumbs
  as well as mice. About (`lib/widgets/about.dart`): Flutter's
  `showAboutDialog` — name, `TesseraLogo` at 48 px, version from
  `package_info_plus` ("1.0.0 (1)": version and build number), the
  copyright line, the "free and ad-free, forever" promise, and links
  to the tessera user guide (English only, which the other languages
  say) and the source, opened through `LinkOpener` (`lib/platform/
  links.dart`, `url_launcher` in the external browser; a fake in
  tests). Its "View licenses" page lists the packages and Noto Sans
  (`registerLicenses` in `lib/licenses.dart`, called by `main`).
- `lib/state/app_state.dart`: `AppState` with the `document`,
  `opening`, `loading` (`LoadProgress?`) and `loadFailure` signals,
  `openFile()` (picker; returns an `OpenFailure` for the UI to localise
  in a snackbar), `loadFrom(source, name:)` (argument or cache copy;
  failure shown inline on the home screen, which then offers the button
  again), `handleOpenRequest()` and `closeFile()`.
- `lib/widgets/tessera_logo.dart`: the icon drawn with a `CustomPainter`
  (the shapes of `../tessera/icon/tessera-icon-foreground.svg`; no image
  asset, no SVG package). `HomePage` shows it at 60 % of the screen and
  50 % opacity behind the "Open file…" button, or behind the sample
  app's progress block (240 px `LinearProgressIndicator` + "Loading
  name… 42%") while the argument loads and the schema is inferred.
- Flow after a file is read (`AppState._open` → `_prepare`):
  `columnNames()`, the first 5 rows as samples, `inferSchema`, then
  `SchemaStore` and `LayoutStore` lookups by `Schema.structureKey` of
  the inferred schema. A workbook (.xlsx, .ods) first gets its sheet
  (`AppState._prepareWorkbook`, 2026-10-23): `FileFormat.sheets` lists
  them through tessera's `sheets()` (`SheetInfo`: name, hidden, empty,
  active — the sheet the file was saved on), `OpenedDocument.sheets`
  keeps the visible ones with a value, `sheet` the one shown: the saved
  one, else the first, and one that throws `EmptySourceException` (a
  title, no rows) gives way to the next. With several, `DocumentTitle`
  (`lib/widgets/document_title.dart`, the title of the schema and cube
  pages) shows the sheet with a ▾ and opens a `PopupMenuButton` of
  them; `AppState.openSheet` goes through `_open` again, so each sheet
  has its own stored schema and pivot by structure key, and the pages
  show a progress bar under the app bar while `loading`. Exports and
  failures name the sheet (`exportBaseName`, `title`). Both pages are
  keyed by document in `app.dart`. Neither → `SchemaPage` (the example's column editor reshaped:
  include switch, type, label, date format / number syntax, samples;
  rows wrap under 720 px for phones; "Reset to inferred", "Continue",
  close/back = discard). Either → a known structure, straight to
  `WorkbenchPage` (stored schema or the inferred one) with a
  `MaterialBanner` of one line per restored thing — "Schema restored
  from the one you saved on <date>" with "Reset to inferred" (forgets
  the entry, opens the schema page with the inferred schema), "Pivot
  restored as you left it on <date>" with "Default pivot"
  (`CubeState.resetLayout`) — and OK. "Continue" stores the schema
  when it differs from the inferred one (`AppState.sameSchema`, JSON
  equality through `CubeJson.encodeSchema`) and deletes the entry when
  it equals it. Snapshots skip all of this (schema from the facts).
  `AppState.page` (`AppPage.home/schema/workbench`) drives the root;
  `schemaBack` says where the schema page's back goes.
- `lib/state/schema_store.dart`: `SchemaStore` (`read/write/delete` by
  structure key), `PreferencesSchemaStore` (`shared_preferences`, key
  `schema:<structureKey>`, JSON `{schema, savedAt}`; a damaged entry
  reads as none) and `MemorySchemaStore` for tests.
- `lib/state/layout_store.dart`: the same for the pivot — `StoredLayout`
  (`CubeConfig` without schema, `shown` as positions in the spec's
  aggregates, `savedAt`), key `layout:<structureKey>`. `CubeState.start
  (layoutKey:, layout:)` starts from it (pruned to the facts like after
  a schema edit) and from then on `_layoutChanged`, a listener on the
  controller plus `setShown`, writes every change at once (no timer):
  it encodes the layout (`encodeConfig` is deterministic) and writes
  only when the encoding differs from the last stored one, deletes the
  entry when back at `defaultSpec`, and skips selection-only
  notifications by identity of the `Cube`. Snapshots get no key.
  Verified on the API 36 emulator across a force-stop.
- Cube page (`WorkbenchPage`) and `lib/state/cube_state.dart`:
  `CubeState` (owned by `AppState.cube`) runs `loadFactsInIsolate` with
  progress (`importing`, `progress` signals), keeps `result`,
  `controller` (tessera's `CubeController`, a ChangeNotifier — used as
  is), `dimensions` (`standardDimensions`) and `shown` aggregates;
  `start()` imports or decodes a snapshot (its `CubeConfig` becomes the
  spec/expansion), `applySchema()` relabels in place for label-only
  edits and re-imports otherwise, pruning the spec (`prune`,
  `defaultSpec`, `sameExceptLabels` copied from the example).
  `AppState.busy` = opening || loading || importing; tests wait on it.
  Layout: `CubePageLayout` setting (`auto` / `editors` / `cubeOnly`;
  `resolve(size)`: editors from Material's 840 dp width and 480 dp
  height breakpoints, so a phone in landscape keeps the grid alone;
  named so because tessera exports its own `CubeLayout`). `editors`:
  `EditorsPanel`
  (`lib/widgets/editors_panel.dart`: `ImportSummary` line → report
  dialog, the two `AxisEditor`s side by side from 600 px else stacked —
  an axis editor cannot shrink below caption + widest chip + add button
  — and the `AggregateEditor`) above the `CubeView`, `CurrentCellLine`
  below, a filter icon in the bar. `cubeOnly`: the grid alone, a "tune"
  icon opens the panel in a `DraggableScrollableSheet`, filter in the
  overflow menu. The overflow menu (`AppMenuButton(entries:)`) has the
  checkable "Editors on top" (writes an explicit layout), Filter…
  (narrow), Schema…, then Language…/Theme…; its items are icon+text
  rows, not `ListTile`s (they overflow in a phone-wide menu). The schema
  page's bar goes compact under 600 px (check icon + Reset in the menu).
  Full screen (`_WorkbenchPageState._fullScreen`, local state): in
  `cubeOnly` a tap on a value (`CubeView.onCellTap`; a `Listener`
  records the pointer kind, so touch and stylus only, never a mouse)
  drops the app bar and the banner, wraps the grid in a `SafeArea` and
  calls `SystemBars.hide()` (`lib/platform/system_bars.dart`, in get_it;
  `SystemChrome` `immersiveSticky`, back to `edgeToEdge` — verified on
  an API 36 emulator despite Flutter's docs saying API 36 ignores it).
  In full screen any tap on a value, or back, leaves it, whatever the
  layout has become (a window resized past the breakpoints); the
  page's `PopScope` lets a pop through while the route
  `willHandlePopInternally` — an open tessera menu holds a local history
  entry (since tessera_flutter 0.2.2), and back must
  close the menu, not the file;
  leaving the page restores the bars. A `GlobalKey` on the `CubeView`
  keeps its scroll position across these and layout switches; the page
  is keyed by document in `app.dart`, so a new file starts fresh.
  Export (`lib/export/`, `lib/widgets/export_dialog.dart`): one bar
  button — Share where `ExportTarget.canShare` (Android, iOS; "Save as…"
  then heads the overflow menu), Save as… elsewhere — opens the format
  dialog (`showExportDialog`: the cube in `ExportFormat.pivots`, then
  "Facts as a table" in `ExportFormat.tables`, then "To reopen in
  Tessera Studio" with `ExportFormat.snapshot` — `TesseraSnapshot()
  .encode(facts, config: CubeConfig.of(cube))`, named `<source>.tsnp`,
  all aggregates of the spec); `runExport` writes the
  bytes on this isolate (`cubeExport` with the aggregates the grid
  shows, `factsExport` = `ExportTable.ofFacts` with the spec's filter)
  behind a `LinearProgressIndicator` under the bar, then
  `ExportTarget.save` (`FilePicker.saveFile(bytes:)`, which writes the
  file itself on every platform) or `.share` (`share_plus`,
  `fileNameOverrides` because the IO `XFile.fromData` drops the name;
  on an iPad the sheet is a popover at the share button's rect,
  `share(origin:)`, without which share_plus refuses — untested, no iPad).
  File names are localized ("sales pivot.xlsx", "sales facts.csv").
  Theme: the grid style's (`GridStyle.exportTheme`, below; standard =
  `CubeExportTheme.brand` on `tesseraGreen`), the PDF's too since
  tessera_pdf 0.2.1 draws the page title, date and page numbers in the
  cell text colour (0.2.0 used the header cells', white on the green,
  and the app had a light PDF variant until 2026-10-11). PDF fonts: Noto Sans Regular/Bold subsets in
  `assets/fonts/` (Latin incl. Extended-A/B/Additional, combining marks,
  Greek, Cyrillic, punctuation, currency; `tool/subset_fonts.sh`, about
  240 KB each), SIL OFL in `assets/fonts/OFL.txt`, registered with the
  `LicenseRegistry` in `main`. No CJK glyphs (TODO). Verified on the
  API 36 emulator: share sheet, the documents UI save dialog (Downloads),
  a Hungarian PDF through `pdftotext`/`pdftoppm`.
  Grid styles (`lib/style/grid_style.dart`): `GridStyle` standard /
  spreadsheet / gradient / hueLevels / highContrast / compact, adapted
  from the example's theme presets; `theme(brightness)` → `CubeTheme`,
  `exportTheme` → `CubeExportTheme` authored to match (exports follow
  the grid). "Grid style…" (palette icon) in the common menu entries
  opens a radio dialog with a description line per style
  (`_RadioDialog.subtitles`); `AppSettings.gridStyle`, key
  `settings:gridStyle` (absent = standard). Dark mode: spreadsheet and
  gradient stay light like paper and pin `headerIconColor` (the dark
  theme's light icons vanish on light headers); high contrast draws
  white lines; compact's header rows are 24 px (20 clipped the title
  cells' descenders). Checked in both modes with the screenshot recipe
  below.
  Failures (`lib/files/file_failure.dart`, `lib/widgets/failure_view.dart`,
  `lib/pages/failure_page.dart`): a file that was read but cannot be
  opened — the reading and inference in `_open`, where `_prepare` also
  throws `EmptySourceException` for no columns / no rows — goes to
  `AppState.failure` (`FileFailure.of`: kind by exception, format and
  bytes — a text format that is not UTF-8 is `notUtf8` whatever was
  thrown; `describe` strips the stacked "FormatException: " prefixes),
  which the root shows as `FailurePage` over whatever was there; close
  or back dismisses it, a successful open clears it. Inference samples
  1 000 rows, so a file broken further down fails in the import
  instead: the cube page shows the same `FailureView` with
  `CubeState.errorRows` and "Schema…". Failures before any bytes
  (unsupported type, network, empty clipboard) stay `loadFailure`, one
  line on the home screen (`describeOpenFailure` in
  `lib/widgets/open_file.dart`, next to `pickAndOpen`).
  `intl`'s `NumberFormat` clashes with tessera's: `show`/`hide` it.
- Localization: `l10n.yaml` + `lib/l10n/app_<code>.arb` for the 14
  locales, generated by `flutter gen-l10n` (runs on `pub get`/build)
  into the git-ignored `lib/l10n/generated/`; `AppLocalizations.of(context)`.
  A test asserts the ARB locale set equals `TesseraLocalizations.supportedLocales`.
- Tests: `GetIt.I.reset()` in `setUp`, then fakes (`FileOpener`,
  `FakeClipboard` and `FakeLoader` from `test/fakes.dart`,
  `MemorySchemaStore`) and a fresh `AppState` are registered. Anything that runs the open flow (inference over a
  tessera `DataSource`) must happen under `tester.runAsync` and poll
  `AppState.opening` / `loading` until done: tessera's source streams
  never complete on the widget test's fake clock (`columnNames()` hangs
  with no timers pending — the example app's `widget_test.dart` has the
  same workaround). Symptom otherwise: `pumpAndSettle timed out`.
- Icon: the library's icon, reused unchanged. Sources are
  `../tessera/icon/*.svg`; `assets/icon/*.png` (not bundled) are
  rasterized from them with `rsvg-convert -w 1024 -h 1024`;
  `dart run flutter_launcher_icons` (config at the end of the pubspec)
  writes Android (adaptive + monochrome), web and Windows icons. Linux
  has its own variant, the icon on a rounded tile
  (`linux/packaging/eu.nagylzs.tessera_studio.svg`, approved by the owner
  2026-10-20; PNGs are rendered from it when packaging, see Linux below).
- Names: "Tessera Studio" is set in the Android manifest label, the web
  manifest/`index.html`, `linux/runner/my_application.cc` (window and
  header-bar title), `windows/runner/main.cpp` and `Runner.rc`
  (product name, company, copyright). Application id
  `eu.nagylzs.tessera_studio`; iOS and macOS `eu.nagylzs.tessera-studio`
  (Apple bundle ids allow no underscore, Android ids no hyphen: the
  closest the two allow, and the repo's spelling; chosen by the owner
  2026-10-09 over Flutter's default `tesseraStudio`; fixed once
  registered with Apple), their `CFBundleName`
  / `CFBundleDisplayName` "Tessera Studio", the macOS copyright in
  `macos/Runner/Configs/AppInfo.xcconfig` with `PRODUCT_NAME` "Tessera
  Studio" (the bundle's file name, which Finder and `/Applications`
  show; until 2026-10-20 it was `tessera_studio`; the menus' and the
  window's `APP_NAME` placeholders are replaced at launch by
  `FlutterAppDelegate` with `CFBundleDisplayName`), the sandbox entitlements
  `files.user-selected.read-write` (picker, save dialog, drops) and
  `network.client` (URLs) in both `.entitlements`. Icons: the
  `flutter_launcher_icons` config covers iOS (no alpha: the paper
  colour behind) and macOS too. Keep the four spellings consistent:
  repo `tessera-studio`, package `tessera_studio`, id as above,
  display name "Tessera Studio". There are unrelated "Tessera" apps on
  Google Play (RSS reader, prayer app, games); the "Studio" suffix and
  our own icon keep the listing distinct — never publish as plain
  "Tessera". On the App Store even "Tessera Studio" was taken (reserved
  by someone, no app published under it): the App Store Connect record
  (iOS and macOS in one, universal purchase, SKU `tessera-studio`,
  2026-10-19) is **"Tessera Studio: Pivot Tables"**, `app_store_name`
  in `store/listing/`, localized; the name under the icon stays
  "Tessera Studio".

## Commands

```bash
flutter pub get
flutter analyze                # must be clean
flutter test
flutter run -d linux           # or -d chrome / -d windows / an Android device
dart run flutter_launcher_icons   # after re-rasterizing assets/icon
flutter build linux --release / windows --release / web --release / appbundle
gh run list -L 3 / gh run watch <id> --exit-status   # CI, see below
```

App Store uploads (by hand from the Mac, first one 2026-10-19, iOS
`1.0.0 (2)` to TestFlight): `flutter build ipa --release` archives
(`build/ios/archive/Runner.xcarchive`; its own IPA export may fail, see
below), then
`env PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive
-archivePath build/ios/archive/Runner.xcarchive -exportOptionsPlist
tool/apple_export_options.plist -exportPath <scratch> -allowProvisioningUpdates`
signs for the App Store and uploads with the Xcode account (set
`destination` to `export` in a copy of the plist for a local .ipa).
macOS (2026-10-20: `1.0.0 (2)` rejected, `1.0.0 (3)` uploaded): the
project signs to run locally (`CODE_SIGN_IDENTITY "-"`, so CI builds
without certificates), so the archive gets the identity on the command
line —
`flutter build macos --release --config-only` (with `--build-number N`
when the store needs a number the pubspec does not have yet), then
`xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner
-configuration Release -archivePath build/macos/archive/Runner.xcarchive
archive TESSERA_CODE_SIGN_IDENTITY="Apple Development"
-allowProvisioningUpdates` — and is exported the same way as iOS,
into a `.pkg` signed with the local Mac Installer Distribution
certificate ("3rd Party Mac Developer Installer", made 2026-10-20;
the first `productbuild` asks for the keychain once: Always Allow).
`TESSERA_CODE_SIGN_IDENTITY` (`AppInfo.xcconfig`) reaches only the
Runner target. **Never pass `CODE_SIGN_IDENTITY` itself**: it also
signs the Swift packages' resource bundles (`Contents/Resources/
*_*.bundle`, unsigned in a normal build), the export re-signs only the
app and its frameworks, and Apple rejects the build after the upload
by email as ITMS-90284 "must be signed with the certificate that is
contained in the provisioning profile" — that happened to `1.0.0 (2)`;
a rejected build number cannot be reused. Check with `pkgutil
--check-signature`, `pkgutil --expand-full`, `codesign --verify
--strict --deep` on the app, and `codesign -dvv` on every item with a
`_CodeSignature`: all must say Apple Distribution.
Two traps, both met on the first upload:
- **Homebrew's rsync breaks Xcode's IPA step** ("exportArchive Copy
  failed"; the log in the `.xcdistributionlogs` folder xcodebuild names
  says `--extended-attributes: unknown option … [server=3.5.1]`):
  `/usr/bin/rsync` starts the `rsync` first on the PATH as its other
  end, and `/opt/homebrew/bin/rsync` (installed 2026-10-19 for the
  website's deploy) speaks another dialect. Hence the system-only PATH.
- **Cloud-managed signing breaks on the accents in the owner's name**:
  Apple's servers write "LÁSZLÓ" decomposed into the designated
  requirement while the certificate has it precomposed, so the upload
  fails as ITMS-90035 "Invalid Signature … not properly signed" and
  `codesign --verify --strict` says "does not satisfy its Designated
  Requirement". The fix is a **local** Apple Distribution certificate
  (Xcode → Settings → Accounts → the team → Manage Certificates → + →
  Apple Distribution; made 2026-10-19, key in the login keychain),
  which automatic signing then prefers. Before uploading, unzip the
  .ipa and check `codesign --verify --strict` on `Runner.app` and every
  `Frameworks/*.framework`.

CI (`.github/workflows/ci.yml`): on every push, analyze + format check
+ tests on Ubuntu, and release builds of Android (split APKs and the
bundle), web, Linux, Windows (`windows-latest`), macOS and iOS
(`macos-latest`, `--no-codesign`) — proof that each platform compiles.
Every job uses the Flutter of `FLUTTER_VERSION` in the workflow's env
(3.47.7 since 2026-10-20, the Mac's, which builds the Apple uploads;
bump it together with the machines). The Linux job also packages and
tests, see Linux below.
The builds are kept as downloads (14 days) only for `v*` tags and
manual runs ("Run workflow"). Signing goes through CI secrets, never
through the repository. Android: `android/app/build.gradle.kts` signs
release builds with the Google Play **upload key** named by
`android/key.properties` (`storeFile` relative to `android/app`,
`storePassword`, `keyAlias`, `keyPassword`; it and `*.jks` are
git-ignored), else with the debug key as before. CI writes both from
the secrets `ANDROID_UPLOAD_KEYSTORE` (the PKCS12 keystore, base64) and
`ANDROID_UPLOAD_PASSWORD` (store and key; alias `upload`; letters and
digits only, a `.properties` file would read a backslash as an escape)
and prints the bundle's signer ("Signer" step). Google Play re-signs
with its own app signing key (Play App Signing); a lost upload key can
be reset through Play Console support. Apple and Windows signing come
later. Iterate on CI from a short-lived branch, not on `main`.

`store/` holds what the stores need besides the builds:
`store/privacy/index.html` is the privacy policy (English and
Hungarian, self-contained, published at
`https://nagylzs.eu/tessera-studio/privacy/`). It states what the app
does with data — files processed on the device only, the Android open
cache emptied at start, settings, schemas and pivots kept locally
(pivots can hold column names and values), the network used only for
URLs the user opens and About's links, the clipboard read only on
"Open from clipboard". Any change to those behaviours updates the page
and its date. `store/listing/<lang>.yaml` are the store listing texts,
one file per app language with every store's fields (`en.yaml` the
American-English master, the 13 others translations using the ARB
files' terms); `store/listing/README.md` maps the fields to Google
Play, the App Store and the Microsoft Store, lists each store's locale
codes and the claims to keep true (e.g. "Open with" on iOS/macOS), and
`test/store_listing_test.dart` checks every file against the limits
and that every ARB language has one. `store/screenshots/README.md` is
the shot list (the same screens on every store, per-store sizes, the
Xvfb and emulator recipes); `tool/demo_data.dart` (`dart run`, fixed
seed; `tessera` is a dev dependency for it) writes the demo data into
`store/screenshots/demo/`: `sales.csv` and two snapshots that open
straight on the pivot the screenshots start from. The sets live next to
it (`desktop/` for the README, `play-phone/`, …). The account work itself is logged in the owner's vault
(`~/LaciBox/Braniac/Projektek/fejlesztoi_fiokok`), not here.

Windows ships twice (owner's choice, 2026-10-10): the Microsoft Store
first, an MSIX made by the `msix` dev dependency (`msix_config` at the
end of the pubspec: display name, logo, `internetClient`, the 14
languages, the file types the app opens except `.txt`; the version is
`major.minor.N.0` from `version:`, N the build number, passed by CI as
`--version` — `1.0.0+4` → `1.0.4.0` — because the Store reserves the
fourth part (0) and wants each upload higher, while msix alone would
make every `1.0.0+N` `1.0.0.0`), and a portable zip. CI's Windows
job makes both after `flutter build windows`: "Portable zip" copies
`Release/` into `build/portable/Tessera Studio/` with the Visual C++
runtime DLLs from the runner's Visual Studio (`vswhere`, the newest
`Microsoft.VC*.CRT`; a fresh Windows may lack them and the app would
not start) and zips it as `tessera-studio-<version>-windows-x64-
portable.zip`; "MSIX" runs `dart run msix:create --build-windows
false`, with `--store` and the Partner Center identity when the
repository variables `MSIX_IDENTITY_NAME` / `MSIX_PUBLISHER` /
`MSIX_PUBLISHER_DISPLAY_NAME` are set, else signed with the msix
tool's test certificate (sideloading, to try installation and file
associations). The variables are set since 2026-10-10 (Partner Center:
`LszlZsoltNagy.TesseraStudio`, `CN=D8CA4CDE-319D-426D-AF14-5FB7FF9F4273`,
"László Zsolt Nagy"; also in the pubspec comment), so CI builds the
Store package — for upload only, it cannot be sideloaded. A test
package for a Windows machine: `dart run msix:create` there (`publisher`
stays out of `msix_config` for that reason), or clear the variables
for one run. The reserved name lapses on 2027-01-10 unless a
submission is made (it can wait for manual publishing). A packaged app
gets an opened file as its command-line
argument, which `main` already loads. The portable app keeps its
settings in AppData like any Flutter app, has no file associations,
and is unsigned (SmartScreen warns) unless the owner buys signing.

Linux ships as a tarball and a `.deb` for x64 and arm64 (owner,
2026-10-20; our own Flatpak repository after the first release; not
Flathub, whose rules exclude AI-assisted packaging and machine
translations: TODO.md). The work was done from the owner's Linux laptop
("tessera-studio on linux laptop"). `linux/packaging/` holds what both
install, four of the files written by `dart run
tool/linux_metadata.dart` and checked by
`test/linux_metadata_test.dart`:
- the desktop entry `eu.nagylzs.tessera_studio.desktop`. Its name is the
  GTK application id, which is also the window's WM_CLASS and Wayland
  app id. `Exec=tessera-studio %f`: a path, not a URL, as `main` takes
  one. GenericName is the ARBs' `exportPivot` (the App Store name is
  English everywhere); Comment and Keywords come from `store/listing/`.
  `Version=1.4`, because the desktop-file-validate of Ubuntu 22.04 and
  Debian 12 rejects 1.5;
- the MIME type `application/vnd.tessera.snapshot`: `*.tsnp`, magic
  `TSNP` at 0, named by `formatSnapshot`;
- the AppStream metainfo. No vcs-browser URL, as AppStream 0.15 on
  Ubuntu 22.04 fails on it. No `<releases>` until `releases` in the tool
  has the version and its date, to be set before each release tag; the
  screenshots are fetched from that tag;
- `control.in`, the `.deb`'s control file. Depends adds libegl1 and
  libgles2, which the engine loads through libepoxy at run time; without
  them it does not start.
Besides these, the folder has the rounded icon (above) and the tarball's
`install.sh` and README. The runner sets the window title in both of its
branches (with only the header bar's title, GTK titles the X11 window
with the prgname; the GNOME header-bar case is unverified) and the icon
name.
`tool/linux_package.sh [x64|arm64]` makes two packages from the release
bundle:
- `tessera-studio-<version>-linux-<arch>.tar.gz`, an unversioned
  `tessera-studio/` folder. `install.sh` integrates it in place for the
  user (the entry with the absolute Exec, the icons, the MIME type,
  `~/.local/bin/tessera-studio`), and `--uninstall` undoes it;
- `tessera-studio_<version>_<arch>.deb`, where `dpkg-deb` and `dpkg-
  shlibdeps` exist: `/usr/lib/tessera-studio`, with `/usr/bin/tessera-
  studio` a symlink (the engine finds `data/` through `/proc/self/exe`;
  the process is then named `tessera-studio`). Depends from `dpkg-
  shlibdeps`, the portal in Recommends, no maintainer scripts.
Both are reproducible: file times are the last commit's. The script
refuses a bundle holding `kernel_blob.bin`. Release bundles copy
`build/flutter_assets`, which debug builds and `flutter run` share and
leave their 75 MB kernel in, so `rm -rf build/flutter_assets` and the
bundle before a local release build. `file_picker_linux` talks to the
xdg-desktop-portal FileChooser over D-Bus with no fallback: without a
portal, `PickerFileOpener` throws `PickerUnavailableException`, and the
snack bar says what is missing (`pickerUnavailableLinux`).
CI:
- the Linux job builds both packages in an `ubuntu:22.04` container
  (glibc 2.35 floor) on `ubuntu-24.04` and `ubuntu-24.04-arm`, with
  Flutter cloned at `FLUTTER_VERSION`, as no arm64 SDK archive exists.
  It marks the workspace a git `safe.directory`: checkout trusts it only
  in a temporary config, and without it the commit time for the
  reproducible packages cannot be read;
- "Linux test" runs `tool/linux_smoke_test.sh` in fresh Ubuntu 22.04,
  24.04 and Debian 12 containers: the .deb with its Depends from the
  archive, the tarball's install.sh, `gio open` and `gio launch` on
  Xvfb, screenshots as an artifact. PID 1 there reaps nothing, so killed
  apps linger as zombies, which the test ignores;
- "Release draft" makes the draft GitHub Release on a `v*` tag, with the
  Linux packages, the Windows portable zip and SHA256SUMS; the owner
  publishes it.
Locally, `podman run` (rootless, installed on the laptop 2026-10-20)
runs the same commands as CI in `ubuntu:22.04`, with the working tree
mounted read-only and copied, and with `-e TAR_OPTIONS=--no-same-owner`:
Flutter's downloads hold uids beyond the 65,536 mapped ones. The "Open
with" checks also run without a container, under Xvfb with a scratch
`HOME`, `XDG_*` dirs and `XDG_RUNTIME_DIR` inside `dbus-run-session`: a
private bus, so the portal's dialogs open on :5, never on the owner's
desktop.

Screenshots, driving the app with synthetic input, and any test that
needs a display: always use the virtual display recipe from
`../tessera/CLAUDE.md` (`Xvfb :5`, `xdotool`, `ffmpeg x11grab`; the
package is `xorg-server-xvfb`, installed 2026-09-15). Never click on the
owner's real desktop. If `Xvfb` is missing, stop and ask the owner to
install it — do not install packages yourself and do not fall back to
other approaches (rendering pages to PNG from a widget test is only a
last resort, and its text is the Ahem block font). Working recipe for
this app: `Xvfb :5 -screen 0 1600x1000x24 &`, then
`DISPLAY=:5 LIBGL_ALWAYS_SOFTWARE=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
build/linux/x64/release/bundle/tessera_studio &`, find the window with
`xdotool search --class tessera_studio`, size it, grab with ffmpeg.
To leave the owner's settings alone and need no clicks, set
`XDG_DATA_HOME` to a scratch directory and write
`$XDG_DATA_HOME/eu.nagylzs.tessera_studio/shared_preferences.json`
first (plain keys, e.g. `{"settings:themeMode":"dark",
"settings:gridStyle":"compact","settings:cubeLayout":"cubeOnly"}`), and
pass a `.tsnp` snapshot (made with `TesseraSnapshot().encode(facts,
config:)` from a throwaway test) as the argument: it opens on its own
pivot without the schema page. The owner's session exports
`GDK_SCALE=2` and `GDK_DPI_SCALE=0.5` (4K monitor), so under Xvfb the
app renders at 2× — a fair stress test of fixed row heights, but for
true-size screenshots start it with `env -u GDK_SCALE -u GDK_DPI_SCALE`
(and `GSETTINGS_BACKEND=memory`); `ffmpeg -draw_mouse 0` leaves the
pointer out.
Stop the app and Xvfb by pid afterwards (`pkill -f <pattern>` matches
the shell running it and kills that shell instead). **Stale icon
  font:** release builds tree-shake `MaterialIcons-Regular.otf` and the
  subset is cached without proper invalidation — an icon added since
  the last build renders as a *wrong glyph* (not a blank). Delete
  `build/flutter_assets/fonts/MaterialIcons-Regular.otf` and rebuild;
  verify with fontTools (`TTFont(...).getBestCmap()`) that the code
  points from `Icons` are present. Applies to the APK too.

## Conventions (carried over from tessera)

- Commit messages: a subject line, a short body of what and why, and
  the Co-Authored-By trailer. Commit and push only when asked.
- `flutter analyze` clean and `dart format .` before committing.
- No `author` field in the pubspec; author in README and LICENSE.
- A `CHANGELOG.md` with `## Unreleased` bullets per feature commit once
  releases start; app versions are `x.y.z+N`, `N` incremented on every
  store upload; tag releases `v<x.y.z>`.
- Signing keys, keystore passwords and store credentials never enter
  the repository (CI secrets or an ignored local properties file).
- Widgets import `package:tessera_flutter/tessera_flutter.dart` (it
  re-exports the engine).

## Tech stack

- **State: `signals` / `signals_flutter`.** Application state (the
  open file, the cube spec, layout, selection, settings, language)
  lives in signals; widgets read them with `Watch` / `watch(context)`
  and derive with `computed`. A plain `StatefulWidget` or a
  `ChangeNotifier` is fine when there is a good reason — much smaller
  or more natural code, purely local widget state (an animation, a
  text field), or when signals would only add wrapper layers around
  something that already is a notifier (tessera's own controllers).
- **Dependency injection: `get_it`.** Services and stores (file
  opening, import, export, settings persistence) are registered in one
  place at startup and looked up with `GetIt.I<T>()`; do not thread
  them through constructors or `InheritedWidget`s. Tests call
  `GetIt.I.reset()` in `setUp` and register fakes.

## Plan

Open work, in priority order, is in `TODO.md` (sections: viewer flow,
app, packaging and release, done). Read it before proposing what to do
next; tick items there as they land. The immediate next step is the
schema page, then the workbench.
