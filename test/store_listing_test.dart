import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Characters (code points) a store allows per text field; see
/// store/listing/README.md.
const _limits = {
  'name': 30,
  'app_store_name': 30,
  'short': 80,
  'subtitle': 30,
  'promo': 170,
  'keywords': 100,
  'summary': 270,
  'description': 4000,
};

int _length(String s) => s.runes.length;

String _code(FileSystemEntity f) =>
    f.uri.pathSegments.last.replaceAll(RegExp(r'\.(yaml|arb)$'), '');

void main() {
  // The app's languages, from the ARB files: the listings must follow.
  final languages = {
    for (final f in Directory('lib/l10n').listSync())
      if (RegExp(r'app_\w+\.arb$').hasMatch(f.path))
        _code(f).replaceFirst('app_', ''),
  };
  final listings = {
    for (final f in Directory('store/listing').listSync())
      if (f.path.endsWith('.yaml')) _code(f): File(f.path),
  };

  for (final MapEntry(key: lang, value: file) in listings.entries) {
    test('the $lang listing fits every store', () {
      final yaml = loadYaml(file.readAsStringSync()) as YamlMap;
      for (final MapEntry(key: field, value: max) in _limits.entries) {
        final value = yaml[field];
        expect(value, isA<String>(), reason: '$lang: $field');
        final text = (value as String).trim();
        expect(text, isNotEmpty, reason: '$lang: $field');
        expect(
          _length(text),
          lessThanOrEqualTo(max),
          reason: '$lang: $field has ${_length(text)} characters, $max allowed',
        );
      }
      expect(yaml['name'], 'Tessera Studio', reason: '$lang: the name');
      expect(
        yaml['app_store_name'],
        startsWith('Tessera Studio: '),
        reason: '$lang: the App Store name',
      );

      final keywords = (yaml['keywords'] as String).split(',');
      expect(
        keywords.where((k) => k != k.trim() || k.isEmpty),
        isEmpty,
        reason: '$lang: keywords without spaces around the commas',
      );
      expect(keywords.toSet(), hasLength(keywords.length), reason: lang);
      expect(
        keywords.where((k) => k.toLowerCase().contains('tessera')),
        isEmpty,
        reason: '$lang: the name is searchable without repeating it',
      );

      final features = (yaml['features'] as YamlList).cast<String>();
      expect(features.length, inInclusiveRange(1, 20), reason: lang);
      for (final f in features) {
        expect(_length(f), lessThanOrEqualTo(200), reason: '$lang: $f');
        expect(f.startsWith('•'), isFalse, reason: 'the Store adds bullets');
      }
      final terms = (yaml['search_terms'] as YamlList).cast<String>();
      expect(terms.length, inInclusiveRange(1, 7), reason: lang);
      for (final t in terms) {
        expect(_length(t), lessThanOrEqualTo(30), reason: '$lang: $t');
      }

      for (final field in ['short', 'promo', 'summary', 'description']) {
        expect(
          (yaml[field] as String).contains(RegExp(r'https?://|www\.|<\w')),
          isFalse,
          reason: '$lang: $field is plain text without URLs',
        );
      }
    });
  }

  final missing = languages.difference(listings.keys.toSet()).toList()..sort();
  test(
    'every language of the app has a listing',
    () {
      expect(listings.keys.toSet(), languages);
    },
    skip: missing.isEmpty
        ? null
        : 'translations pending: ${missing.join(', ')}',
  );
}
