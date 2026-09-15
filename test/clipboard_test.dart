import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/pages/schema_page.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/schema_store.dart';

import 'fakes.dart';

final class _NoOpener implements FileOpener {
  @override
  Future<OpenedDocument?> pick() async => null;
}

late FakeClipboard clipboard;
late FakeLoader loader;

void _register(String? text) {
  clipboard = FakeClipboard(text);
  loader = FakeLoader();
  GetIt.I
    ..registerSingleton<FileOpener>(_NoOpener())
    ..registerSingleton<ClipboardReader>(clipboard)
    ..registerSingleton<DocumentLoader>(loader)
    ..registerSingleton<SchemaStore>(MemorySchemaStore())
    ..registerSingleton<AppState>(AppState());
}

Finder get _button => find.widgetWithText(FilledButton, 'Open from clipboard');

Future<void> _press(WidgetTester tester) async {
  final state = GetIt.I<AppState>();
  await tester.runAsync(() async {
    await tester.tap(_button);
    for (
      var i = 0;
      i < 200 && (state.opening.value || state.loading.value != null);
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      // A source handed to the loader: answer with a small CSV so the
      // flow runs to its end.
      if (loader.loadedSource != null && !loader.completer.isCompleted) {
        loader.completer.complete(
          OpenedDocument.detect(
            name: 'rows.csv',
            bytes: Uint8List.fromList('a,b\n1,2\n'.codeUnits),
          ),
        );
      }
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => GetIt.I.reset());

  test('what a clipboard line names', () {
    expect(
      AppState.clipboardSource('https://x.org/a.csv'),
      'https://x.org/a.csv',
    );
    expect(AppState.clipboardSource('file:///tmp/a.csv'), '/tmp/a.csv');
    expect(AppState.clipboardSource('/tmp/a.csv'), '/tmp/a.csv');
    expect(AppState.clipboardSource(r'C:\data\a.csv'), r'C:\data\a.csv');
    expect(AppState.clipboardSource('a,b\n1,2'), isNull);
    expect(AppState.clipboardSource('hello'), isNull);
    expect(AppState.clipboardSource('mailto:x@y.z'), isNull);
  });

  testWidgets('the button is disabled while the clipboard is empty', (
    tester,
  ) async {
    _register(null);
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.pump();
    expect(tester.widget<FilledButton>(_button).enabled, isFalse);
    clipboard.text = 'x';
    await GetIt.I<AppState>().refreshClipboard();
    await tester.pump();
    expect(tester.widget<FilledButton>(_button).enabled, isTrue);
  });

  testWidgets('a URL on the clipboard goes to the loader', (tester) async {
    _register('https://example.com/rows.csv');
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.pump();
    await _press(tester);
    expect(loader.loadedSource, 'https://example.com/rows.csv');
    expect(find.byType(SchemaPage), findsOneWidget);
  });

  testWidgets('cells copied from a spreadsheet open as a table', (
    tester,
  ) async {
    _register('region\tamount\r\nEU\t1\r\nUS\t2\r\n');
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.pump();
    await _press(tester);
    expect(find.byType(SchemaPage), findsOneWidget);
    expect(find.text('Clipboard'), findsOneWidget);
    expect(find.text('EU · US'), findsOneWidget);
    final doc = GetIt.I<AppState>().document.value!;
    expect(doc.format, FileFormat.tsv);
  });

  testWidgets('a semicolon CSV text keeps its delimiter', (tester) async {
    _register('a;b\n1;2\n');
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.pump();
    await _press(tester);
    expect(find.byType(SchemaPage), findsOneWidget);
    expect(GetIt.I<AppState>().document.value!.delimiter, ';');
  });

  testWidgets('a lone word is nothing to open', (tester) async {
    _register('hello');
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.pump();
    await _press(tester);
    expect(find.text('Nothing to open in the clipboard.'), findsOneWidget);
  });
}
