import UIKit
import UniformTypeIdentifiers

/// Copies shared audio (e.g. WhatsApp voice messages, .opus) into the App Group
/// inbox. Whisper Notes transcribes everything in the inbox the next time it
/// comes to the foreground.
final class ShareViewController: UIViewController {
  private let label = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    label.text = "Saving voice message…"
    label.numberOfLines = 0
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Task { await saveAttachments() }
  }

  private var inbox: URL? {
    let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
      ?? "group.dev.schemann.whispernotes"
    guard let container = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
    let dir = container.appendingPathComponent("Inbox", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private func saveAttachments() async {
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    var saved = 0
    for provider in providers {
      if await save(provider) { saved += 1 }
    }
    label.text = saved > 0
      ? "Saved. Open Whisper Notes to see the transcript."
      : "No audio found in this share."
    try? await Task.sleep(nanoseconds: 1_200_000_000)
    extensionContext?.completeRequest(returningItems: nil)
  }

  private func save(_ provider: NSItemProvider) async -> Bool {
    guard let inbox,
      let type = [UTType.audio, UTType.audiovisualContent, UTType.fileURL]
        .first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) })
    else { return false }
    return await withCheckedContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
        guard let url else { return continuation.resume(returning: false) }
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))_\(url.lastPathComponent)"
        do {
          try FileManager.default.copyItem(at: url, to: inbox.appendingPathComponent(name))
          continuation.resume(returning: true)
        } catch {
          continuation.resume(returning: false)
        }
      }
    }
  }
}
