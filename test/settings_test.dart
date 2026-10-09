import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/licenses.dart';
import 'package:tessera_studio/platform/links.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/layout_store.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';
import 'package:tessera_studio/style/grid_style.dart';
import 'package:tessera_studio/widgets/about.dart';

import 'fakes.dart';

final class _NoOpener implements FileOpener {
  @override
  Future<OpenedDocument?> pick() async => null;
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
    expect(settings.gridStyle.value, GridStyle.standard);

    await settings.setThemeMode(ThemeMode.dark);
    await settings.setLocale(const Locale('hu'));
    await settings.setGridStyle(GridStyle.compact);
    expect(s.themeMode, 'dark');
    expect(s.language, 'hu');
    expect(s.gridStyle, 'compact');

    final again = AppSettings(s);
    await again.load();
    expect(again.themeMode.value, ThemeMode.dark);
    expect(again.locale.value, const Locale('hu'));
    expect(again.gridStyle.value, GridStyle.compact);

    await again.setThemeMode(ThemeMode.system);
    await again.setLocale(null);
    await again.setGridStyle(GridStyle.standard);
    expect(s.themeMode, isNull);
    expect(s.language, isNull);
    expect(s.gridStyle, isNull);
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
  });

  testWidgets('About: version, the promise, licences, links', (tester) async {
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
    expect(find.text('© 2026 László Zsolt Nagy\nMIT licence'), findsOneWidget);
    expect(find.textContaining('Free and ad-free, forever'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);

    await tester.tap(find.text('tessera user guide'));
    await tester.tap(find.text('Source code'));
    expect(links.opened, [guideUrl, sourceUrl]);
  });

  test('the licences page lists the PDF font', () async {
    registerLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final noto = entries.where((e) => e.packages.contains('Noto Sans'));
    expect(noto, hasLength(1));
    final text = noto.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL OPEN FONT LICENSE'));
    expect(text, contains('The Noto Project Authors'));
  });

  testWidgets('the grid style dialog explains and applies a style', (
    tester,
  ) async {
    _register();
    await tester.pumpWidget(const TesseraStudioApp());
    await _openMenu(tester);
    await tester.tap(find.text('Grid style…'));
    await tester.pumpAndSettle();
    expect(find.text('Grid style'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text("Colours from the app's theme"), findsOneWidget);
    await tester.tap(find.text('Spreadsheet'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(GetIt.I<AppSettings>().gridStyle.value, GridStyle.spreadsheet);
    expect(store.gridStyle, 'spreadsheet');
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
