#!/bin/sh
# Subsets Noto Sans for the PDF export: Latin with its extensions
# (Hungarian ő/ű live in Extended-A, Vietnamese in Extended Additional),
# combining marks, Greek, Cyrillic, general punctuation (… – — quotes),
# currency, letterlike symbols, arrows and the minus sign. Needs fonttools
# (`pyftsubset`). Source: the full fonts from the system or a download;
# their licence (SIL OFL 1.1) is assets/fonts/OFL.txt.
#
#   tool/subset_fonts.sh [source directory]   (default /usr/share/fonts/noto)
set -e
src=${1:-/usr/share/fonts/noto}
dst=$(dirname "$0")/../assets/fonts
for face in Regular Bold; do
  pyftsubset "$src/NotoSans-$face.ttf" \
    --unicodes="U+0000-036F,U+0370-03FF,U+0400-052F,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-2199,U+2212" \
    --layout-features='*' --no-hinting --desubroutinize \
    --output-file="$dst/NotoSans-$face.ttf"
  ls -l "$dst/NotoSans-$face.ttf"
done
