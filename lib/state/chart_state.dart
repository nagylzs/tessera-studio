import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../charts/chart_settings.dart';
import 'layout_store.dart';

/// The chart of the open document: whether it shows and how, remembered per
/// source structure like the pivot. Owned by `CubeState`.
final class ChartState {
  /// Off until asked for: a file opens on its pivot table.
  final visible = signal(false);
  final settings = signal(const ChartSettings());

  /// Where changes are remembered; `null` for none (a snapshot).
  String? _key;

  /// Starts from what is stored under [key], or the defaults.
  Future<void> start(String? key) async {
    clear();
    _key = key;
    if (key == null) return;
    final stored = await GetIt.I<LayoutStore>().readChart(key);
    // another file may have opened in the meantime
    if (stored == null || _key != key) return;
    visible.value = stored.visible;
    settings.value = stored.settings;
  }

  void setVisible(bool value) {
    visible.value = value;
    _save();
  }

  void update(ChartSettings value) {
    settings.value = value;
    _save();
  }

  void clear() {
    _key = null;
    visible.value = false;
    settings.value = const ChartSettings();
  }

  /// A hidden chart with the default settings leaves no entry behind.
  void _save() {
    final key = _key;
    if (key == null) return;
    final store = GetIt.I<LayoutStore>();
    final json = jsonEncode(settings.value.toJson());
    if (!visible.value && json == jsonEncode(const ChartSettings().toJson())) {
      store.deleteChart(key);
      return;
    }
    store.writeChart(
      key,
      StoredChart(visible: visible.value, settings: settings.value),
    );
  }
}
