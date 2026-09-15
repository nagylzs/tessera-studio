import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Where the axis and aggregate editors live on the cube page.
enum CubePageLayout {
  /// By window width: [editors] from 840 dp up, [cubeOnly] below.
  auto,

  /// Editors inline above the grid (desktop windows, wide tablets).
  editors,

  /// Only the grid; the editors open in a bottom sheet (phones).
  cubeOnly;

  /// Material's "expanded" breakpoint.
  static const wideFrom = 840.0;

  /// The layout to use at [width]; never [auto].
  CubePageLayout resolve(double width) => switch (this) {
    auto => width >= wideFrom ? editors : cubeOnly,
    _ => this,
  };
}

/// Persists the user's settings. Registered in get_it.
abstract interface class SettingsStore {
  /// The stored theme mode name (`light`, `dark`), `null` for system.
  Future<String?> readThemeMode();
  Future<void> writeThemeMode(String? name);

  /// The stored language code, `null` for the system language.
  Future<String?> readLanguage();
  Future<void> writeLanguage(String? code);

  /// The stored [CubePageLayout] name, `null` for [CubePageLayout.auto].
  Future<String?> readCubeLayout();
  Future<void> writeCubeLayout(String? name);
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

  static const _cubeLayout = 'settings:cubeLayout';

  @override
  Future<String?> readCubeLayout() => _prefs.getString(_cubeLayout);

  @override
  Future<void> writeCubeLayout(String? name) => name == null
      ? _prefs.remove(_cubeLayout)
      : _prefs.setString(_cubeLayout, name);
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

  String? cubeLayout;

  @override
  Future<String?> readCubeLayout() async => cubeLayout;

  @override
  Future<void> writeCubeLayout(String? name) async => cubeLayout = name;
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
  final cubeLayout = signal(CubePageLayout.auto);

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
    final layout = await _store.readCubeLayout();
    cubeLayout.value = CubePageLayout.values.firstWhere(
      (l) => l.name == layout,
      orElse: () => CubePageLayout.auto,
    );
  }

  Future<void> setCubeLayout(CubePageLayout layout) async {
    cubeLayout.value = layout;
    await _store.writeCubeLayout(
      layout == CubePageLayout.auto ? null : layout.name,
    );
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
