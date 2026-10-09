import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds what the app bundles beyond its packages to the licences page
/// (About → View licenses): the PDF export embeds Noto Sans
/// (assets/fonts), which comes under the SIL Open Font License.
void registerLicenses() => LicenseRegistry.addLicense(_fontLicense);

Stream<LicenseEntry> _fontLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['Noto Sans'], text);
}
