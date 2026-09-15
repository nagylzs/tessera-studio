import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Persists the user's settings. Registered in get_it.
abstract interface class SettingsStore {
  /// The stored theme mode name (`light`, `dark`), `null` for system.
  Future<String?> readThemeMode();
  Future<void> writeThemeMode(String? name);

  /// The stored language code, `null` for the system language.
  Future<String?> readLanguage();
  Future<void> writeLanguage(String? code);
}

final class PreferencesSettingsStore implements SettingsStore {
  PreferencesSettingsStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _theme = 'settings:themeMode';
  static const _language = 'settings:language';

  @override
  Future<String?> readThemeMode() => _prefs.getString(_theme);

  @override
  Future<void> writeThemeMode(String? name) =>
      name == null ? _prefs.remove(_theme) : _prefs.setString(_theme, name);

  @override
  Future<String?> readLanguage() => _prefs.getString(_language);

  @override
  Future<void> writeLanguage(String? code) => code == null
      ? _prefs.remove(_language)
      : _prefs.setString(_language, code);
}

/// In-memory store for tests.
final class MemorySettingsStore implements SettingsStore {
  String? themeMode;
  String? language;

  @override
  Future<String?> readThemeMode() async => themeMode;

  @override
  Future<void> writeThemeMode(String? name) async => themeMode = name;

  @override
  Future<String?> readLanguage() async => language;

  @override
  Future<void> writeLanguage(String? code) async => language = code;
}

/// The user's settings as signals the `MaterialApp` reads. Both default
/// to the system: [themeMode] follows the platform brightness and a
/// `null` [locale] lets Flutter resolve the system language (falling
/// back to English when it is not one of tessera's fourteen).
final class AppSettings {
  AppSettings(this._store);

  final SettingsStore _store;

  final themeMode = signal(ThemeMode.system);
  final locale = signal<Locale?>(null);

  /// Reads the stored values; call once before the first frame.
  Future<void> load() async {
    final theme = await _store.readThemeMode();
    themeMode.value = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final code = await _store.readLanguage();
    locale.value = code == null ? null : Locale(code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _store.writeThemeMode(mode == ThemeMode.system ? null : mode.name);
  }

  Future<void> setLocale(Locale? value) async {
    locale.value = value;
    await _store.writeLanguage(value?.languageCode);
  }
}
