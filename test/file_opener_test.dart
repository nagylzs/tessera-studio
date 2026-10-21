import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_studio/files/file_format.dart';
import 'package:tessera_studio/files/file_opener.dart';

void main() {
  late FakePicker picker;

  setUp(() => FilePickerPlatform.instance = picker = FakePicker());

  test('Android shows every file, as its filter loses .tsnp', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      picker.file = FakeFile('sales.tsnp', utf8.encode('TSNP…'));
      final document = await const PickerFileOpener().pick();
      expect(picker.type, FileType.any);
      expect(picker.allowedExtensions, isNull);
      expect(document!.format, FileFormat.snapshot);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('other platforms filter by extension', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      picker.file = null;
      expect(await const PickerFileOpener().pick(), isNull);
      expect(picker.type, FileType.custom);
      expect(picker.allowedExtensions, FileFormat.allExtensions);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('a CSV under a name that says nothing opens by its content', () async {
    picker.file = FakeFile('download', utf8.encode('Region,Units\nEU,3\n'));
    final document = await const PickerFileOpener().pick();
    expect(document!.format, FileFormat.csv);
    expect(picker.readWhole, isTrue);
  });

  test('an unknown file is turned down from its first bytes', () async {
    // An old Excel file: the OLE2 signature, then binary data.
    final xls = Uint8List(4 * FileFormat.sniffLength)
      ..setAll(0, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]);
    for (var i = 8; i < xls.length; i++) {
      xls[i] = i * 7 % 256;
    }
    picker.file = FakeFile('countries.xls', xls);
    await expectLater(
      const PickerFileOpener().pick(),
      throwsA(
        isA<UnsupportedFileException>().having(
          (e) => e.fileName,
          'fileName',
          'countries.xls',
        ),
      ),
    );
    expect(picker.readWhole, isFalse);
    expect(picker.streamed, lessThan(xls.length));
  });
}

final class FakePicker extends FilePickerPlatform {
  FakeFile? file;
  FileType? type;
  List<String>? allowedExtensions;

  bool get readWhole => file!.readWhole;
  int get streamed => file!.streamed;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    return file;
  }
}

/// Hands out its bytes in 4 KB chunks and records how much was read.
final class FakeFile extends PlatformFile {
  FakeFile(this.name, List<int> bytes) : bytes = Uint8List.fromList(bytes);

  @override
  final String name;
  final Uint8List bytes;
  bool readWhole = false;
  int streamed = 0;

  @override
  Uri get uri => Uri.file('/picked/$name');

  @override
  XFile get xFile => XFile.fromData(bytes, name: name);

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async {
    readWhole = true;
    return bytes;
  }

  @override
  Stream<Uint8List> readAsByteStream() async* {
    for (var i = 0; i < bytes.length; i += 4096) {
      final end = i + 4096 < bytes.length ? i + 4096 : bytes.length;
      streamed = end;
      yield Uint8List.sublistView(bytes, i, end);
    }
  }
}
