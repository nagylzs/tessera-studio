import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';

import 'file_format.dart';
import 'file_opener.dart';
import 'opened_document.dart';

/// The open dialog on Android: the system's document picker through
/// `DocumentPicker` in `android/.../DocumentPicker.kt`, not file_picker's.
///
/// Every document can be picked, whatever media type the device has on
/// record for it (unknown extensions such as .tsnp and .jsonl were greyed
/// out by a filter), and so can a document without a file behind it: a
/// Google Sheet in Drive arrives as the XLSX its provider makes of it. The
/// detection here turns down what is not ours, a film by its first bytes
/// rather than whole.
final class AndroidFileOpener implements FileOpener {
  const AndroidFileOpener();

  static const channel = MethodChannel('eu.nagylzs.tessera_studio/pick');

  @override
  Future<OpenedDocument?> pick({String? dialogTitle}) async {
    final Map<String, Object?>? picked;
    try {
      picked = await channel.invokeMapMethod<String, Object?>('pick');
    } on PlatformException catch (e) {
      throw PickerUnavailableException(e);
    }
    if (picked == null) return null;
    final name = picked['name'] as String;
    if (picked['unsupported'] == true) throw UnsupportedFileException(name);
    final source = {'uri': picked['uri'], 'type': picked['type']};
    try {
      if (FileFormat.ofFileName(name) == null) {
        final head = await channel.invokeMethod<Uint8List>('head', {
          ...source,
          'length': FileFormat.sniffLength,
        });
        if (FileFormat.ofBytes(head!) == null) {
          throw UnsupportedFileException(name);
        }
      }
      final path = await channel.invokeMethod<String>('copy', {
        ...source,
        'name': name,
      });
      return OpenedDocument.detect(
        name: name,
        bytes: await XFile(path!).readAsBytes(),
      );
    } on PlatformException catch (e) {
      throw FileReadException(name, e.message ?? e.code);
    }
  }
}
