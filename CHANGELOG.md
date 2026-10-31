# Changelog

## 1.1.0

The same version in every store. 1.0.0, the first release, came out in
each store as it was approved; Google Play, Linux and the portable
Windows build start with this one.

* Workbooks (`.xlsx`, `.ods`) open on the sheet they were saved on, as
  Excel and LibreOffice do, passing over hidden and empty sheets. With
  several sheets, the title shows the sheet's name with a ▾ that lists
  the others; each sheet keeps its own schema and pivot, and exports
  are named after the sheet.
* Computed dimensions: "Expression…" in the dimension picker groups or
  splits by a formula, e.g. `floor(year / 10) * 10` for decades or
  `rating >= 8`.
* A file opened while the schema page was up (Finder, Android's "Open
  with") kept the previous file's columns.
* Android: a file opened from another app (Telegram, Files) no longer
  leaves a second, empty copy of the app behind the launcher icon.
* Android: every file can be picked in the open dialog (`.tsnp` and
  `.jsonl` were greyed out); one of an unsupported type gets a clear
  message.
