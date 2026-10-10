// Demo data for the store screenshots, the same on every platform:
// store/screenshots/demo/sales.csv (opens through the schema page) and
// two snapshots with the pivot the screenshots start from. Deterministic
// (fixed seed), so a rerun writes the same files.
//
//   dart run tool/demo_data.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tessera/tessera.dart';

/// Region → country → relative market size.
const _countries = {
  'Europe': {
    'Germany': 1.0,
    'United Kingdom': 0.85,
    'France': 0.8,
    'Italy': 0.6,
    'Spain': 0.5,
    'Netherlands': 0.35,
  },
  'North America': {'United States': 1.6, 'Canada': 0.5, 'Mexico': 0.35},
  'Asia Pacific': {
    'Japan': 0.8,
    'Australia': 0.45,
    'India': 0.4,
    'Singapore': 0.25,
  },
  'Latin America': {
    'Brazil': 0.55,
    'Argentina': 0.25,
    'Chile': 0.2,
    'Colombia': 0.2,
  },
};

/// Category → product → unit price; units per order differ by category.
const _products = {
  'Furniture': {'Desks': 320, 'Chairs': 180, 'Bookcases': 140, 'Lamps': 45},
  'Office Supplies': {'Paper': 9, 'Binders': 7, 'Pens': 4, 'Labels': 6},
  'Technology': {
    'Laptops': 1150,
    'Phones': 690,
    'Monitors': 260,
    'Printers': 230,
  },
};
const _units = {
  'Furniture': (1, 12),
  'Office Supplies': (20, 200),
  'Technology': (1, 8),
};

/// Channel → share of orders and price factor (partners get a discount).
const _channels = {
  'Online': (0.45, 1.0),
  'Retail': (0.35, 1.0),
  'Partner': (0.20, 0.9),
};

/// Orders per month, relative: a summer dip and a strong fourth quarter.
const _season = [
  0.9,
  0.85,
  1.0,
  0.95,
  1.0,
  0.85,
  0.75,
  0.8,
  1.0,
  1.1,
  1.35,
  1.5,
];

const _rows = 3000;

final _out = Directory('store/screenshots/demo');

Future<void> main() async {
  final rnd = Random(2026);
  T pick<T>(Map<T, double> weights) {
    var x = rnd.nextDouble() * weights.values.reduce((a, b) => a + b);
    for (final MapEntry(:key, :value) in weights.entries) {
      if ((x -= value) <= 0) return key;
    }
    return weights.keys.last;
  }

  final regionWeights = {
    for (final r in _countries.entries)
      r.key: r.value.values.reduce((a, b) => a + b),
  };
  final monthWeights = {for (var m = 1; m <= 12; m++) m: _season[m - 1]};
  final csv = StringBuffer(
    'Date,Region,Country,Category,Product,Channel,Units,Revenue\n',
  );
  for (var i = 0; i < _rows; i++) {
    final region = pick(regionWeights);
    final country = pick(_countries[region]!);
    final category = pick({for (final c in _products.keys) c: 1.0});
    final product = pick({for (final p in _products[category]!.keys) p: 1.0});
    final channel = pick({
      for (final c in _channels.entries) c.key: c.value.$1,
    });
    final month = pick(monthWeights);
    final day = 1 + rnd.nextInt(DateTime(2025, month + 1, 0).day);
    final (lo, hi) = _units[category]!;
    final units = lo + rnd.nextInt(hi - lo + 1);
    final price = _products[category]![product]! * _channels[channel]!.$2;
    final revenue = (units * price * (0.85 + rnd.nextDouble() * 0.25)).round();
    final date = '2025-${'$month'.padLeft(2, '0')}-${'$day'.padLeft(2, '0')}';
    csv.writeln(
      '$date,$region,$country,$category,$product,$channel,$units,$revenue',
    );
  }
  _out.createSync(recursive: true);
  final bytes = utf8.encode(csv.toString());
  File('${_out.path}/sales.csv').writeAsBytesSync(bytes);

  final facts = (await loadFacts(
    CsvDataSource.fromData(bytes, name: 'sales.csv'),
  )).facts;
  for (final c in facts.columns) {
    stdout.writeln('  ${c.name}: ${c.type.name}');
  }

  const region = ColumnDimension('Region');
  const country = ColumnDimension('Country');
  final revenue = Aggregate.sum(ColumnMeasure('Revenue'));
  DimensionPath open(String r) => DimensionPath([DimensionValue(region, r)]);

  // Desktop and tablet: regions and countries down, quarters across.
  final wide = Cube(
    facts: facts,
    spec: CubeSpec(
      rows: CubeAxis.of([region, country]),
      columns: CubeAxis.of([const DatePartDimension('Date', DatePart.quarter)]),
      aggregates: [revenue],
    ),
  ).toggleRow(open('Europe')).toggleRow(open('North America'));
  _snapshot('Sales by quarter.tsnp', wide);

  // Phones: one value, the largest regions and countries first; the
  // smallest region stays collapsed at the bottom.
  final phone =
      Cube(
            facts: facts,
            spec: CubeSpec(
              rows: CubeAxis(
                dimensions: [
                  AxisDimension(
                    region,
                    sort: AxisSort(
                      by: SortBy.aggregate,
                      aggregate: revenue,
                      direction: SortDirection.descending,
                    ),
                  ),
                  const AxisDimension(country),
                ],
              ),
              aggregates: [revenue],
            ),
          )
          .toggleRow(open('Europe'))
          .toggleRow(open('North America'))
          .toggleRow(open('Asia Pacific'));
  _snapshot('Sales 2025.tsnp', phone);

  stdout.writeln('${facts.rowCount} rows → ${_out.path}');
}

void _snapshot(String name, Cube cube) => File('${_out.path}/$name')
    .writeAsBytesSync(
      TesseraSnapshot().encode(cube.facts, config: CubeConfig.of(cube)),
    );
