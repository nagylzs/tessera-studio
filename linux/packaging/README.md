Tessera Studio for Linux
========================

Opens CSV, tab-separated, Excel (.xlsx), OpenDocument (.ods), JSON and
JSON Lines files as pivot tables, and saves them as Excel, OpenDocument,
PDF, HTML, SVG, CSV, JSON or a Tessera snapshot. Free and ad-free
forever: no account, no tracking, your files stay on your computer.

Run it from this folder, wherever you unpacked it:

    ./tessera_studio [file or URL]

To have it in your applications menu and under "Open with" for the files
it opens (for you only, no root needed):

    ./install.sh

Run `./install.sh` again after moving the folder, and
`./install.sh --uninstall` before deleting it. To update, unpack the new
version over this folder.

Needs a 64-bit desktop with GTK 3 and xdg-desktop-portal (with the GTK,
GNOME or KDE back end) for the open and save dialogs; every current
desktop has them.

Source, issues and the user guide: https://github.com/nagylzs/tessera-studio
MIT license (LICENSE); László Zsolt Nagy.
