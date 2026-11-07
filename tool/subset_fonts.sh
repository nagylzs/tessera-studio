#!/bin/sh
# Subsets Noto Sans for the PDF export: Latin with its extensions
# (Hungarian ő/ű live in Extended-A, Vietnamese in Extended Additional),
# combining marks, Greek, Cyrillic, general punctuation (… – — quotes),
# currency, letterlike symbols, arrows and the minus sign. Needs fonttools
# (`pyftsubset`). Source: the full fonts from the system or a download;
# their licence (SIL OFL 1.1) is assets/fonts/OFL.txt.
#
# Every empty glyph a character maps to then gets a single point, which draws
# nothing, except the plain space's. package:pdf (3.13) takes an empty glyph's
# offset for the start of its outline and so embeds the next glyph's: the
# no-break space, tessera's thousands separator in five languages, printed as
# "¡" (test/pdf_fonts_test.dart).
#
#   tool/subset_fonts.sh [source directory]   (default /usr/share/fonts/noto)
set -e
src=${1:-/usr/share/fonts/noto}
dst=$(dirname "$0")/../assets/fonts
for face in Regular Bold; do
  font="$dst/NotoSans-$face.ttf"
  pyftsubset "$src/NotoSans-$face.ttf" \
    --unicodes="U+0000-036F,U+0370-03FF,U+0400-052F,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-2199,U+2212" \
    --layout-features='*' --no-hinting --desubroutinize \
    --output-file="$font"
  python3 - "$font" <<'EOF'
import sys
from array import array

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph, GlyphCoordinates, flagOnCurve
from fontTools.ttLib.tables.ttProgram import Program

font = TTFont(sys.argv[1])
glyf = font["glyf"]
for rune, name in font.getBestCmap().items():
    if rune != 0x20 and glyf[name].numberOfContours == 0:
        point = Glyph()
        point.numberOfContours = 1
        point.endPtsOfContours = [0]
        point.coordinates = GlyphCoordinates([(0, 0)])
        point.flags = array("B", [flagOnCurve])
        point.program = Program()
        point.program.fromBytecode(b"")
        point.recalcBounds(glyf)
        glyf[name] = point
font.save(sys.argv[1])
EOF
  ls -l "$font"
done
