import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/settings.dart';

/// An entry a page adds above the common ones of [AppMenuButton].
final class AppMenuEntry {
  const AppMenuEntry({
    required this.label,
    required this.onTap,
    this.icon,
    this.checked,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Non-null renders a checkable entry.
  final bool? checked;
  final bool enabled;
}

/// The overflow menu at the end of every app bar: the page's own
/// [entries] first, then language and theme (About and Settings join
/// here later). Dialogs rather than submenus: they work with a thumb as
/// well as with a mouse.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, this.entries = const []});

  final List<AppMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final common = [
      AppMenuEntry(
        label: l10n.menuLanguage,
        icon: Icons.language,
        onTap: () => showLanguageDialog(context),
      ),
      AppMenuEntry(
        label: l10n.menuTheme,
        icon: Icons.brightness_6_outlined,
        onTap: () => showThemeDialog(context),
      ),
    ];
    return PopupMenuButton<AppMenuEntry>(
      tooltip: l10n.moreActions,
      onSelected: (entry) => entry.onTap(),
      itemBuilder: (context) => [
        for (final e in entries)
          if (e.checked != null)
            CheckedPopupMenuItem(
              value: e,
              checked: e.checked!,
              enabled: e.enabled,
              child: Text(e.label),
            )
          else
            PopupMenuItem(value: e, enabled: e.enabled, child: _row(e)),
        if (entries.isNotEmpty) const PopupMenuDivider(),
        for (final e in common) PopupMenuItem(value: e, child: _row(e)),
      ],
    );
  }

  /// Icon and label. Not a ListTile: inside a menu clamped to a phone's
  /// width a ListTile cannot shrink and overflows.
  static Widget _row(AppMenuEntry e) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (e.icon != null) ...[Icon(e.icon), const SizedBox(width: 12)],
      Flexible(child: Text(e.label)),
    ],
  );
}

/// The fourteen tessera languages, each named in itself, so a user in
/// the wrong language can still find their own. Not translated.
const languageNames = <String, String>{
  'cs': 'Čeština',
  'de': 'Deutsch',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'hu': 'Magyar',
  'it': 'Italiano',
  'ja': '日本語',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'pt': 'Português',
  'ru': 'Русский',
  'tr': 'Türkçe',
  'zh': '中文',
};

/// "System" plus every supported language; applies on selection.
Future<void> showLanguageDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final settings = GetIt.I<AppSettings>();
  return showDialog<void>(
    context: context,
    builder: (context) => _RadioDialog<String?>(
      title: l10n.menuLanguage,
      value: settings.locale.value?.languageCode,
      options: [
        (null, l10n.systemDefault),
        for (final locale in TesseraLocalizations.supportedLocales)
          (
            locale.languageCode,
            languageNames[locale.languageCode] ?? locale.languageCode,
          ),
      ],
      onChanged: (code) =>
          settings.setLocale(code == null ? null : Locale(code)),
    ),
  );
}

/// System, light or dark; applies on selection.
Future<void> showThemeDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final settings = GetIt.I<AppSettings>();
  return showDialog<void>(
    context: context,
    builder: (context) => _RadioDialog<ThemeMode>(
      title: l10n.menuTheme,
      value: settings.themeMode.value,
      options: [
        (ThemeMode.system, l10n.systemDefault),
        (ThemeMode.light, l10n.themeLight),
        (ThemeMode.dark, l10n.themeDark),
      ],
      onChanged: settings.setThemeMode,
    ),
  );
}

class _RadioDialog<T> extends StatelessWidget {
  const _RadioDialog({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title.replaceAll('…', '')),
    contentPadding: const EdgeInsets.symmetric(vertical: 16),
    content: SizedBox(
      width: 320,
      child: RadioGroup<T>(
        groupValue: value,
        onChanged: (v) {
          Navigator.pop(context);
          onChanged(v as T);
        },
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (v, label) in options)
              RadioListTile<T>(value: v, title: Text(label)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
  );
}
