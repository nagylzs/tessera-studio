import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/export/export_target.dart';
import 'package:tessera_studio/files/clipboard_reader.dart';
import 'package:tessera_studio/files/document_loader.dart';
import 'package:tessera_studio/files/file_failure.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/pages/failure_page.dart';
import 'package:tessera_studio/pages/home_page.dart';
import 'package:tessera_studio/pages/schema_page.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/state/layout_store.dart';
import 'package:tessera_studio/state/schema_store.dart';
import 'package:tessera_studio/state/settings.dart';

import 'fakes.dart';

/// Hands out the queued files one pick at a time.
final class _Opener implements FileOpener {
  final queue = <(String, List<int>)>[];

  @override
  Future<OpenedDocument?> pick() async {
    final (name, bytes) = queue.removeAt(0);
    return OpenedDocument.detect(name: name, bytes: Uint8List.fromList(bytes));
  }
}

late _Opener _opener;

void _register() {
  _opener = _Opener();
  GetIt.I
    ..registerSingleton<FileOpener>(_opener)
    ..registerSingleton<ClipboardReader>(FakeClipboard())
    ..registerSingleton<DocumentLoader>(FakeLoader())
    ..registerSingleton<SchemaStore>(MemorySchemaStore())
    ..registerSingleton<LayoutStore>(MemoryLayoutStore())
    ..registerSingleton<AppSettings>(AppSettings(MemorySettingsStore()))
    ..registerSingleton<ExportTarget>(FakeExportTarget())
    ..registerSingleton<AppState>(AppState());
}

/// Taps [finder] for real (inference does not advance on the fake
/// clock) and waits until the app is idle.
Future<void> _tapAndWait(WidgetTester tester, Finder finder) async {
  final state = GetIt.I<AppState>();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 500 && state.busy.value; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
}

/// Not UTF-8: "é" in Latin-1, as Excel's plain CSV writes it.
final latin1Csv = [
  ...utf8.encode('name,city\nAnn,'),
  0xE9,
  ...utf8.encode('\n'),
];

void main() {
  setUp(() => GetIt.I.reset());

  group('classification', () {
    FileFailure of(Object e, FileFormat f, [List<int>? bytes]) =>
        FileFailure.of(
          'x',
          e,
          format: f,
          bytes: bytes == null ? null : Uint8List.fromList(bytes),
        );

    test('each kind of failure gets its own explanation', () {
      const syntax = FormatException('FormatException: x.json: Unexpected');
      expect(
        of(syntax, FileFormat.json, utf8.encode('[')).kind,
        FailureKind.syntax,
      );
      expect(
        of(
          const FormatException('not an .xlsx workbook'),
          FileFormat.xlsx,
        ).kind,
        FailureKind.damaged,
      );
      expect(
        of(const FormatException('bad byte'), FileFormat.csv, latin1Csv).kind,
        FailureKind.notUtf8,
      );
      expect(
        of(const EmptySourceException(hasColumns: false), FileFormat.csv).kind,
        FailureKind.empty,
      );
      expect(
        of(const EmptySourceException(hasColumns: true), FileFormat.csv).kind,
        FailureKind.noRows,
      );
      expect(of(StateError('?'), FileFormat.ods).kind, FailureKind.other);
    });

    test('details drop the stacked FormatException prefixes', () {
      expect(
        FileFailure.describe(
          const FormatException('FormatException: x.json: Unexpected'),
        ),
        'x.json: Unexpected',
      );
      expect(
        of(const EmptySourceException(hasColumns: true), FileFormat.csv).detail,
        isNull,
      );
    });
  });

  testWidgets('a broken file gets the failure page; close returns home', (
    tester,
  ) async {
    _register();
    _opener.queue.add(('bad.json', utf8.encode('[{"a": 1}, {"a": 2,]')));
    await tester.pumpWidget(const TesseraStudioApp());
    await _tapAndWait(tester, find.widgetWithText(FilledButton, 'Open file…'));

    expect(find.byType(FailurePage), findsOneWidget);
    expect(find.text('Could not open bad.json'), findsOneWidget);
    expect(
      find.textContaining('The JSON file has an error in it'),
      findsOneWidget,
    );
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('bad.json: Unexpected'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(GetIt.I<AppState>().failure.value, isNull);
  });

  testWidgets('not UTF-8, empty and header-only files are explained', (
    tester,
  ) async {
    _register();
    _opener.queue
      ..add(('latin1.csv', latin1Csv))
      ..add(('empty.csv', <int>[]))
      ..add(('header.csv', utf8.encode('a,b,c\n')))
      ..add(('fine.csv', utf8.encode('a,b\n1,2\n')));
    await tester.pumpWidget(const TesseraStudioApp());
    await _tapAndWait(tester, find.widgetWithText(FilledButton, 'Open file…'));
    expect(find.textContaining('not UTF-8 text'), findsOneWidget);
    expect(find.textContaining('“CSV UTF-8”'), findsOneWidget);

    Future<void> another() =>
        _tapAndWait(tester, find.text('Open another file…'));
    await another();
    expect(find.text('Could not open empty.csv'), findsOneWidget);
    expect(find.text('The file is empty.'), findsOneWidget);
    await another();
    expect(
      find.text('The file has column headings but no rows of data.'),
      findsOneWidget,
    );
    await another();
    expect(find.byType(FailurePage), findsNothing);
    expect(find.byType(SchemaPage), findsOneWidget);
  });

  testWidgets('a failure while a file is open returns to it on close', (
    tester,
  ) async {
    _register();
    _opener.queue
      ..add(('fine.csv', utf8.encode('a,b\n1,2\n')))
      ..add(('empty.csv', <int>[]));
    await tester.pumpWidget(const TesseraStudioApp());
    await _tapAndWait(tester, find.widgetWithText(FilledButton, 'Open file…'));
    expect(find.byType(SchemaPage), findsOneWidget);
    final state = GetIt.I<AppState>();
    await tester.runAsync(state.openFile);
    await tester.pumpAndSettle();
    expect(find.byType(FailurePage), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SchemaPage), findsOneWidget);
    expect(state.document.value!.name, 'fine.csv');
  });
}
