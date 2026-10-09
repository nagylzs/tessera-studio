import 'package:flutter/services.dart';

/// The status and navigation bars, hidden for the cube page's full
/// screen. Registered in get_it; tests register a fake.
abstract interface class SystemBars {
  /// Hides both bars; a swipe from an edge shows them for a moment.
  Future<void> hide();

  /// Shows both bars again (edge to edge, Flutter's default).
  Future<void> show();
}

/// [SystemChrome]: Android and iOS hide the bars, desktops and the web
/// ignore the call (the page still drops its own app bar there).
final class PlatformSystemBars implements SystemBars {
  const PlatformSystemBars();

  @override
  Future<void> hide() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  @override
  Future<void> show() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}
