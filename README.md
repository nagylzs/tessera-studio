# Tessera Studio

Pivot tables from CSV, Excel, ODS and JSON files, with charts and
XLSX / ODS / HTML / SVG / PDF export. Built on the
[tessera](https://github.com/nagylzs/tessera) engine and widgets.

Targets: Android, web, Windows and Linux.

## Development

```bash
flutter pub get
flutter run -d linux        # or -d chrome, -d windows, an Android device
flutter test
```

To work on the tessera packages and the app at the same time, point the
app at a local checkout with a `pubspec_overrides.yaml` (ignored by
git):

```yaml
dependency_overrides:
  tessera:
    path: ../tessera/packages/tessera
  tessera_flutter:
    path: ../tessera/packages/tessera_flutter
```

The committed `pubspec.yaml` always depends on the published versions.

## License

MIT — see [LICENSE](LICENSE). Author: László Zsolt Nagy.
