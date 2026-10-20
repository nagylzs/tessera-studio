#!/bin/sh
# Packages the Linux release build for distribution:
#
#   flutter build linux --release
#   tool/linux_package.sh [x64|arm64]
#
# writes into build/linux/packages/
# - tessera-studio-<version>-linux-<arch>.tar.gz: the bundle in an
#   unversioned tessera-studio/ folder (unpacking an update over it keeps
#   the paths install.sh wrote), with share/ — the desktop entry, the
#   snapshot MIME type, the metainfo and the hicolor icons from
#   linux/packaging/ — install.sh, README.md and LICENSE;
# - tessera-studio_<version>_<amd64|arm64>.deb, where dpkg-deb and
#   dpkg-shlibdeps exist (CI's Ubuntu container): the bundle in
#   /usr/lib/tessera-studio, /usr/bin/tessera-studio a symlink to it (the
#   engine finds data/ through /proc/self/exe), the same share/ in
#   /usr/share, Depends from dpkg-shlibdeps; no maintainer scripts, as
#   dpkg triggers refresh the MIME, desktop and icon caches.
# Needs rsvg-convert (librsvg2-bin) for the PNG icons and GNU tar.
# Reproducible: file times are the last commit's (or $SOURCE_DATE_EPOCH),
# owners root.
set -eu

arch=${1:-x64}
case $arch in
  x64) debarch=amd64 ;;
  arm64) debarch=arm64 ;;
  *)
    echo "usage: $0 [x64|arm64]" >&2
    exit 64
    ;;
esac
cd "$(dirname "$0")/.."
id=eu.nagylzs.tessera_studio
version=$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' pubspec.yaml)
bundle=build/linux/$arch/release/bundle
out=build/linux/packages
stage=$out/stage/tessera-studio
src=linux/packaging

if [ ! -x "$bundle/tessera_studio" ]; then
  echo "linux_package.sh: no $bundle; flutter build linux --release first" >&2
  exit 1
fi
if ! grep -q "\"version\":\"$version\"" "$bundle/data/flutter_assets/version.json"; then
  echo "linux_package.sh: $bundle is not version $version; build it again" >&2
  exit 1
fi
# A release bundle copies build/flutter_assets, which debug builds (and
# flutter run) share and leave their 75 MB kernel_blob.bin in; the bundle
# folder itself keeps libraries no longer built. CI starts clean.
if [ -e "$bundle/data/flutter_assets/kernel_blob.bin" ]; then
  echo "linux_package.sh: $bundle has a debug build's kernel_blob.bin;" \
    "rm -rf build/flutter_assets $bundle and build again" >&2
  exit 1
fi
: "${SOURCE_DATE_EPOCH:=$(git log -1 --format=%ct)}"

rm -rf "$out/stage"
mkdir -p "$stage"
cp -a "$bundle/." "$stage/"
install -Dm644 "$src/$id.desktop" "$stage/share/applications/$id.desktop"
install -Dm644 "$src/$id.xml" "$stage/share/mime/packages/$id.xml"
install -Dm644 "$src/$id.metainfo.xml" "$stage/share/metainfo/$id.metainfo.xml"
icons=$stage/share/icons/hicolor
install -Dm644 "$src/$id.svg" "$icons/scalable/apps/$id.svg"
for size in 16 24 32 48 64 128 256 512; do
  mkdir -p "$icons/${size}x$size/apps"
  rsvg-convert -w "$size" -h "$size" "$src/$id.svg" \
    -o "$icons/${size}x$size/apps/$id.png"
done
install -m755 "$src/install.sh" "$stage/install.sh"
install -m644 "$src/README.md" "$stage/README.md"
install -m644 LICENSE "$stage/LICENSE"

tarball=$out/tessera-studio-$version-linux-$arch.tar.gz
tar --sort=name --owner=0 --group=0 --numeric-owner \
  --mtime="@$SOURCE_DATE_EPOCH" -C "$out/stage" -cf - tessera-studio |
  gzip -n -9 >"$tarball"
echo "wrote $tarball"

if ! command -v dpkg-deb >/dev/null || ! command -v dpkg-shlibdeps >/dev/null; then
  echo "no dpkg-deb or dpkg-shlibdeps: no .deb"
  exit 0
fi
root=$out/stage/deb
app=$root/usr/lib/tessera-studio
mkdir -p "$app" "$root/usr/bin" "$root/DEBIAN"
cp -a "$bundle/." "$app/"
cp -a "$stage/share" "$root/usr/share"
ln -s ../lib/tessera-studio/tessera_studio "$root/usr/bin/tessera-studio"
doc=$root/usr/share/doc/tessera-studio
mkdir -p "$doc"
{
  echo "Tessera Studio, https://github.com/nagylzs/tessera-studio"
  echo
  cat LICENSE
} >"$doc/copyright"
chmod -R u=rwX,go=rX "$root"
chmod 755 "$app/tessera_studio"

# dpkg-shlibdeps wants a source package around it. The plugins and the
# engine are ours (in this package); libapp is the AOT snapshot and links
# nothing; libdartjni, which jni builds only where a JDK is installed, is
# its Android-only library, never loaded on Linux, and needs a libjvm no
# package has.
work=$out/stage/shlibs
mkdir -p "$work/debian"
printf 'Source: tessera-studio\n\nPackage: tessera-studio\nArchitecture: any\n' \
  >"$work/debian/control"
abs=$(pwd)
depends=$(cd "$work" && dpkg-shlibdeps -O --ignore-missing-info \
  -l"$abs/$app/lib" \
  "$abs/$app/tessera_studio" \
  "$abs/$app/lib/libflutter_linux_gtk.so" \
  "$abs/$app/lib/libdesktop_drop_plugin.so" \
  "$abs/$app/lib/liburl_launcher_linux_plugin.so" |
  sed -n 's/^shlibs:Depends=//p')
# Apparent sizes: a compressing filesystem (ZFS, btrfs) shrinks blocks.
size=$(du -sk --apparent-size --exclude=DEBIAN "$root" | cut -f1)
sed -e '/^#/d' -e "s/@VERSION@/$version/" -e "s/@ARCH@/$debarch/" \
  -e "s/@SIZE@/$size/" -e "s/@DEPENDS@/$depends/" \
  "$src/control.in" >"$root/DEBIAN/control"
find "$root" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
deb=$out/tessera-studio_${version}_$debarch.deb
dpkg-deb --root-owner-group -Zxz --build "$root" "$deb" >/dev/null
echo "wrote $deb"
