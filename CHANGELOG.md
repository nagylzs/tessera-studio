# Changelog

## Unreleased

* Charts: the chart button shows the pivot as bars, stacked bars, a line, a
  pie or a scatter chart, and follows it live. It can also break the current
  cell down by another column. Beside the grid on a desktop or a tablet in
  landscape, above it on a tablet in portrait, in its place on a phone. On
  any of them a button lets it fill the window, and Esc or back returns.
  Remembered per file structure.
* A chart of all the data can be broken down by columns of its own, whatever
  the pivot shows: revenue by month beside a pivot of regions ("All data" in
  the chart's source menu).
* A scatter chart of all the data or of the current cell can show single
  records, a dot each, two of their number columns against each other
  ("Single records" under "Break down by"). Beyond 5,000 records it shows
  5,000 taken at even steps, and says so.
* A pie names a slice's group, value and share when it is tapped, or while
  the pointer rests on it; a tap on its legend entry does the same, for
  slices too thin to hit. A second tap hides it.
* Export: a showing chart saves or shares as a PNG, an SVG or a PDF, light or
  dark, with its background or on a transparent one.
* The export dialog asks first what to export (the chart, the pivot table or
  the facts), then lists only that one's formats, instead of every format of
  all of them in one long list.
* On a Mac, Share sits beside Save as…: the system's share menu, which gives
  Mail, Messages or AirDrop the file.
* The grid style dialog is as wide as its descriptions need, so they stay on
  one line at a larger text size where the window has room.
* A tap anywhere in a group's cell, its name included, expands or collapses
  it; the small +/− was hard to hit on a phone (tessera_flutter 0.2.7). The
  grand total still folds everything only through its −.
* Excel and OpenDocument pivot exports show whole numbers, such as counts,
  without decimals ("1 014", not "1 014,00"), as the grid and the PDF do
  (tessera_xlsx and tessera_ods 0.2.4).

## 1.2.1

* PDF exports: in Czech, French, Hungarian, Polish and Russian the space
  between the thousands of a number printed as "¡" ("1¡771¡020"). It is a
  space again.

## 1.2.0

* Help for expressions: the ? at the end of every expression field
  (filter, calculated measure, computed dimension, cell formula) opens
  a reference that works offline and in the app's language — examples
  written with the file's own columns, the columns, operators, how to
  write values, what happens to empty values, and every function. A
  tap on an example, a column or a function puts it in the field at
  the cursor.
* On a phone in landscape the filter takes the whole screen, with Clear
  and Apply at the top: with the keyboard up, the dialog left its rows
  no room. The expression form of "Add dimension" keeps its field above
  the keyboard there.
* Rotating the phone with an expression form open in "Add dimension" or
  "Add aggregate" no longer empties its label field.

## 1.1.0

The same version in every store but Google Play, whose first public
release is 1.2.1. 1.0.0, the first release, came out in each store as it
was approved; Linux and the portable Windows build start with this one.

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
