#!/bin/sh
# Installs what tool/linux_package.sh made into a fresh Debian or Ubuntu
# container and checks it the way a desktop uses it, on a virtual display:
#
#   tool/linux_smoke_test.sh [build/linux/packages]
#
# As root in a throwaway container only (CI's "Linux test" job, or
# `podman run` locally): it apt-installs the test tools and the .deb.
# - The tarball: install.sh writes the menu entry, the snapshot type and
#   the ~/.local/bin link; the app opens a snapshot through that link;
#   install.sh --uninstall removes them again.
# - The .deb: installed with its Depends from the archive (proof they are
#   complete); the desktop entry and the metainfo validate; GIO knows the
#   types (the snapshot also by its magic, without the extension) and
#   offers the app for them; `gio open` on a snapshot (the default
#   handler) and `gio launch` of the entry on a CSV (what "Open with"
#   does) both start it on the file. Window title and class are checked.
# Screenshots and logs: build/linux/smoke/.
set -eu

id=eu.nagylzs.tessera_studio
demo=store/screenshots/demo
shots=build/linux/smoke

# One launch: waits for the window, screenshots it after the file has
# loaded, checks it is still running and stops it.
launch() {
  name=$1
  shift
  "$@" >"$shots/$name.log" 2>&1 &
  win=$(timeout 90 xdotool search --sync --onlyvisible --class "$id" | head -1)
  if [ -z "$win" ]; then
    echo "$name: no window after 90 s"
    cat "$shots/$name.log"
    exit 1
  fi
  sleep 10
  import -window root "$shots/$name.png"
  title=$(xprop -id "$win" _NET_WM_NAME)
  echo "$name: $title"
  case $title in
    *'"Tessera Studio"') ;;
    *)
      echo "$name: the window is not titled Tessera Studio"
      exit 1
      ;;
  esac
  if ! pgrep -x 'tessera[-_]studio' >/dev/null; then
    echo "$name: the app has exited"
    cat "$shots/$name.log"
    exit 1
  fi
  pkill -x 'tessera[-_]studio'
  timeout 20 sh -c 'while pgrep -x 'tessera[-_]studio' >/dev/null; do sleep 1; done'
}

# What GIO, which file managers use, thinks of a file and a type.
content_type() {
  gio info -a standard::content-type "$1" | sed -n 's/.*content-type: //p'
}

expect_type() {
  actual=$(content_type "$1")
  echo "$1: $actual"
  if [ "$actual" != "$2" ]; then
    echo "expected $2"
    exit 1
  fi
}

offered_for() {
  gio mime "$1" | grep -q "$id.desktop" || {
    echo "not offered for $1:"
    gio mime "$1"
    exit 1
  }
  echo "offered for $1"
}

# Inside xvfb-run and dbus-run-session.
session() {
  pkgs=$1
  export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
  mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
  export LIBGL_ALWAYS_SOFTWARE=1
  files=$HOME/Documents
  mkdir -p "$files"
  cp "$demo/sales.csv" "$demo/Sales 2025.tsnp" "$files/"
  cp "$files/Sales 2025.tsnp" "$files/snapshot-without-extension"

  echo "== tarball"
  mkdir -p "$HOME/apps"
  tar -xzf "$pkgs"/tessera-studio-*-linux-*.tar.gz -C "$HOME/apps"
  "$HOME/apps/tessera-studio/install.sh"
  entry=$HOME/.local/share/applications/$id.desktop
  grep -E '^(TryExec|Exec)=' "$entry"
  desktop-file-validate "$entry"
  expect_type "$files/Sales 2025.tsnp" application/vnd.tessera.snapshot
  offered_for application/vnd.tessera.snapshot
  launch tarball-link "$HOME/.local/bin/tessera-studio" "$files/Sales 2025.tsnp"
  "$HOME/apps/tessera-studio/install.sh" --uninstall
  for f in "$entry" "$HOME/.local/share/mime/packages/$id.xml" \
    "$HOME/.local/bin/tessera-studio"; do
    if [ -e "$f" ] || [ -L "$f" ]; then
      echo "--uninstall left $f"
      exit 1
    fi
  done

  echo "== .deb"
  dpkg -s tessera-studio | grep -E '^(Version|Architecture|Depends|Recommends):'
  desktop-file-validate "/usr/share/applications/$id.desktop"
  appstreamcli validate --no-net "/usr/share/metainfo/$id.metainfo.xml"
  expect_type "$files/sales.csv" text/csv
  expect_type "$files/Sales 2025.tsnp" application/vnd.tessera.snapshot
  expect_type "$files/snapshot-without-extension" application/vnd.tessera.snapshot
  for t in text/csv text/tab-separated-values application/json \
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet \
    application/vnd.oasis.opendocument.spreadsheet \
    application/vnd.tessera.snapshot; do
    offered_for "$t"
  done
  gio mime application/vnd.tessera.snapshot | grep -q "^Default application.*$id.desktop" || {
    echo "not the default for snapshots"
    exit 1
  }
  launch deb-open-snapshot gio open "$files/Sales 2025.tsnp"
  launch deb-open-with-csv gio launch "/usr/share/applications/$id.desktop" "$files/sales.csv"
  echo "== all good"
}

if [ "${1-}" = --session ]; then
  session "$2"
  exit
fi

pkgs=$(cd "${1:-build/linux/packages}" && pwd)
mkdir -p "$shots"
export DEBIAN_FRONTEND=noninteractive
apt-get update
# The test tools only; what the app needs comes with the .deb's Depends
# (and Recommends: the portal).
apt-get install -y --no-install-recommends ca-certificates xvfb xauth dbus \
  libglib2.0-bin xdotool x11-utils imagemagick procps desktop-file-utils \
  appstream libgl1-mesa-dri
apt-get install -y "$(ls "$pkgs"/tessera-studio_*.deb)"
xvfb-run -a -s '-screen 0 1600x1000x24' \
  dbus-run-session -- sh "$0" --session "$pkgs"
