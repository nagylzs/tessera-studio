#!/bin/sh
# Tessera Studio: adds the app to your applications menu and to "Open
# with" for the files it opens (CSV, TSV, JSON, Excel, OpenDocument,
# Tessera snapshots). For you only: no root, nothing outside your home.
#
#   ./install.sh              from the unpacked folder, wherever you keep it
#   ./install.sh --uninstall  removes what install.sh added
#
# The app stays in this folder; run install.sh again after moving it.
# Your default apps are left alone: Tessera Studio becomes one of the
# choices under "Open with", and the default only for its own snapshots.
set -eu

id=eu.nagylzs.tessera_studio
here=$(cd "$(dirname "$0")" && pwd -P)
data=${XDG_DATA_HOME:-$HOME/.local/share}
icons=$data/icons/hicolor
bin=$HOME/.local/bin
link=$bin/tessera-studio

# Lets the desktop see the change: the MIME and desktop-file caches,
# and the icon theme (GTK rescans a directory without a cache, so only
# a cache that exists is refreshed; a stale one would hide the icon).
refresh() {
  if [ -d "$data/mime" ] && command -v update-mime-database >/dev/null; then
    update-mime-database "$data/mime" || true
  fi
  if [ -d "$data/applications" ] &&
    command -v update-desktop-database >/dev/null; then
    update-desktop-database "$data/applications" || true
  fi
  if [ -d "$icons" ]; then
    touch "$icons"
    if [ -f "$icons/icon-theme.cache" ] &&
      command -v gtk-update-icon-cache >/dev/null; then
      gtk-update-icon-cache -f -t "$icons" >/dev/null 2>&1 || true
    fi
  fi
}

# Whether $link is a symlink this script made (to a tessera_studio).
own_link() {
  [ -L "$link" ] && case $(readlink "$link") in
    */tessera_studio) true ;;
    *) false ;;
  esac
}

install() {
  exe=$here/tessera_studio
  if [ ! -x "$exe" ]; then
    echo "install.sh: no tessera_studio next to install.sh" >&2
    exit 1
  fi
  case $exe in
    *'
'*)
      echo "install.sh: the folder's path has a line break in it" >&2
      exit 1
      ;;
  esac

  # Exec quotes the path (backslash before " ` $ \), then escapes it as
  # a desktop-entry string (every backslash doubled) and % as %%;
  # TryExec is a plain string. Both are spelled out in the Desktop Entry
  # Specification, "The Exec key".
  q=$(printf '%s\n' "$exe" |
    sed -e 's/[\\"`$]/\\&/g' -e 's/\\/\\\\/g' -e 's/%/%%/g')
  t=$(printf '%s\n' "$exe" | sed -e 's/\\/\\\\/g')
  mkdir -p "$data/applications" "$data/mime/packages"
  desktop=$data/applications/$id.desktop
  EXEC="Exec=\"$q\" %f" TRYEXEC="TryExec=$t" awk '
    /^Exec=/ { print ENVIRON["TRYEXEC"]; print ENVIRON["EXEC"]; next }
    { print }
  ' "$here/share/applications/$id.desktop" >"$desktop.new"
  mv "$desktop.new" "$desktop"

  cp "$here/share/mime/packages/$id.xml" "$data/mime/packages/$id.xml"
  (
    cd "$here/share/icons/hicolor"
    for f in */apps/"$id".*; do
      mkdir -p "$icons/${f%/*}"
      cp "$f" "$icons/$f"
    done
  )

  mkdir -p "$bin"
  if [ -e "$link" ] && ! own_link; then
    echo "install.sh: $link exists and is not ours; left as it is" >&2
  else
    ln -sfn "$exe" "$link"
  fi

  refresh
  echo "Tessera Studio is in your applications menu and under \"Open with\"."
  echo "It runs from $here; run install.sh again if you move that folder."
  case ":$PATH:" in
    *":$bin:"*) echo "From a terminal: tessera-studio [file or URL]" ;;
    *) echo "From a terminal: $link [file or URL] ($bin is not on your PATH)" ;;
  esac
}

uninstall() {
  rm -f "$data/applications/$id.desktop" "$data/mime/packages/$id.xml"
  for f in "$icons"/*/apps/"$id".png "$icons"/*/apps/"$id".svg; do
    if [ -e "$f" ]; then rm -f "$f"; fi
  done
  if own_link; then rm -f "$link"; fi
  refresh
  echo "Tessera Studio is no longer in your applications menu."
  echo "The app is still in $here; delete that folder to remove it."
  echo "Your settings and saved pivots: $data/$id"
}

case ${1-} in
  '') install ;;
  --uninstall) uninstall ;;
  *)
    echo "usage: $0 [--uninstall]" >&2
    exit 64
    ;;
esac
