import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_studio/l10n/generated/app_localizations.dart';
import 'package:tessera_studio/style/style_gallery.dart';

import 'fakes.dart';

/// WCAG's relative luminance of an ARGB colour (alpha ignored).
double _luminance(int argb) {
  double channel(int shift) {
    final c = ((argb >> shift) & 0xFF) / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// WCAG's contrast ratio of two colours, from 1 to 21.
double contrast(int a, int b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [over] laid on [under], for the translucent ones (`#AARRGGBB`).
int _over(int over, int under) {
  final a = ((over >> 24) & 0xFF) / 255;
  int channel(int shift) =>
      (((over >> shift) & 0xFF) * a + ((under >> shift) & 0xFF) * (1 - a))
          .round();
  return 0xFF000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
}

void main() {
  final gallery = testGallery();

  test('the gallery: 20 to 30 styles, unique ids, the six of before', () {
    expect(gallery.styles.length, inInclusiveRange(20, 30));
    final ids = [for (final s in gallery.styles) s.id];
    expect(ids.toSet(), hasLength(ids.length));
    // the stored choices of the styles before the gallery still hold
    expect(
      ids,
      containsAll([
        'standard',
        'spreadsheet',
        'gradient',
        'hueLevels',
        'highContrast',
        'compact',
      ]),
    );
    expect(ids.first, defaultStyleId);
    expect(gallery.byId('gone').id, defaultStyleId);
  });

  test('every style is named in every language of the app', () {
    for (final style in gallery.styles.cast<JsonCubeStyle>()) {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(
          style.names[locale.languageCode],
          isNotNull,
          reason: '${style.id} in ${locale.languageCode}',
        );
      }
    }
  });

  test('text is readable on its fill everywhere, light and dark', () {
    const roles = CellRole.values;
    final problems = <String>[];
    for (final style in gallery.styles) {
      for (final dark in [false, if (style.hasDark) true]) {
        final chrome = style.chrome(dark: dark);
        for (final role in roles) {
          for (var depth = 0; depth < 4; depth++) {
            final cell = switch (role) {
              CellRole.value => StyleCell(
                role,
                rowLevel: depth,
                columnLevel: 0,
              ),
              CellRole.rowLabel => StyleCell(role, rowLevel: depth),
              CellRole.title => StyleCell(role, rowLevel: depth),
              CellRole.columnLabel ||
              CellRole.valueName => StyleCell(role, columnLevel: depth),
              _ => StyleCell(role),
            };
            final look = style.lookOf(cell, dark: dark);
            // WCAG AA: 4.5 for text, 3 for large or bold text
            final large = look.bold || look.size >= 18;
            final need = large ? 3.0 : 4.5;
            final ratio = contrast(look.fill, look.text);
            if (ratio < need) {
              problems.add(
                '${style.id}${dark ? ' dark' : ''} ${role.name} $depth: '
                '${ratio.toStringAsFixed(2)} < $need',
              );
            }
            // the expand and sort icons on the headers
            if (role != CellRole.value && role != CellRole.total) {
              final icon = chrome.icon ?? look.text;
              final iconRatio = contrast(look.fill, _over(icon, look.fill));
              if (iconRatio < 3) {
                problems.add(
                  '${style.id}${dark ? ' dark' : ''} ${role.name} $depth '
                  'icon: ${iconRatio.toStringAsFixed(2)} < 3',
                );
              }
            }
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
