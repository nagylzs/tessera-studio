import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// Delivers files Finder hands us (double click, "Open With", a drop on
/// the Dock icon) to Dart, as `MainActivity.kt` does on Android. The
/// Info.plist declares the document types; macOS grants the sandbox read
/// access to each file it opens this way, so Dart gets the file's own
/// path, nothing is copied.
///
/// Events on `eu.nagylzs.tessera_studio/open` are maps with an `event`:
/// `ready` {name, path}. Events raised before Dart listens are queued and
/// flushed on subscription.
final class OpenRequests: NSObject, FlutterStreamHandler, FlutterAppLifecycleDelegate {
  static let shared = OpenRequests()

  private var sink: FlutterEventSink?
  private var queued: [[String: Any]] = []

  func register(with registrar: FlutterPluginRegistrar) {
    FlutterEventChannel(name: "eu.nagylzs.tessera_studio/open", binaryMessenger: registrar.messenger)
      .setStreamHandler(self)
    registrar.addApplicationDelegate(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    for e in queued { events(e) }
    queued.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  @objc(handleOpenURLs:)
  func handleOpen(_ urls: [URL]) -> Bool {
    let files = urls.filter(\.isFileURL)
    for url in files {
      emit(["event": "ready", "name": url.lastPathComponent, "path": url.path])
    }
    return !files.isEmpty
  }

  private func emit(_ event: [String: Any]) {
    if let sink { sink(event) } else { queued.append(event) }
  }
}
