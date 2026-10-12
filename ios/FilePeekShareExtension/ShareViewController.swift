import Social
import UniformTypeIdentifiers
import UIKit

// Copies one supported document before handing it to receive_sharing_intent.
class ShareViewController: SLComposeServiceViewController {
  private let inboxName = "FilePeekShareInbox"
  private let maximumBytes = 5 * 1024 * 1024
  private let supportedExtensions: Set<String> = ["json", "csv", "txt", "log"]
  private var isImporting = false

  override func isContentValid() -> Bool { !providers.isEmpty }

  override func presentationAnimationDidFinish() {
    super.presentationAnimationDidFinish()
    navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = localized(
      "保存至 FilePeek", "Save to FilePeek"
    )
  }

  override func didSelectPost() {
    guard !isImporting, let provider = providers.first else {
      showFailure(localized("没有可读取的文件。", "No readable file was shared."))
      return
    }
    isImporting = true
    let types = provider.registeredTypeIdentifiers.filter { identifier in
      guard let type = UTType(identifier) else { return false }
      return type.conforms(to: .data) || type.conforms(to: .item)
    }
    NSLog("[FilePeekShare] types=%@ suggestedName=%@", types, provider.suggestedName ?? "<none>")
    loadFileRepresentation(from: provider, types: types, index: 0)
  }

  private var providers: [NSItemProvider] {
    (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
  }

  private func loadFileRepresentation(
    from provider: NSItemProvider,
    types: [String],
    index: Int
  ) {
    guard index < types.count else {
      loadFileURL(from: provider)
      return
    }
    let identifier = types[index]
    provider.loadFileRepresentation(forTypeIdentifier: identifier) { [weak self] url, error in
      guard let self else { return }
      if let url {
        // This system-owned URL expires when the callback returns.
        do {
          try self.importFile(at: url, provider: provider, typeIdentifier: identifier)
          return
        } catch {
          NSLog("[FilePeekShare] copy failed for %@: %@", identifier, String(describing: error))
          // Another representation may still provide a readable file.
        }
      } else if let error {
        NSLog("[FilePeekShare] representation %@ failed: %@", identifier, String(describing: error))
      }
      self.loadFileRepresentation(from: provider, types: types, index: index + 1)
    }
  }

  private func loadFileURL(from provider: NSItemProvider) {
    guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
      showFailure(localized("无法读取分享的文件。", "The shared file could not be read."))
      return
    }
    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
      [weak self] item, error in
      guard let self else { return }
      guard let url = (item as? URL) ?? (item as? NSURL).map({ $0 as URL }), url.isFileURL else {
        NSLog("[FilePeekShare] fileURL missing: %@", String(describing: error))
        self.showFailure(self.localized("无法读取分享的文件。", "The shared file could not be read."))
        return
      }
      do {
        try self.importFile(at: url, provider: provider, typeIdentifier: UTType.fileURL.identifier)
      } catch ShareImportError.tooLarge {
        self.showFailure(self.localized("文件超过 5 MiB 上限。", "The file exceeds the 5 MiB limit."))
      } catch ShareImportError.unsupportedType {
        self.showFailure(self.localized(
          "仅支持 JSON、CSV、TXT 和 LOG 文件。", "Only JSON, CSV, TXT and LOG files are supported."
        ))
      } catch {
        NSLog("[FilePeekShare] fileURL copy failed: %@", String(describing: error))
        self.showFailure(self.localized("无法读取分享的文件。", "The shared file could not be read."))
      }
    }
  }

  private func importFile(
    at source: URL,
    provider: NSItemProvider,
    typeIdentifier: String
  ) throws {
    guard let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          ),
          let defaults = UserDefaults(suiteName: appGroup) else {
      throw ShareImportError.unavailableGroup
    }
    let filename = try documentName(source: source, provider: provider, typeIdentifier: typeIdentifier)
    let accessed = source.startAccessingSecurityScopedResource()
    defer { if accessed { source.stopAccessingSecurityScopedResource() } }

    if let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize,
       size > maximumBytes {
      throw ShareImportError.tooLarge
    }
    let inbox = container.appendingPathComponent(inboxName, isDirectory: true)
    let importFolder = inbox.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: importFolder, withIntermediateDirectories: true)
    let destination = importFolder.appendingPathComponent(filename)
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      let copiedSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard copiedSize <= maximumBytes else { throw ShareImportError.tooLarge }
    } catch {
      try? FileManager.default.removeItem(at: importFolder)
      throw error
    }

    // The plugin's host decoder expects type=file and a file:// path.
    let payload = [["path": "file://" + destination.path, "type": "file"]]
    let data = try JSONSerialization.data(withJSONObject: payload)
    // Only the newest share can be pending, so remove copies superseded by it.
    if let entries = try? FileManager.default.contentsOfDirectory(
      at: inbox, includingPropertiesForKeys: nil
    ) {
      for entry in entries where entry != importFolder {
        try? FileManager.default.removeItem(at: entry)
      }
    }
    defaults.set(data, forKey: "ShareKey")
    defaults.removeObject(forKey: "ShareMessageKey")
    defaults.synchronize()
    showImportSaved()
  }

  private func documentName(
    source: URL,
    provider: NSItemProvider,
    typeIdentifier: String
  ) throws -> String {
    var name = (provider.suggestedName?.isEmpty == false ? provider.suggestedName : nil)
      ?? source.lastPathComponent
    name = URL(fileURLWithPath: name).lastPathComponent
    if !supportedExtensions.contains(URL(fileURLWithPath: name).pathExtension.lowercased()),
       let ext = UTType(typeIdentifier)?.preferredFilenameExtension,
       supportedExtensions.contains(ext.lowercased()) {
      name += "." + ext
    }
    guard supportedExtensions.contains(URL(fileURLWithPath: name).pathExtension.lowercased()) else {
      throw ShareImportError.unsupportedType
    }
    return name
  }

  private func showImportSaved() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      NSLog("[FilePeekShare] saved file to App Group inbox")
      let alert = UIAlertController(
        title: self.localized("已保存", "Saved"),
        message: self.localized(
          "请打开 FilePeek 查看分享的文件。", "Open FilePeek to view the shared file."
        ),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: self.localized("完成", "Done"), style: .default) { _ in
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      })
      self.present(alert, animated: true)
    }
  }

  private func showFailure(_ message: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.isImporting = false
      let alert = UIAlertController(
        title: self.localized("导入失败", "Import failed"), message: message, preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: self.localized("好", "OK"), style: .default))
      self.present(alert, animated: true)
    }
  }

  private func localized(_ zh: String, _ en: String) -> String {
    Locale.current.languageCode == "zh" ? zh : en
  }
}

private enum ShareImportError: Error {
  case unavailableGroup
  case tooLarge
  case unsupportedType
}
