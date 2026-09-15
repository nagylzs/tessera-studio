# Tessera Studio — project notes for Claude

The end-user application built on the tessera packages: open a CSV,
Excel, ODS or JSON file, pivot it with expandable row and column
hierarchies, filter, calculate, chart, export. Owner: László Zsolt Nagy
(nagylzs@gmail.com). MIT. Targets: Android (Google Play), web, Windows
and Linux binaries. No iOS/macOS folders on purpose (cannot build them
here), but they may be added later with `flutter create --platforms
ios,macos .` — so **ask the owner before adding a dependency that does
not support iOS and macOS**, even though those platforms are not built
yet.

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
  (`tessera_flutter ^0.2.1`, exporters `^0.2.0`). For developing both at
  once, `pubspec_overrides.yaml` (git-ignored, exists locally) points
  all seven packages at `../tessera/packages/*`; delete it to build
  against pub.dev. Pub accepts workspace members as path overrides from
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
  extension, `readAsBytes`), `DocumentLoader` (interface) with
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
  app runs, `singleTop`). The manifest's intent filters match by MIME
  type (CSV, TSV, plain text, JSON, NDJSON, XLSX, ODS); `.tsnp` is not
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
  start` tests the cold-start path; without it `onNewIntent`.
  Screenshots: `adb exec-out screencap -p > shot.png`.
- Home screen buttons: "Open file…" (picker) and "Open from clipboard"
  (`AppState.openFromClipboard`: a single line that is an http(s) URL,
  a `file:` URL or an absolute path goes through `loadFrom`, anything
  else is `OpenedDocument.detect`ed as text named "Clipboard" — Excel
  copies as TSV; `NothingToOpen` otherwise). The button follows
  `clipboardAvailable`, refreshed by `HomePage` (stateful for its
  `AppLifecycleListener`) on appearance and on resume.
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
  `columnNames()`, the first 5 rows as samples, `inferSchema`, then a
  `SchemaStore` lookup by `Schema.structureKey` of the inferred schema.
  No entry → `SchemaPage` (the example's column editor reshaped:
  include switch, type, label, date format / number syntax, samples;
  rows wrap under 720 px for phones; "Reset to inferred", "Continue",
  close/back = discard). Entry → straight to `WorkbenchPage` with a
  `MaterialBanner` "Schema restored from the one you saved on <date>"
  offering "Reset to inferred" (forgets the entry, opens the schema
  page with the inferred schema) and OK. "Continue" stores the schema
  when it differs from the inferred one (`AppState.sameSchema`, JSON
  equality through `CubeJson.encodeSchema`) and deletes the entry when
  it equals it. Snapshots skip all of this (schema from the facts).
  `AppState.page` (`AppPage.home/schema/workbench`) drives the root;
  `schemaBack` says where the schema page's back goes.
- `lib/state/schema_store.dart`: `SchemaStore` (`read/write/delete` by
  structure key), `PreferencesSchemaStore` (`shared_preferences`, key
  `schema:<structureKey>`, JSON `{schema, savedAt}`; a damaged entry
  reads as none) and `MemorySchemaStore` for tests. The same store is
  where a pivot layout per structure will go later.
- `WorkbenchPage` is still a placeholder (name, format, size, the
  included columns with localised type names via `lib/l10n/labels.dart`,
  "Schema…" action, close); the import and the `CubeView` come next.
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
  has no launcher icon in Flutter's runner; it comes with packaging (a
  `.desktop` file + PNG) later.
- Names: "Tessera Studio" is set in the Android manifest label, the web
  manifest/`index.html`, `linux/runner/my_application.cc` (window and
  header-bar title), `windows/runner/main.cpp` and `Runner.rc`
  (product name, company, copyright). Application id
  `eu.nagylzs.tessera_studio`. Keep the four spellings consistent:
  repo `tessera-studio`, package `tessera_studio`, id as above,
  display name "Tessera Studio". There are unrelated "Tessera" apps on
  Google Play (RSS reader, prayer app, games); the "Studio" suffix and
  our own icon keep the listing distinct — never publish as plain
  "Tessera".

## Commands

```bash
flutter pub get
flutter analyze                # must be clean
flutter test
flutter run -d linux           # or -d chrome / -d windows / an Android device
dart run flutter_launcher_icons   # after re-rasterizing assets/icon
flutter build linux --release / windows --release / web --release / appbundle
```

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
Stop the app and Xvfb by pid afterwards (`pkill -f <pattern>` matches
the shell running it and kills that shell instead).

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
