import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareInbox") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "whisper_notes/share", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "takeSharedFiles" {
        result(ShareInbox.takeSharedFiles())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Moves files the Share Extension left in the App Group inbox into the app's
/// own temp folder and returns their paths.
enum ShareInbox {
  static func takeSharedFiles() -> [String] {
    let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
      ?? "group.dev.schemann.whispernotes"
    let fm = FileManager.default
    guard let container = fm.containerURL(forSecurityApplicationGroupIdentifier: group) else {
      return []
    }
    let inbox = container.appendingPathComponent("Inbox", isDirectory: true)
    let target = fm.temporaryDirectory.appendingPathComponent("shared", isDirectory: true)
    try? fm.createDirectory(at: target, withIntermediateDirectories: true)
    let files = (try? fm.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
    return files.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { file in
      let destination = target.appendingPathComponent(file.lastPathComponent)
      try? fm.removeItem(at: destination)
      do {
        try fm.moveItem(at: file, to: destination)
        return destination.path
      } catch {
        return nil
      }
    }
  }
}
