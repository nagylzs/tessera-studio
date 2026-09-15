import 'package:get_it/get_it.dart';

import 'files/clipboard_reader.dart';
import 'files/document_loader.dart';
import 'files/file_opener.dart';
import 'files/open_requests.dart';
import 'state/app_state.dart';
import 'state/schema_store.dart';

/// Registers every service and store in [GetIt.I]. Called once from
/// `main`; tests reset the locator and register fakes instead.
void registerServices() {
  GetIt.I
    ..registerSingleton<FileOpener>(const PickerFileOpener())
    ..registerSingleton<ClipboardReader>(const SystemClipboardReader())
    ..registerSingleton<DocumentLoader>(const IoDocumentLoader())
    ..registerSingleton<OpenRequests>(OpenRequests.forPlatform())
    ..registerSingleton<SchemaStore>(PreferencesSchemaStore())
    ..registerSingleton<AppState>(AppState());
}
