// Writes the Linux desktop integration files into linux/packaging/ from
// the texts the app already has in every language:
//
//   dart run tool/linux_metadata.dart
//
// - eu.nagylzs.tessera_studio.desktop — the menu entry: GenericName the
//   app's own term for a pivot table (exportPivot in the ARB files; the
//   App Store name is English everywhere), Comment from the App Store
//   subtitle, Keywords from the App Store keywords
//   (store/listing/<lang>.yaml);
// - eu.nagylzs.tessera_studio.xml — the shared-mime-info type of the
//   Tessera snapshot (*.tsnp, "TSNP" magic), named as the app names it
//   (formatSnapshot in lib/l10n/app_<lang>.arb);
// - eu.nagylzs.tessera_studio.metainfo.xml — the AppStream component for
//   software centres: the subtitle, the Microsoft Store summary and
//   feature list (written for a desktop), the desktop screenshots at the
//   tag of the pubspec's version, and [releases];
// - control.in — the .deb's control file, in English (Debian has no
//   translated control fields), for tool/linux_package.sh to fill in:
//   @VERSION@, @ARCH@, @SIZE@ and @DEPENDS@ (from dpkg-shlibdeps).
//
// Run it again after changing any of those; test/linux_metadata_test.dart
// fails while the committed files differ from what it writes.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// The application id: GTK's (linux/CMakeLists.txt), the desktop file's
/// and every exported file's name.
const appId = 'eu.nagylzs.tessera_studio';

/// The command on the PATH (the .deb's /usr/bin symlink, the tarball's
/// ~/.local/bin one).
const command = 'tessera-studio';

const _repository = 'https://github.com/nagylzs/tessera-studio';
const _guide = 'https://github.com/nagylzs/tessera/blob/main/docs/README.md';
const _developer = 'László Zsolt Nagy';

/// The media types the app opens. Not text/plain (it would claim every
/// text file) and not JSON Lines (shared-mime-info has no type for it).
const mimeTypes = [
  'text/csv',
  'text/tab-separated-values',
  'application/json',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.oasis.opendocument.spreadsheet',
  snapshotType,
];

const snapshotType = 'application/vnd.tessera.snapshot';

/// Released versions, newest first, with their dates (AppStream insists
/// on one): add the new version on its release day, before the tag, as
/// `('1.0.0', '2026-11-10')`. Without any, the metainfo has no releases.
const releases = <(String, String)>[];

/// The files this tool writes, by path from the project root.
Map<String, String> linuxMetadataFiles() {
  final meta = LinuxMetadata.load();
  return {
    'linux/packaging/$appId.desktop': meta.desktopEntry(),
    'linux/packaging/$appId.xml': meta.mimeInfo(),
    'linux/packaging/$appId.metainfo.xml': meta.metainfo(),
    'linux/packaging/control.in': meta.debianControl(),
  };
}

void main() {
  for (final MapEntry(key: path, value: content)
      in linuxMetadataFiles().entries) {
    File(path).writeAsStringSync(content);
    stdout.writeln('wrote $path');
  }
}

class LinuxMetadata {
  LinuxMetadata({
    required this.listings,
    required this.snapshotNames,
    required this.pivotNames,
    required this.version,
    required this.screenshots,
  });

