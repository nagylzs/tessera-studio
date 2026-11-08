import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// The fonts the app bundles for the three kinds a style may name; the
/// screen draws with them and the PDF export embeds them (`pubspec.yaml`,
/// `tool/subset_fonts.sh`).
const styleFontFamilies = {
  StyleFamily.sans: 'Noto Sans',
  StyleFamily.serif: 'Noto Serif',
  StyleFamily.mono: 'Noto Sans Mono',
};

/// The style a stored id that is no longer offered falls back to, and the
/// default.
const defaultStyleId = 'standard';

/// The grid styles the app offers, hand-crafted in `assets/styles/` in the
/// format of tessera's `docs/style.md`, in the order of their file names.
/// Loaded once before the first frame; under "Grid style…" as a gallery.
/// The style a user picked is stored by its id (`AppSettings.gridStyle`):
/// the first six keep the names of the styles before the gallery, so a
/// choice made then still holds.
final class StyleGallery {
  StyleGallery(List<CubeStyle> styles) : styles = List.unmodifiable(styles) {
    assert(styles.isNotEmpty, 'a gallery without styles');
  }

  /// Where the styles are, one JSON file each.
  static const folder = 'assets/styles/';

  final List<CubeStyle> styles;

  /// The style [id], or the default where there is none such.
  CubeStyle byId(String? id) =>
      styles.where((s) => s.id == id).firstOrNull ??
      styles.where((s) => s.id == defaultStyleId).firstOrNull ??
      styles.first;

  /// Reads every style in [folder]. One that fails to read is left out
  /// (the tests read them all, so this is a last resort).
  static Future<StyleGallery> load([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(assets);
    final paths = [
      for (final path in manifest.listAssets())
        if (path.startsWith(folder) && path.endsWith('.json')) path,
    ]..sort();
    final styles = <CubeStyle>[];
    for (final path in paths) {
      try {
        styles.add(JsonCubeStyle.parse(await assets.loadString(path)));
      } on FormatException catch (e) {
        debugPrint('$path: ${e.message}');
      }
    }
    return StyleGallery(styles);
  }
}
