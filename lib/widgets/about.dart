import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/generated/app_localizations.dart';
import '../platform/links.dart';
import 'tessera_logo.dart';

/// The tessera user guide (English only).
final guideUrl = Uri.parse(
  'https://github.com/nagylzs/tessera/blob/main/docs/README.md',
);

/// Tessera Studio's own repository.
final sourceUrl = Uri.parse('https://github.com/nagylzs/tessera-studio');

/// Flutter's about dialog — name, version, logo, licence, and its "View
/// licenses" page, which lists every package's licence and the PDF
/// font's — with the "free forever" promise and two links.
Future<void> showAbout(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  final build = info.buildNumber;
  final links = GetIt.I<LinkOpener>();
  Widget link(IconData icon, String label, Uri uri) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: () => links.open(uri),
    ),
  );
  showAboutDialog(
    context: context,
    applicationName: l10n.appTitle,
    applicationVersion: build.isEmpty
        ? info.version
        : '${info.version} ($build)',
    applicationIcon: const SizedBox.square(dimension: 48, child: TesseraLogo()),
    applicationLegalese: l10n.aboutLegalese('2026', 'László Zsolt Nagy'),
    children: [
      const SizedBox(height: 16),
      Text(l10n.aboutFree),
      const SizedBox(height: 12),
      Text(l10n.aboutBuiltOn),
      const SizedBox(height: 4),
      link(Icons.menu_book_outlined, l10n.aboutGuide, guideUrl),
      link(Icons.code, l10n.aboutSource, sourceUrl),
    ],
  );
}
