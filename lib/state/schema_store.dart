import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// A schema the user accepted for files of one structure, with the time
/// it was saved (shown in the "restored" banner).
final class StoredSchema {
  const StoredSchema(this.schema, {required this.savedAt});

  factory StoredSchema.fromJson(Map<String, Object?> json) => StoredSchema(
    CubeJson.standard.decodeSchema(
      (json['schema'] as Map).cast<String, Object?>(),
    ),
    savedAt: DateTime.parse(json['savedAt'] as String),
  );

  final Schema schema;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {
    'schema': CubeJson.standard.encodeSchema(schema),
    'savedAt': savedAt.toIso8601String(),
  };
}

/// Remembers the user's schema edits per source structure, keyed by
/// [Schema.structureKey] of the inferred schema. Registered in get_it.
abstract interface class SchemaStore {
  Future<StoredSchema?> read(String structureKey);
  Future<void> write(String structureKey, StoredSchema stored);
  Future<void> delete(String structureKey);
}

/// The real store: one JSON string per structure in the platform's
/// preferences (`shared_preferences`, all platforms including web).
final class PreferencesSchemaStore implements SchemaStore {
  PreferencesSchemaStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static String _key(String structureKey) => 'schema:$structureKey';

  @override
  Future<StoredSchema?> read(String structureKey) async {
    final text = await _prefs.getString(_key(structureKey));
    if (text == null) return null;
    try {
      return StoredSchema.fromJson(
        (jsonDecode(text) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null; // a damaged entry is as good as none
    }
  }

  @override
  Future<void> write(String structureKey, StoredSchema stored) =>
      _prefs.setString(_key(structureKey), jsonEncode(stored.toJson()));

  @override
  Future<void> delete(String structureKey) => _prefs.remove(_key(structureKey));
}

/// In-memory store for tests.
final class MemorySchemaStore implements SchemaStore {
  final entries = <String, StoredSchema>{};

  @override
  Future<StoredSchema?> read(String structureKey) async =>
      entries[structureKey];

  @override
  Future<void> write(String structureKey, StoredSchema stored) async =>
      entries[structureKey] = stored;

  @override
  Future<void> delete(String structureKey) async =>
      entries.remove(structureKey);
}
