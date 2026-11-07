import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

/// The fonts a PDF is written with, as package:pdf reads them.
TtfParser _font(String face) => TtfParser(
  File('assets/fonts/NotoSans-$face.ttf').readAsBytesSync().buffer.asByteData(),
);

void main() {
  for (final face in ['Regular', 'Bold']) {
    group('NotoSans-$face', () {
      // package:pdf embeds the next glyph's outline for an empty one, all but
      // the plain space's: "1¡771¡020" in Hungarian, found on 2026-11-07.
      test('no character but the space has an empty glyph', () {
        final font = _font(face);
        final empty = [
          for (final MapEntry(key: rune, value: glyph)
              in font.charToGlyphIndexMap.entries)
            if (rune != 0x20 && font.glyphSizes[glyph] == 0)
              rune.toRadixString(16),
        ];
        expect(empty, isEmpty);
      });

      test('the other spaces draw nothing, and keep their width', () {
        final font = _font(face);
        // the separators of thousands in the pivot, the compact numbers of
        // the axes, and a narrow one that intl uses in some languages
        for (final (rune, width) in [
          (0xA0, 260),
          (0x2009, 166),
          (0x202F, 166),
        ]) {
          final glyph = font.charToGlyphIndexMap[rune]!;
          final outline = font.readGlyph(glyph).data;
          final header = outline.buffer.asByteData(outline.offsetInBytes);
          expect(header.getInt16(0), 1, reason: 'one contour');
          expect(header.getInt16(6), header.getInt16(2), reason: 'no width');
          expect(header.getInt16(8), header.getInt16(4), reason: 'no height');
          expect(
            font.glyphInfoMap[glyph]!.advanceWidth * font.unitsPerEm,
            closeTo(width, 0.5),
          );
        }
      });
    });
  }
}
