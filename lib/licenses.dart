import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds what the app bundles beyond its packages to the licences page
/// (About → View licenses): Noto Sans, Noto Serif and Noto Sans Mono
/// (assets/fonts), which the grid styles draw with and the PDF export
/// embeds, all under the SIL Open Font License; and the palettes two grid
/// styles take colours from (assets/licenses; each style file's
/// `_credits` says which): Solarized for Sand, Nord for Frost, both MIT.
void registerLicenses() => LicenseRegistry.addLicense(_licenses);

Stream<LicenseEntry> _licenses() async* {
  yield* _fontLicense();
  for (final (name, file) in const [
    ('Solarized', 'solarized'),
    ('Nord', 'nord'),
  ]) {
    final text = await rootBundle.loadString('assets/licenses/$file.txt');
    yield LicenseEntryWithLineBreaks([name], text);
  }
}

Stream<LicenseEntry> _fontLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(const [
    'Noto Sans',
    'Noto Serif',
    'Noto Sans Mono',
  ], text);
}
