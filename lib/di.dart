import 'package:get_it/get_it.dart';

import 'export/export_target.dart';
import 'files/clipboard_reader.dart';
import 'files/document_loader.dart';
import 'files/file_opener.dart';
import 'files/open_requests.dart';
import 'platform/links.dart';
import 'platform/system_bars.dart';
import 'state/app_state.dart';
import 'state/layout_store.dart';
import 'state/schema_store.dart';
import 'state/settings.dart';

/// Registers every service and store in [GetIt.I]. Called once from
/// `main`; tests reset the locator and register fakes instead.
void registerServices() {
  GetIt.I
    ..registerSingleton<FileOpener>(const PickerFileOpener())
    ..registerSingleton<ClipboardReader>(const SystemClipboardReader())
    ..registerSingleton<DocumentLoader>(const IoDocumentLoader())
    ..registerSingleton<OpenRequests>(OpenRequests.forPlatform())
    ..registerSingleton<SystemBars>(const PlatformSystemBars())
    ..registerSingleton<LinkOpener>(const PlatformLinkOpener())
    ..registerSingleton<ExportTarget>(const PlatformExportTarget())
    ..registerSingleton<SchemaStore>(PreferencesSchemaStore())
    ..registerSingleton<LayoutStore>(PreferencesLayoutStore())
    ..registerSingleton<AppSettings>(AppSettings(PreferencesSettingsStore()))
    ..registerSingleton<AppState>(AppState());
}
