import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../state/app_state.dart';

/// Lets the user override the inferred [Schema] before importing:
/// include or exclude columns, change their type and label, and set the
/// date format or number syntax used to parse text. "Continue" accepts
/// (and remembers the edits for files of the same structure), back or
/// close discards. Local edit state is a plain StatefulWidget: it only
/// exists while the page is up.
class SchemaPage extends StatefulWidget {
  const SchemaPage({super.key, required this.document});

  final OpenedDocument document;

  @override
  State<SchemaPage> createState() => _SchemaPageState();
}

class _SchemaPageState extends State<SchemaPage> {
  final _state = GetIt.I<AppState>();
  late Schema _schema = _state.schema.value ?? _info.inferred;

  SourceInfo get _info => _state.source.value!;

  String _samples(String column) {
    final i = _info.columnNames.indexOf(column);
    if (i < 0) return '';
    return _info.samples
        .map((r) => i < r.length ? r[i]?.toString() ?? '' : '')
        .where((s) => s.isNotEmpty)
        .take(3)
        .join(' · ');
  }

  void _set(ColumnSpec spec) => setState(() => _schema = _schema.replace(spec));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fromWorkbench = _state.schemaBack.value == AppPage.workbench;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _state.cancelSchema();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(fromWorkbench ? Icons.arrow_back : Icons.close),
            tooltip: fromWorkbench
                ? MaterialLocalizations.of(context).backButtonTooltip
                : l10n.closeFile,
            onPressed: _state.cancelSchema,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.schemaTitle),
              Text(widget.document.name, style: theme.textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() => _schema = _info.inferred),
              child: Text(l10n.resetToInferred),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _state.acceptSchema(_schema),
              icon: const Icon(Icons.check),
              label: Text(l10n.continueButton),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: _schema.columns.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _ColumnRow(
            spec: _schema.columns[i],
            samples: _samples(_schema.columns[i].name),
            onChanged: _set,
          ),
        ),
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({
    required this.spec,
    required this.samples,
    required this.onChanged,
  });

  final ColumnSpec spec;
  final String samples;
  final ValueChanged<ColumnSpec> onChanged;

  /// Below this width the fields wrap under the name instead of sitting
  /// in one row (phones).
  static const _wide = 720.0;

  /// [ColumnSpec.copyWith] cannot clear [ColumnSpec.format], so rebuild.
  ColumnSpec _with({
    bool? include,
    ColumnType? type,
    String? label,
    String? format,
    bool clearFormat = false,
    NumberSyntax? numberSyntax,
  }) => ColumnSpec(
    name: spec.name,
    type: type ?? spec.type,
    include: include ?? spec.include,
    label: label ?? spec.label,
    format: clearFormat ? null : format ?? spec.format,
    numberSyntax: numberSyntax ?? spec.numberSyntax,
    parser: spec.parser,
    nullValues: spec.nullValues,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDate =
        spec.type == ColumnType.date || spec.type == ColumnType.dateTime;
    final isNumeric = spec.type.isNumeric;

    final head = Row(
      children: [
        Tooltip(
          message: l10n.includeColumn,
          child: Switch(
            value: spec.include,
            onChanged: (v) => onChanged(_with(include: v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spec.name, style: theme.textTheme.titleSmall),
              Text(
                samples,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    final type = SizedBox(
      width: 160,
      child: DropdownButtonFormField<ColumnType>(
        key: ValueKey('type-${spec.name}'),
        isExpanded: true,
        initialValue: spec.type,
        decoration: InputDecoration(labelText: l10n.typeLabel, isDense: true),
        items: [
          for (final t in ColumnType.values)
            DropdownMenuItem(value: t, child: Text(l10n.columnType(t))),
        ],
        onChanged: spec.include
            ? (t) => onChanged(_with(type: t, clearFormat: true))
            : null,
      ),
    );
    final label = SizedBox(
      width: 180,
      child: TextFormField(
        key: ValueKey('label-${spec.name}'),
        initialValue: spec.label ?? '',
        enabled: spec.include,
        decoration: InputDecoration(
          labelText: l10n.labelLabel,
          hintText: spec.name,
          isDense: true,
        ),
        onChanged: (v) => onChanged(_with(label: v.isEmpty ? null : v)),
      ),
    );
    final Widget parsing = isDate
        ? SizedBox(
            width: 200,
            child: TextFormField(
              key: ValueKey('format-${spec.name}'),
              initialValue: spec.format ?? '',
              enabled: spec.include,
              decoration: InputDecoration(
                labelText: l10n.dateFormatLabel,
                hintText: l10n.dateFormatHint,
                isDense: true,
              ),
              onChanged: (v) => onChanged(
                v.isEmpty ? _with(clearFormat: true) : _with(format: v),
              ),
            ),
          )
        : isNumeric
        ? SizedBox(
            width: 200,
            child: DropdownButtonFormField<NumberSyntax>(
              key: ValueKey('syntax-${spec.name}'),
              isExpanded: true,
              initialValue: spec.numberSyntax,
              decoration: InputDecoration(
                labelText: l10n.numberSyntaxLabel,
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: NumberSyntax.standard,
                  child: Text('1,234.56'),
                ),
                DropdownMenuItem(
                  value: NumberSyntax.european,
                  child: Text('1.234,56'),
                ),
              ],
              onChanged: spec.include
                  ? (s) => onChanged(_with(numberSyntax: s))
                  : null,
            ),
          )
        : const SizedBox(width: 200);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _wide
            ? Row(
                children: [
                  Expanded(flex: 3, child: head),
                  const SizedBox(width: 12),
                  type,
                  const SizedBox(width: 12),
                  label,
                  const SizedBox(width: 12),
                  parsing,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  head,
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [type, label, parsing],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
