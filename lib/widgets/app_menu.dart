import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/settings.dart';

/// The overflow menu at the end of every app bar: language and theme
/// (About and Settings join here later). Dialogs rather than submenus:
/// they work with a thumb as well as with a mouse.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_Entry>(
      tooltip: l10n.moreActions,
      onSelected: (entry) => switch (entry) {
        _Entry.language => showLanguageDialog(context),
        _Entry.theme => showThemeDialog(context),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _Entry.language,
          child: ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.menuLanguage),
          ),
        ),
        PopupMenuItem(
          value: _Entry.theme,
          child: ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.menuTheme),
          ),
        ),
      ],
    );
  }
}

enum _Entry { language, theme }

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
