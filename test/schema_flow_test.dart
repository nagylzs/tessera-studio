import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/pages/schema_page.dart';
import 'package:tessera_studio/pages/workbench_page.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/schema_store.dart';

final class _Opener implements FileOpener {
  _Opener(this.text);

  final String text;

  @override
  Future<OpenedDocument?> pick() async => OpenedDocument(
    name: 'sales.csv',
    format: FileFormat.csv,
    bytes: Uint8List.fromList(text.codeUnits),
  );
}

late MemorySchemaStore store;

void _register(String csv) {
  store = MemorySchemaStore();
  GetIt.I
    ..registerSingleton<FileOpener>(_Opener(csv))
    ..registerSingleton<DocumentLoader>(const IoDocumentLoader())
    ..registerSingleton<SchemaStore>(store)
    ..registerSingleton<AppState>(AppState());
}

/// Taps "Open file…" and waits for inference. Under [WidgetTester.runAsync]
/// because tessera's source streams do not complete on the fake clock.
Future<void> _open(WidgetTester tester) async {
  final state = GetIt.I<AppState>();
  await tester.runAsync(() async {
    await tester.tap(find.widgetWithText(FilledButton, 'Open file…'));
    for (var i = 0; i < 200 && state.opening.value; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  expect(state.opening.value, isFalse);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GetIt.I.reset());

  testWidgets('edited schema is remembered and restored by structure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    _register('region,amount\nEU,1\nUS,2\n');
    await tester.pumpWidget(const TesseraStudioApp());
    await _open(tester);
    expect(find.byType(SchemaPage), findsOneWidget);
    expect(find.text('EU · US'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('label-region')),
      'Region',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkbenchPage), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);
    expect(store.entries.keys, ['["region","amount"]']);
    expect(store.entries.values.single.schema['region']!.label, 'Region');

    // The same structure again: straight to the workbench, with the
    // banner; different data does not matter.
    await tester.tap(find.byTooltip('Close file'));
    await tester.pumpAndSettle();
    GetIt.I.unregister<FileOpener>();
    GetIt.I.registerSingleton<FileOpener>(_Opener('region,amount\nX,9\n'));
    await _open(tester);
    expect(find.byType(WorkbenchPage), findsOneWidget);
    expect(find.textContaining('Schema restored'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);

    // Reset: schema page with the inferred schema, entry gone.
    await tester.tap(find.text('Reset to inferred'));
    await tester.pumpAndSettle();
    expect(find.byType(SchemaPage), findsOneWidget);
    expect(store.entries, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkbenchPage), findsOneWidget);
    expect(find.text('region'), findsOneWidget);
    expect(find.textContaining('Schema restored'), findsNothing);
  });

  testWidgets('an unedited schema is not stored', (tester) async {
    _register('a,b\n1,2\n');
    await tester.pumpWidget(const TesseraStudioApp());
    await _open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkbenchPage), findsOneWidget);
    expect(store.entries, isEmpty);
  });

  testWidgets('back from the schema page closes the file', (tester) async {
    _register('a,b\n1,2\n');
    await tester.pumpWidget(const TesseraStudioApp());
    await _open(tester);
    await tester.tap(find.byTooltip('Close file'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Open file…'), findsOneWidget);
  });

  testWidgets('Schema… from the workbench returns there on back', (
    tester,
  ) async {
    _register('a,b\n1,2\n');
    await tester.pumpWidget(const TesseraStudioApp());
    await _open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Schema…'));
    await tester.pumpAndSettle();
    expect(find.byType(SchemaPage), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkbenchPage), findsOneWidget);
  });

  test('the preferences store round-trips and survives damage', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    final s = PreferencesSchemaStore(prefs);
    const key = '["a"]';
    expect(await s.read(key), isNull);
    final schema = Schema([
      const ColumnSpec(name: 'a', type: ColumnType.date, format: 'dd.MM.yyyy'),
    ]);
    await s.write(key, StoredSchema(schema, savedAt: DateTime(2026, 9, 15)));
    final back = (await s.read(key))!;
    expect(back.savedAt, DateTime(2026, 9, 15));
    expect(back.schema['a']!.format, 'dd.MM.yyyy');
    expect(back.schema.structureKey, key);
    await prefs.setString('schema:$key', '{not json');
    expect(await s.read(key), isNull);
    await s.delete(key);
    expect(await prefs.getString('schema:$key'), isNull);
  });
}
