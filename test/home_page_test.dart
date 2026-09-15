import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/app.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';
import 'package:tessera_studio/files/opened_document.dart';
import 'package:tessera_studio/l10n/generated/app_localizations.dart';
import 'package:tessera_studio/state/app_state.dart';
import 'package:tessera_studio/widgets/tessera_logo.dart';

final class _FakeOpener implements FileOpener {
  _FakeOpener(this.result);

  final Future<OpenedDocument?> Function() result;

  @override
  Future<OpenedDocument?> pick() => result();
}

void _register(FileOpener opener) {
  GetIt.I
    ..registerSingleton<FileOpener>(opener)
    ..registerSingleton<AppState>(AppState());
}

void main() {
  setUp(() => GetIt.I.reset());

  testWidgets('home shows the logo and the open button', (tester) async {
    _register(_FakeOpener(() async => null));
    await tester.pumpWidget(const TesseraStudioApp());
    expect(find.byType(TesseraLogo), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open file…'), findsOneWidget);
  });

  testWidgets('opening a file shows it in the workbench', (tester) async {
    _register(
      _FakeOpener(
        () async => OpenedDocument(
          name: 'sales.csv',
          format: FileFormat.csv,
          bytes: Uint8List.fromList('a,b\n1,2\n'.codeUnits),
        ),
      ),
    );
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('sales.csv'), findsOneWidget);
    expect(find.text('CSV file'), findsOneWidget);
    expect(find.text('8 bytes'), findsOneWidget);

    await tester.tap(find.byTooltip('Close file'));
    await tester.pumpAndSettle();
    expect(find.byType(TesseraLogo), findsOneWidget);
  });

  testWidgets('an unsupported file is reported', (tester) async {
    _register(
      _FakeOpener(() async => throw const UnsupportedFileException('x.docx')),
    );
    await tester.pumpWidget(const TesseraStudioApp());
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Unsupported file type: x.docx'), findsOneWidget);
  });

  test('the app is localised for exactly the tessera locales', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.toString()).toSet(),
      TesseraLocalizations.supportedLocales.map((l) => l.toString()).toSet(),
    );
  });

  test('file formats are detected by extension', () {
    expect(FileFormat.ofFileName('Data.CSV'), FileFormat.csv);
    expect(FileFormat.ofFileName('rows.ndjson'), FileFormat.jsonl);
    expect(FileFormat.ofFileName('cube.tsnp'), FileFormat.snapshot);
    expect(FileFormat.ofFileName('README'), isNull);
    expect(FileFormat.ofFileName('a.docx'), isNull);
  });
}
