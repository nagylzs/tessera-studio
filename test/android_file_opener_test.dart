import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_studio/files/android_file_opener.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';

/// The Dart half of the Android open dialog, against a fake of
/// `DocumentPicker.kt` that answers like the real one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sheetType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  late Directory cache;
  late List<MethodCall> calls;
  late Object? picked;
  late Uint8List content;
  PlatformException? copyFails;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('picker_test');
    calls = [];
    copyFails = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidFileOpener.channel, (call) async {
          calls.add(call);
          final args = (call.arguments as Map?)?.cast<String, Object?>();
          switch (call.method) {
            case 'pick':
              return picked;
            case 'head':
              final length = args!['length'] as int;
              return content.length > length
                  ? Uint8List.sublistView(content, 0, length)
                  : content;
            case 'copy':
              if (copyFails != null) throw copyFails!;
              final file = File('${cache.path}/${args!['name']}')
                ..writeAsBytesSync(content);
              return file.path;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidFileOpener.channel, null);
    cache.deleteSync(recursive: true);
  });

  List<String> methods() => [for (final c in calls) c.method];

  test('cancelling opens nothing', () async {
    picked = null;
    expect(await const AndroidFileOpener().pick(), isNull);
    expect(methods(), ['pick']);
  });

  test('a file with a known name is copied and opened', () async {
    picked = {'name': 'sales.tsnp', 'uri': 'content://a/1', 'type': null};
    content = Uint8List.fromList(utf8.encode('TSNP…'));
    final document = await const AndroidFileOpener().pick();
    expect(document!.name, 'sales.tsnp');
    expect(document.format, FileFormat.snapshot);
    expect(methods(), ['pick', 'copy']);
    expect(calls.last.arguments, {
      'uri': 'content://a/1',
      'type': null,
      'name': 'sales.tsnp',
    });
  });

  test('a virtual document is read as the spreadsheet its provider makes '
      'of it', () async {
    // DocumentPicker names it after the type it is read as.
    picked = {
      'name': 'Alghero.xlsx',
      'uri': 'content://d/2',
      'type': sheetType,
    };
    content = Uint8List.fromList([0x50, 0x4B, 3, 4]);
    final document = await const AndroidFileOpener().pick();
    expect(document!.format, FileFormat.xlsx);
    expect(calls.last.arguments, {
      'uri': 'content://d/2',
      'type': sheetType,
      'name': 'Alghero.xlsx',
    });
  });

  test(
    'a Google Sheet, which Drive gives out only as a PDF, says so',
    () async {
      picked = {
        'name': 'Egyiptom elszámolás',
        'unsupported': true,
        'mimeType': AndroidFileOpener.googleSheetType,
      };
      await expectLater(
        const AndroidFileOpener().pick(),
        throwsA(
          isA<GoogleSheetException>().having(
            (e) => e.fileName,
            'fileName',
            'Egyiptom elszámolás',
          ),
        ),
      );
      expect(methods(), ['pick']);
    },
  );

  test('a virtual document with no spreadsheet form is turned down', () async {
    picked = {
      'name': 'Notes',
      'unsupported': true,
      'mimeType': 'application/vnd.google-apps.document',
    };
    await expectLater(
      const AndroidFileOpener().pick(),
      throwsA(
        isA<UnsupportedFileException>().having(
          (e) => e.fileName,
          'fileName',
          'Notes',
        ),
      ),
    );
    expect(methods(), ['pick']);
  });

  test('a name that says nothing is judged by its first bytes', () async {
    picked = {'name': 'download', 'uri': 'content://a/3', 'type': null};
    content = Uint8List.fromList(utf8.encode('Region,Units\nEU,3\n'));
    final document = await const AndroidFileOpener().pick();
    expect(document!.format, FileFormat.csv);
    expect(methods(), ['pick', 'head', 'copy']);
    expect((calls[1].arguments as Map)['length'], FileFormat.sniffLength);
  });

  test('a film picked by mistake is never copied', () async {
    picked = {'name': 'holiday', 'uri': 'content://a/4', 'type': null};
    content = Uint8List(4 * FileFormat.sniffLength);
    for (var i = 0; i < content.length; i++) {
      content[i] = i * 7 % 256;
    }
    await expectLater(
      const AndroidFileOpener().pick(),
      throwsA(isA<UnsupportedFileException>()),
    );
    expect(methods(), ['pick', 'head']);
  });

  test('a read that fails names the file and says why', () async {
    picked = {
      'name': 'Alghero.xlsx',
      'uri': 'content://d/2',
      'type': sheetType,
    };
    copyFails = PlatformException(code: 'read', message: 'Network error');
    await expectLater(
      const AndroidFileOpener().pick(),
      throwsA(
        isA<FileReadException>()
            .having((e) => e.fileName, 'fileName', 'Alghero.xlsx')
            .having((e) => e.toString(), 'message', 'Network error'),
      ),
    );
  });

  test('a document that cannot even be looked at is a read failure', () async {
    // The provider refused the query after the dialog had closed.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidFileOpener.channel,
          (call) async => throw PlatformException(
            code: 'read',
            message: 'Permission Denial',
          ),
        );
    await expectLater(
      const AndroidFileOpener().pick(),
      throwsA(
        isA<FileReadException>()
            .having((e) => e.fileName, 'fileName', '')
            .having((e) => e.toString(), 'message', 'Permission Denial'),
      ),
    );
  });

  test('no picker at all is a missing dialog', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidFileOpener.channel,
          (call) async => throw PlatformException(code: 'unavailable'),
        );
    await expectLater(
      const AndroidFileOpener().pick(),
      throwsA(isA<PickerUnavailableException>()),
    );
  });
}
