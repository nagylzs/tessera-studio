import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/linux_metadata.dart';

void main() {
  final files = linuxMetadataFiles();

  for (final MapEntry(key: path, value: content) in files.entries) {
    test('$path is up to date', () {
      expect(
        File(path).readAsStringSync(),
        content,
        reason: 'run `dart run tool/linux_metadata.dart`',
      );
    });
  }

  test('every language of the app is in the desktop integration', () {
    final languages = [
      for (final f in Directory('lib/l10n').listSync())
        if (RegExp(r'app_(\w+)\.arb$').firstMatch(f.path) case final m?) m[1]!,
    ];
    expect(languages, hasLength(14));
    final desktop = files['linux/packaging/$appId.desktop']!;
    final mime = files['linux/packaging/$appId.xml']!;
    final metainfo = files['linux/packaging/$appId.metainfo.xml']!;
    for (final lang in languages.where((l) => l != 'en')) {
      for (final key in ['GenericName', 'Comment', 'Keywords']) {
        expect(desktop, contains('\n$key[$lang]='), reason: '$key, $lang');
      }
      expect(mime, contains('<comment xml:lang="$lang">'), reason: lang);
      for (final tag in ['summary', 'p', 'li', 'keyword']) {
        expect(metainfo, contains('<$tag xml:lang="$lang">'), reason: lang);
      }
    }
  });

  test('the desktop entry matches the GTK application id', () {
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    expect(cmake, contains('set(APPLICATION_ID "$appId")'));
    expect(File('linux/packaging/$appId.svg').existsSync(), isTrue);
  });

  test('releases are dated, newest first', () {
    final dates = [for (final (_, date) in releases) DateTime.parse(date)];
    for (var i = 1; i < dates.length; i++) {
      expect(dates[i].isBefore(dates[i - 1]), isTrue);
    }
  });
}
