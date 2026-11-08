import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../charts/chart_settings.dart';

import 'package:tessera_flutter/tessera_flutter.dart' show DepthColoring;

import '../style/style_gallery.dart';

/// Where the axis and aggregate editors live on the cube page.
enum CubePageLayout {
  /// By window size: [editors] from 840 × 480 dp up, [cubeOnly] below
  /// (a phone turned to landscape is wide enough but too low).
  auto,

  /// Editors inline above the grid (desktop windows, wide tablets).
  editors,

  /// Only the grid; the editors open in a bottom sheet (phones).
  cubeOnly;

  /// Material's "expanded" width breakpoint.
  static const wideFrom = 840.0;

  /// Material's "medium" height breakpoint; every phone in landscape is
  /// below it ("compact").
  static const tallFrom = 480.0;

  /// The layout to use in a window of [size]; never [auto].
  CubePageLayout resolve(Size size) => switch (this) {
    auto =>
      size.width >= wideFrom && size.height >= tallFrom ? editors : cubeOnly,
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

  /// The stored grid style's id, `null` for [defaultStyleId].
  Future<String?> readGridStyle();
  Future<void> writeGridStyle(String? id);

  /// The stored [DepthColoring] name, `null` for [DepthColoring.both].
  Future<String?> readDepthColoring();
  Future<void> writeDepthColoring(String? name);

  /// The grid's share of a window split with a chart, `null` for half.
  Future<double?> readChartSplit();
  Future<void> writeChartSplit(double? fraction);

  Future<String?> readChartLook();
  Future<void> writeChartLook(String? name);
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

  static const _gridStyle = 'settings:gridStyle';
  static const _depthColoring = 'settings:depthColoring';

  @override
  Future<String?> readGridStyle() => _prefs.getString(_gridStyle);

  @override
  Future<void> writeGridStyle(String? id) =>
      id == null ? _prefs.remove(_gridStyle) : _prefs.setString(_gridStyle, id);

  @override
  Future<String?> readDepthColoring() => _prefs.getString(_depthColoring);

  @override
  Future<void> writeDepthColoring(String? name) => name == null
      ? _prefs.remove(_depthColoring)
      : _prefs.setString(_depthColoring, name);

  static const _chartSplit = 'settings:chartSplit';

  @override
  Future<double?> readChartSplit() => _prefs.getDouble(_chartSplit);

  @override
  Future<void> writeChartSplit(double? fraction) => fraction == null
      ? _prefs.remove(_chartSplit)
      : _prefs.setDouble(_chartSplit, fraction);

  static const _chartLook = 'settings:chartLook';

  @override
  Future<String?> readChartLook() => _prefs.getString(_chartLook);

  @override
  Future<void> writeChartLook(String? name) => name == null
      ? _prefs.remove(_chartLook)
      : _prefs.setString(_chartLook, name);
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

  String? gridStyle;
  String? depthColoring;

  @override
  Future<String?> readGridStyle() async => gridStyle;

  @override
  Future<void> writeGridStyle(String? id) async => gridStyle = id;

  @override
  Future<String?> readDepthColoring() async => depthColoring;

  @override
  Future<void> writeDepthColoring(String? name) async => depthColoring = name;

  double? chartSplit;

  @override
  Future<double?> readChartSplit() async => chartSplit;

  @override
  Future<void> writeChartSplit(double? fraction) async => chartSplit = fraction;

  String? chartLook;

  @override
  Future<String?> readChartLook() async => chartLook;

  @override
  Future<void> writeChartLook(String? name) async => chartLook = name;
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

  /// The id of the grid style ([StyleGallery]); one the gallery no longer
  /// has shows as its default.
  final gridStyle = signal(defaultStyleId);

  /// Which depths pick the grid style's colours: the user's, for any style.
  final depthColoring = signal(DepthColoring.both);

  /// The first pane's share of a window split between grid and chart.
  final chartSplit = signal(0.5);

  /// How the last exported chart looked: the next one starts from it.
  final chartLook = signal<ChartLook>(plainChartLook);

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
    gridStyle.value = await _store.readGridStyle() ?? defaultStyleId;
    final coloring = await _store.readDepthColoring();
    depthColoring.value = DepthColoring.values.firstWhere(
      (c) => c.name == coloring,
      orElse: () => DepthColoring.both,
    );
    chartSplit.value = await _store.readChartSplit() ?? 0.5;
    final look = await _store.readChartLook();
    chartLook.value = (
      dark: look?.contains('dark') ?? false,
      transparent: look?.contains('transparent') ?? false,
    );
  }

  Future<void> setChartLook(ChartLook look) async {
    chartLook.value = look;
    await _store.writeChartLook(
      look == plainChartLook
          ? null
          : [
              if (look.dark) 'dark',
              if (look.transparent) 'transparent',
            ].join(' '),
    );
  }

  Future<void> setChartSplit(double fraction) async {
    chartSplit.value = fraction;
    await _store.writeChartSplit(fraction);
  }

  Future<void> setGridStyle(String id) async {
    gridStyle.value = id;
    await _store.writeGridStyle(id == defaultStyleId ? null : id);
  }

  Future<void> setDepthColoring(DepthColoring coloring) async {
    depthColoring.value = coloring;
    await _store.writeDepthColoring(
      coloring == DepthColoring.both ? null : coloring.name,
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
