import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    OpenRequests.shared.clearCache()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenRequests") {
      OpenRequests.shared.register(with: registrar)
    }
  }
}

/// Delivers files the system hands us (the share sheet, "Open in", AirDrop,
/// the Files app) to Dart, as `MainActivity.kt` does on Android. The
/// Info.plist declares the document types with
/// `LSSupportsOpeningDocumentsInPlace` off, so iOS puts a copy into our
/// container; it is moved into `Caches/open` right away (emptied at every
/// start) and Dart gets a plain path plus the file's name.
///
/// Events on `eu.nagylzs.tessera_studio/open` are maps with an `event`:
/// `started` {name}, `ready` {name, path}, `failed` {name, error}. Events
/// raised before Dart listens are queued and flushed on subscription.
final class OpenRequests: NSObject, FlutterStreamHandler, FlutterSceneLifeCycleDelegate {
  static let shared = OpenRequests()

  private var sink: FlutterEventSink?
  private var queued: [[String: Any]] = []

  func register(with registrar: FlutterPluginRegistrar) {
    FlutterEventChannel(name: "eu.nagylzs.tessera_studio/open", binaryMessenger: registrar.messenger())
      .setStreamHandler(self)
    registrar.addSceneDelegate(self)
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

  /// A cold start with a file.
  @objc(scene:willConnectToSession:options:)
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    return open(contexts)
  }

  /// A file while the app runs.
  @objc(scene:openURLContexts:)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    open(URLContexts)
  }

  private func open(_ contexts: Set<UIOpenURLContext>) -> Bool {
    let files = contexts.map(\.url).filter(\.isFileURL)
    for url in files { copy(url) }
    return !files.isEmpty
  }

  private func copy(_ url: URL) {
    let name = Self.sanitize(url.lastPathComponent)
    emit(["event": "started", "name": name])
    DispatchQueue.global(qos: .userInitiated).async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      do {
        let files = FileManager.default
        let dir = try Self.cacheDir()
        try files.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent("\(DispatchTime.now().uptimeNanoseconds)_\(name)")
        try files.copyItem(at: url, to: target)
        // iOS's copy in our container (the inbox) is not needed again.
        if url.standardizedFileURL.path.hasPrefix(NSHomeDirectory()) {
          try? files.removeItem(at: url)
        }
        DispatchQueue.main.async {
          self.emit(["event": "ready", "name": name, "path": target.path])
        }
      } catch {
        DispatchQueue.main.async {
          self.emit(["event": "failed", "name": name, "error": error.localizedDescription])
        }
      }
    }
  }

  /// Empties `Caches/open`. Not the inbox: at a cold start iOS has already
  /// put the file being opened there; each one is removed once copied.
  func clearCache() {
    let files = FileManager.default
    guard let dir = try? Self.cacheDir() else { return }
    for item in (try? files.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
      try? files.removeItem(at: item)
    }
  }

  private static func cacheDir() throws -> URL {
    try FileManager.default.url(
      for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    ).appendingPathComponent("open")
  }

  private static func sanitize(_ name: String) -> String {
    let n = name.replacingOccurrences(of: "/", with: "_")
    return n.isEmpty ? "file" : n
  }

  private func emit(_ event: [String: Any]) {
    if let sink { sink(event) } else { queued.append(event) }
  }
}
