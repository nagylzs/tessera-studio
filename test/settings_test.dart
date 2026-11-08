import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera_flutter/tessera_flutter.dart'
    show CubeStylePreview, DepthColoring;
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/licenses.dart';
import 'package:tessera_studio/pages/style_gallery_page.dart';
import 'package:tessera_studio/platform/links.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/layout_store.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';
import 'package:tessera_studio/style/style_gallery.dart';
import 'package:tessera_studio/widgets/about.dart';

import 'fakes.dart';

final class _NoOpener implements FileOpener {
  @override
  Future<OpenedDocument?> pick({String? dialogTitle}) async => null;
}

late MemoryLayoutStore layouts;
late MemorySettingsStore store;
late FakeLinkOpener links;

void _register() {
  store = MemorySettingsStore();
  links = FakeLinkOpener();
  GetIt.I
    ..registerSingleton<LinkOpener>(links)
    ..registerSingleton<FileOpener>(_NoOpener())
    ..registerSingleton<ClipboardReader>(FakeClipboard())
    ..registerSingleton<DocumentLoader>(FakeLoader())
    ..registerSingleton<SchemaStore>(MemorySchemaStore())
    ..registerSingleton<LayoutStore>(layouts = MemoryLayoutStore())
    ..registerSingleton<StyleGallery>(testGallery())
    ..registerSingleton<AppSettings>(AppSettings(store))
    ..registerSingleton<AppState>(AppState());
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GetIt.I.reset());

  test('settings load with system defaults and persist choices', () async {
    final s = MemorySettingsStore();
    final settings = AppSettings(s);
    await settings.load();
    expect(settings.themeMode.value, ThemeMode.system);
    expect(settings.locale.value, isNull);
    expect(settings.gridStyle.value, 'standard');
    expect(settings.depthColoring.value, DepthColoring.both);

    await settings.setThemeMode(ThemeMode.dark);
    await settings.setLocale(const Locale('hu'));
    await settings.setGridStyle('compact');
    await settings.setDepthColoring(DepthColoring.rows);
    expect(s.themeMode, 'dark');
    expect(s.language, 'hu');
    expect(s.gridStyle, 'compact');
    expect(s.depthColoring, 'rows');

    final again = AppSettings(s);
    await again.load();
    expect(again.themeMode.value, ThemeMode.dark);
    expect(again.locale.value, const Locale('hu'));
    expect(again.gridStyle.value, 'compact');
    expect(again.depthColoring.value, DepthColoring.rows);

    await again.setThemeMode(ThemeMode.system);
    await again.setLocale(null);
    await again.setGridStyle('standard');
    await again.setDepthColoring(DepthColoring.both);
    expect(s.themeMode, isNull);
    expect(s.language, isNull);
    expect(s.gridStyle, isNull);
    expect(s.depthColoring, isNull);
  });

  test('the preferences store round-trips', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final s = PreferencesSettingsStore(SharedPreferencesAsync());
    expect(await s.readThemeMode(), isNull);
    await s.writeThemeMode('light');
    await s.writeLanguage('de');
    expect(await s.readThemeMode(), 'light');
    expect(await s.readLanguage(), 'de');
    await s.writeThemeMode(null);
    expect(await s.readThemeMode(), isNull);
    await s.writeGridStyle('spreadsheet');
    expect(await s.readGridStyle(), 'spreadsheet');
    await s.writeDepthColoring('columns');
    expect(await s.readDepthColoring(), 'columns');
  });

  testWidgets('About: version, the promise, licenses, links', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'tessera_studio',
      packageName: 'eu.nagylzs.tessera_studio',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    _register();
    await tester.pumpWidget(const TesseraStudioApp());
    await _openMenu(tester);
    await tester.tap(find.text('About…'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('Tessera Studio'), findsWidgets);
    expect(find.text('1.0.0 (1)'), findsOneWidget);
    expect(find.text('© 2026 László Zsolt Nagy\nMIT license'), findsOneWidget);
    expect(find.textContaining('Free and ad-free, forever'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);

    await tester.tap(find.text('tessera user guide'));
    await tester.tap(find.text('Source code'));
    expect(links.opened, [guideUrl, sourceUrl]);
  });

  test('the licenses page lists the PDF font', () async {
    registerLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final noto = entries.where((e) => e.packages.contains('Noto Sans'));
    expect(noto, hasLength(1));
    expect(noto.single.packages, containsAll(['Noto Serif', 'Noto Sans Mono']));
    final text = noto.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL OPEN FONT LICENSE'));
    expect(text, contains('The Noto Project Authors'));
  });

  testWidgets('the style gallery applies a style and the depth coloring', (
    tester,
  ) async {
    _register();
    await tester.pumpWidget(const TesseraStudioApp());
    await _openMenu(tester);
    await tester.tap(find.text('Grid style…'));
    await tester.pumpAndSettle();
    expect(find.byType(StyleGalleryPage), findsOneWidget);
    expect(find.text('Grid style'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.byType(CubeStylePreview), findsWidgets);
    await tester.tap(find.text('Spreadsheet'));
    await tester.pumpAndSettle();
    // applied at once; the page stays, to compare
    expect(GetIt.I<AppSettings>().gridStyle.value, 'spreadsheet');
    expect(store.gridStyle, 'spreadsheet');
    expect(find.byType(StyleGalleryPage), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Spreadsheet')),
      matchesSemantics(
        label: 'Spreadsheet',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Rows'));
    await tester.pumpAndSettle();
    expect(GetIt.I<AppSettings>().depthColoring.value, DepthColoring.rows);
    expect(store.depthColoring, 'rows');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(StyleGalleryPage), findsNothing);
  });

  testWidgets('the style gallery fits a phone at a larger text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    _register();
    await tester.pumpWidget(const TesseraStudioApp());
    await _openMenu(tester);
    await tester.tap(find.text('Grid style…'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final gallery = GetIt.I<StyleGallery>();
    final last = find.text(gallery.styles.last.name('en'));
    await tester.scrollUntilVisible(
      last,
      300,
      // the page's, not the depth switch's sideways one
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(GetIt.I<AppSettings>().gridStyle.value, gallery.styles.last.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the theme dialog switches the app to dark', (tester) async {
    _register();
    await tester.pumpWidget(const TesseraStudioApp());
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    await _openMenu(tester);
    await tester.tap(find.text('Theme…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(store.themeMode, 'dark');
  });

  testWidgets('the language dialog relabels the app at once', (tester) async {
    _register();
    await tester.pumpWidget(const TesseraStudioApp());
    await _openMenu(tester);
    await tester.tap(find.text('Language…'));
    await tester.pumpAndSettle();
    expect(find.text('System'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Magyar'));
    await tester.pumpAndSettle();
    expect(find.text('Fájl megnyitása…'), findsOneWidget);
    expect(store.language, 'hu');

    // And back to the system language through the (now Hungarian) menu.
    await tester.tap(find.byTooltip('Továbbiak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nyelv…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rendszer'));
    await tester.pumpAndSettle();
    expect(find.text('Open file…'), findsOneWidget);
    expect(store.language, isNull);
  });
}
