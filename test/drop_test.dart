import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/pages/schema_page.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';

import 'fakes.dart';

final class _NoOpener implements FileOpener {
  @override
  Future<OpenedDocument?> pick() async => null;
}

late FakeLoader loader;

void _register() {
  loader = FakeLoader();
  GetIt.I
    ..registerSingleton<FileOpener>(_NoOpener())
    ..registerSingleton<ClipboardReader>(FakeClipboard())
    ..registerSingleton<DocumentLoader>(loader)
    ..registerSingleton<SchemaStore>(MemorySchemaStore())
    ..registerSingleton<AppSettings>(AppSettings(MemorySettingsStore()))
    ..registerSingleton<AppState>(AppState());
}

void main() {
  setUp(() => GetIt.I.reset());

  test(
    'a dropped file with a path goes to the loader under its name',
    () async {
      _register();
      final done = GetIt.I<AppState>().openDropped(XFile('/data/q3.xlsx'));
      expect(loader.loadedSource, '/data/q3.xlsx');
      expect(loader.loadedName, 'q3.xlsx');
      loader.completer.completeError(const LoadException('boom'));
      await done;
      expect(GetIt.I<AppState>().loadFailure.value, isA<OpenError>());
    },
  );

  testWidgets('a dropped file without a path (web) opens from its bytes', (
    tester,
  ) async {
    _register();
    final state = GetIt.I<AppState>();
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.runAsync(() async {
      await state.openDropped(
        XFile.fromData(
          Uint8List.fromList('a;b\n1;2\n'.codeUnits),
          name: 'export.csv',
        ),
      );
    });
    await tester.pumpAndSettle();
    expect(find.byType(SchemaPage), findsOneWidget);
    // The IO XFile derives its name from the (empty) path, so the
    // fallback name shows here; the web XFile keeps the given name.
    expect(find.text('file'), findsOneWidget);
    expect(state.document.value!.delimiter, ';');
  });

  testWidgets('the drop target exists on Linux and not on Android', (
    tester,
  ) async {
    _register();
    // Fresh keys: an identical widget instance would not be rebuilt.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(TesseraStudioApp(key: UniqueKey()));
    await tester.pump();
    expect(find.byType(DropTarget), findsNothing);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(TesseraStudioApp(key: UniqueKey()));
    await tester.pump();
    expect(find.byType(DropTarget), findsOneWidget);
    // The framework checks debug variables before tear-downs run.
    debugDefaultTargetPlatformOverride = null;
  });
}
