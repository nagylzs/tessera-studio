import 'package:get_it/get_it.dart';

import 'files/file_opener.dart';
import 'state/app_state.dart';

/// Registers every service and store in [GetIt.I]. Called once from
/// `main`; tests reset the locator and register fakes instead.
void registerServices() {
  GetIt.I
    ..registerSingleton<FileOpener>(const PickerFileOpener())
    ..registerSingleton<AppState>(AppState());
}