  /// Reads the inputs from the project root (the working directory).
  factory LinuxMetadata.load() {
    final listings = <String, YamlMap>{};
    final snapshotNames = <String, String>{};
    final pivotNames = <String, String>{};
    for (final f in Directory('lib/l10n').listSync().whereType<File>()) {
      final match = RegExp(r'app_(\w+)\.arb$').firstMatch(f.path);
      if (match == null) continue;
      final lang = match[1]!;
      final arb = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      snapshotNames[lang] = arb['formatSnapshot'] as String;
      pivotNames[lang] = arb['exportPivot'] as String;
      final listing = File('store/listing/$lang.yaml');
      listings[lang] = loadYaml(listing.readAsStringSync()) as YamlMap;
    }
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final shots =
        Directory('store/screenshots/desktop')
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('.png'))
            .toList()
          ..sort();
    return LinuxMetadata(
      listings: listings,
      snapshotNames: snapshotNames,
      pivotNames: pivotNames,
      version: (pubspec['version'] as String).split('+').first,
      screenshots: shots,
    );
  }

  /// `store/listing/<lang>.yaml` by language code.
  final Map<String, YamlMap> listings;

  /// formatSnapshot by language code.
  final Map<String, String> snapshotNames;

  /// exportPivot ("Pivot table") by language code.
  final Map<String, String> pivotNames;

  /// The pubspec's version without the build number.
  final String version;

  /// File names in store/screenshots/desktop, in order.
  final List<String> screenshots;

  /// English first (the untranslated value), then the others by code.
  /// The bare codes, as the app resolves them: `pt` is Brazilian and
  /// `zh` Simplified for every region, like the app's own strings.
  List<String> get _languages => [
    'en',
    ...(listings.keys.where((l) => l != 'en').toList()..sort()),
  ];

  String _field(String lang, String key) =>
      (listings[lang]![key] as String).trim();

  List<String> _keywords(String lang) => _field(lang, 'keywords').split(',');

  String desktopEntry() {
    final out = StringBuffer()
      ..writeln('# Generated by tool/linux_metadata.dart from')
      ..writeln('# store/listing/*.yaml and lib/l10n/app_*.arb: edit those')
      ..writeln('# and run it again.')
      ..writeln('[Desktop Entry]')
      ..writeln('Type=Application')
      // 1.4, not the current 1.5: the desktop-file-validate of Ubuntu
      // 22.04 and Debian 12 rejects a version it does not know, and
      // nothing here needs 1.5.
      ..writeln('Version=1.4')
      ..writeln('Name=Tessera Studio');
    void localized(String key, String Function(String lang) value) {
      for (final lang in _languages) {
        final suffix = lang == 'en' ? '' : '[$lang]';
        out.writeln('$key$suffix=${value(lang)}');
      }
    }

    localized('GenericName', (l) => _desktopString(pivotNames[l]!));
    localized('Comment', (l) => _desktopString(_field(l, 'subtitle')));
    localized(
      'Keywords',
      (l) =>
          _keywords(l).map((k) => '${_desktopString(k, list: true)};').join(),
    );
    out
      ..writeln('Icon=$appId')
      ..writeln('Exec=$command %f')
      ..writeln('Terminal=false')
      ..writeln('Categories=Office;Spreadsheet;Viewer;')
      ..writeln('MimeType=${mimeTypes.map((t) => '$t;').join()}')
      ..writeln('StartupNotify=true')
      ..writeln('StartupWMClass=$appId');
    return out.toString();
  }

  String mimeInfo() {
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<!-- Generated by tool/linux_metadata.dart from')
      ..writeln('     lib/l10n/app_*.arb: edit those and run it again. -->')
      ..writeln(
        '<mime-info '
        'xmlns="http://www.freedesktop.org/standards/shared-mime-info">',
      )
      ..writeln('  <mime-type type="$snapshotType">');
    for (final lang in _languages) {
      out.writeln(
        '    <comment${_xmlLang(lang)}>'
        '${_xml(snapshotNames[lang]!)}</comment>',
      );
    }
    out
      ..writeln('    <generic-icon name="x-office-spreadsheet"/>')
      // TesseraSnapshot.magic: the first four bytes of every snapshot.
      ..writeln('    <magic priority="60">')
      ..writeln('      <match type="string" offset="0" value="TSNP"/>')
      ..writeln('    </magic>')
      ..writeln('    <glob pattern="*.tsnp"/>')
      ..writeln('  </mime-type>')
      ..writeln('</mime-info>');
    return out.toString();
  }

  /// The binary package's control file. The synopsis is the subtitle
  /// (Debian's wants no package name and no full stop), the long
  /// description the Microsoft Store summary, wrapped.
  String debianControl() {
    final out = StringBuffer()
      ..writeln('Package: $command')
      ..writeln('Version: @VERSION@')
      ..writeln('Architecture: @ARCH@')
      ..writeln('Maintainer: $_developer <apps@nagylzs.eu>')
      ..writeln('Installed-Size: @SIZE@')
      // The engine loads EGL and GLES through libepoxy at run time,
      // which dpkg-shlibdeps cannot see; without them it does not start.
      ..writeln('Depends: @DEPENDS@, libegl1, libgles2')
      // file_picker talks to the FileChooser portal directly, with no
      // fallback: without it "Open file…" and "Save as…" fail.
      ..writeln(
        'Recommends: xdg-desktop-portal, '
        'xdg-desktop-portal-gtk | xdg-desktop-portal-backend',
      )
      ..writeln('Section: utils')
      ..writeln('Priority: optional')
      ..writeln('Homepage: $_repository')
      ..writeln('Description: ${_field('en', 'subtitle')}');
    for (final line in _wrap(_field('en', 'summary'), 72)) {
      out.writeln(' $line');
    }
    return out.toString();
  }

  String metainfo() {
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<!-- Generated by tool/linux_metadata.dart from')
      ..writeln('     store/listing/*.yaml and pubspec.yaml: edit those and')
      ..writeln('     run it again. -->')
      ..writeln('<component type="desktop-application">')
      ..writeln('  <id>$appId</id>')
      ..writeln('  <metadata_license>MIT</metadata_license>')
      ..writeln('  <project_license>MIT</project_license>')
      ..writeln('  <name>Tessera Studio</name>');
    void localized(String indent, String tag, String Function(String) text) {
      for (final lang in _languages) {
        out.writeln('$indent<$tag${_xmlLang(lang)}>${_xml(text(lang))}</$tag>');
      }
    }

    localized('  ', 'summary', (l) => _field(l, 'subtitle'));
    out
      ..writeln('  <developer id="eu.nagylzs">')
      ..writeln('    <name>$_developer</name>')
      ..writeln('  </developer>')
      ..writeln('  <description>');
    localized('    ', 'p', (l) => _field(l, 'summary').replaceAll('\n', ' '));
    out.writeln('    <ul>');
    for (final lang in _languages) {
      for (final f
          in (listings[lang]!['features'] as YamlList).cast<String>()) {
        out.writeln('      <li${_xmlLang(lang)}>${_xml(f.trim())}</li>');
      }
    }
    out
      ..writeln('    </ul>')
      ..writeln('  </description>')
      ..writeln('  <launchable type="desktop-id">$appId.desktop</launchable>')
      ..writeln('  <url type="homepage">$_repository</url>')
      // No vcs-browser: the homepage is the repository, and Ubuntu 22.04's
      // AppStream 0.15 does not know the type.
      ..writeln('  <url type="bugtracker">$_repository/issues</url>')
      ..writeln('  <url type="help">$_guide</url>')
      ..writeln('  <screenshots>');
    final raw = 'https://raw.githubusercontent.com/nagylzs/tessera-studio';
    for (final (i, name) in screenshots.indexed) {
      out
        ..writeln(
          i == 0 ? '    <screenshot type="default">' : '    <screenshot>',
        )
        ..writeln(
          '      <image>$raw/v$version/store/screenshots/desktop/$name</image>',
        )
        ..writeln('    </screenshot>');
    }
    out
      ..writeln('  </screenshots>')
      ..writeln('  <keywords>');
    for (final lang in _languages) {
      for (final k in _keywords(lang)) {
        out.writeln('    <keyword${_xmlLang(lang)}>${_xml(k)}</keyword>');
      }
    }
    out
      ..writeln('  </keywords>')
      ..writeln('  <provides>')
      ..writeln('    <binary>$command</binary>');
    for (final t in mimeTypes) {
      out.writeln('    <mediatype>$t</mediatype>');
    }
    out
      ..writeln('  </provides>')
      ..writeln('  <supports>')
      ..writeln('    <control>pointing</control>')
      ..writeln('    <control>keyboard</control>')
      ..writeln('    <control>touch</control>')
      ..writeln('  </supports>')
      ..writeln('  <branding>')
      ..writeln(
        '    <color type="primary" scheme_preference="light">#f2f9f6</color>',
      )
      ..writeln(
        '    <color type="primary" scheme_preference="dark">#00856e</color>',
      )
      ..writeln('  </branding>')
      ..writeln('  <content_rating type="oars-1.1"/>');
    if (releases.isNotEmpty) {
      out.writeln('  <releases>');
      for (final (v, date) in releases) {
        out.writeln('    <release version="$v" date="$date"/>');
      }
      out.writeln('  </releases>');
    }
    out.writeln('</component>');
    return out.toString();
  }
}

/// [text] in lines of at most [width] characters, broken at spaces.
List<String> _wrap(String text, int width) {
  final lines = <String>[];
  var line = '';
  for (final word in text.split(RegExp(r'\s+'))) {
    if (line.isNotEmpty && line.length + 1 + word.length > width) {
      lines.add(line);
      line = word;
    } else {
      line = line.isEmpty ? word : '$line $word';
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines;
}

/// A desktop-entry string value: backslash, newline, tab and CR escaped,
/// and in a list (Keywords) the separator too.
String _desktopString(String s, {bool list = false}) {
  var v = s
      .replaceAll(r'\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t')
      .replaceAll('\r', r'\r');
  if (list) v = v.replaceAll(';', r'\;');
  return v;
}

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _xmlLang(String lang) => lang == 'en' ? '' : ' xml:lang="$lang"';
