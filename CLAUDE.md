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

- `lib/main.dart` registers services (`di.dart`) and runs
  `TesseraStudioApp` (`app.dart`: Material 3 light/dark from the tessera
  green `#00856e`, all localization delegates, root `SignalBuilder`
  switching between `HomePage` and `WorkbenchPage` on
  `AppState.document`).
- `lib/files/`: `FileFormat` (extension → tessera `DataSource`, plus
  `.tsnp` snapshots), `OpenedDocument` (name, format, bytes — kept in
  memory because web and Android give no path, and `fromData` sources
  are isolate-sendable), `FileOpener` (interface) with
  `PickerFileOpener` (`file_picker`, `FileType.custom` with every known
  extension, `readAsBytes`).
- `lib/state/app_state.dart`: `AppState` with the `document` and
  `opening` signals, `openFile()` (returns an `OpenFailure` for the UI to
  localise) and `closeFile()`.
- `lib/widgets/tessera_logo.dart`: the icon drawn with a `CustomPainter`
  (the shapes of `../tessera/icon/tessera-icon-foreground.svg`; no image
  asset, no SVG package). `HomePage` shows it at 60 % of the screen and
  50 % opacity behind the "Open file…" button. `WorkbenchPage` is a
  placeholder (name, format, size, close button; Android back closes the
  file through `PopScope`).
- Localization: `l10n.yaml` + `lib/l10n/app_<code>.arb` for the 14
  locales, generated by `flutter gen-l10n` (runs on `pub get`/build)
  into the git-ignored `lib/l10n/generated/`; `AppLocalizations.of(context)`.
  A test asserts the ARB locale set equals `TesseraLocalizations.supportedLocales`.
- Tests in `test/home_page_test.dart`: `GetIt.I.reset()` in `setUp`,
  then a fake `FileOpener` and a fresh `AppState` are registered.
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

## Plan (agreed so far)

1. ~~First screen: an open-file flow~~ (done) → the workbench: infer +
   isolate import with progress, schema page, axis and aggregate
   editors, filter editor, `CubeView`, current-cell info line; snapshots
   (`OpenedDocument.snapshot`) skip inference and import.
2. Save/load a pivot layout (`CubeConfig` / `CubeJson`, a `.json` file
   through the file picker) and "Save snapshot…" — the same two items
   sit in `../tessera/TODO.md` for the example app; whichever lands
   first, keep the example minimal.
3. Export menu (all formats, `CubeExportTheme` chosen by the app's
   theme), charts pane (`ChartData` / `ScatterData` + `fl_chart`),
   localization (the 14 tessera locales + the app's own strings).
4. Packaging and CI: GitHub Actions building web, Linux and Windows
   binaries and an Android app bundle per tag; Play upload manual at
   first.
