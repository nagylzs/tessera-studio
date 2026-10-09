import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// The pivot the user left files of one structure on: spec and expanded
/// groups ([config], without a schema — that is [StoredSchema]'s), the
/// aggregates the grid showed ([shown], positions in the spec's list,
/// `null` = all), and when.
final class StoredLayout {
  StoredLayout(this.config, {this.shown, required this.savedAt});

  factory StoredLayout.fromJson(Map<String, Object?> json) => StoredLayout(
    CubeJson.standard.decodeConfig(
      (json['config'] as Map).cast<String, Object?>(),
    ),
    shown: (json['shown'] as List?)?.cast<int>(),
    savedAt: DateTime.parse(json['savedAt'] as String),
  );

  final CubeConfig config;
  final List<int>? shown;
  final DateTime savedAt;

  /// The aggregates of [shown], `null` for all.
  List<Aggregate>? get shownAggregates {
    final all = config.spec.aggregates;
    return shown == null
        ? null
        : [
            for (final i in shown!)
              if (i >= 0 && i < all.length) all[i],
          ];
  }

  Map<String, Object?> toJson() => {
    'config': CubeJson.standard.encodeConfig(config),
    'shown': ?shown,
    'savedAt': savedAt.toIso8601String(),
  };
}

/// Remembers the pivot per source structure, keyed like [SchemaStore]
/// by [Schema.structureKey] of the inferred schema. Registered in get_it.
abstract interface class LayoutStore {
  Future<StoredLayout?> read(String structureKey);
  Future<void> write(String structureKey, StoredLayout stored);
  Future<void> delete(String structureKey);
}

/// The real store: one JSON string per structure in the platform's
/// preferences, next to the schemas.
final class PreferencesLayoutStore implements LayoutStore {
  PreferencesLayoutStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static String _key(String structureKey) => 'layout:$structureKey';

  @override
  Future<StoredLayout?> read(String structureKey) async {
    final text = await _prefs.getString(_key(structureKey));
    if (text == null) return null;
    try {
      return StoredLayout.fromJson(
        (jsonDecode(text) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null; // a damaged entry is as good as none
    }
  }

  @override
  Future<void> write(String structureKey, StoredLayout stored) =>
      _prefs.setString(_key(structureKey), jsonEncode(stored.toJson()));

  @override
  Future<void> delete(String structureKey) => _prefs.remove(_key(structureKey));
}

/// In-memory store for tests.
final class MemoryLayoutStore implements LayoutStore {
  final entries = <String, StoredLayout>{};

  @override
  Future<StoredLayout?> read(String structureKey) async =>
      entries[structureKey];

  @override
  Future<void> write(String structureKey, StoredLayout stored) async =>
      entries[structureKey] = stored;

  @override
  Future<void> delete(String structureKey) async =>
      entries.remove(structureKey);
}
