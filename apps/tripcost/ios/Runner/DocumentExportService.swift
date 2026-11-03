import Flutter
import UIKit
import UniformTypeIdentifiers

final class DocumentExportService: NSObject, UIDocumentPickerDelegate {
  private static let channelName = "trip_cost/documents"

  private let presentingViewController: () -> UIViewController?
  private var documentPickerResult: FlutterResult?

  static func register(
    binaryMessenger: FlutterBinaryMessenger,
    presentingViewController: @escaping () -> UIViewController?
  ) -> DocumentExportService {
    let service = DocumentExportService(presentingViewController: presentingViewController)
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak service] call, result in
      service?.handle(call, result: result)
    }
    return service
  }

  init(presentingViewController: @escaping () -> UIViewController?) {
    self.presentingViewController = presentingViewController
    super.init()
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "generatePdf":
      guard let document = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid-document", message: "Missing PDF document.", details: nil))
        return
      }
      do {
        result(try ExpensePdfRenderer.render(document: document).path)
      } catch {
        result(FlutterError(code: "pdf-failed", message: "Could not create PDF.", details: nil))
      }
    case "shareFiles":
      shareFiles(call.arguments, result: result)
    case "pickBackupFile":
      pickBackupFile(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func shareFiles(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let value = arguments as? [String: Any],
      let paths = value["paths"] as? [String],
      !paths.isEmpty
    else {
      result(FlutterError(code: "invalid-share", message: "No files to share.", details: nil))
      return
    }
    let urls = paths.map(URL.init(fileURLWithPath:)).filter {
      FileManager.default.fileExists(atPath: $0.path)
    }
    guard urls.count == paths.count, let presenter = presentingViewController() else {
      result(FlutterError(code: "share-unavailable", message: "A file is unavailable.", details: nil))
      return
    }
    let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(activity, animated: true) { result(nil) }
  }

  private func pickBackupFile(result: @escaping FlutterResult) {
    guard documentPickerResult == nil, let presenter = presentingViewController() else {
      result(FlutterError(code: "picker-unavailable", message: "Document picker is unavailable.", details: nil))
      return
    }
    documentPickerResult = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .data], asCopy: true)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    let result = documentPickerResult
    documentPickerResult = nil
    result?(urls.first?.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = documentPickerResult
    documentPickerResult = nil
    result?(nil)
  }
}

enum ExpensePdfRenderer {
  private static let pageSize = CGSize(width: 595, height: 842)
  private static let margin: CGFloat = 40
  private static let contentWidth = pageSize.width - (margin * 2)

  static func render(document: [String: Any]) throws -> URL {
    guard
      let title = document["title"] as? String,
      let generatedAt = document["generatedAt"] as? String,
      let labels = document["labels"] as? [String: String],
      let rows = document["rows"] as? [[String: Any]],
      let disclaimer = document["disclaimer"] as? String,
      !rows.isEmpty
    else {
      throw PdfRenderError.invalidDocument
    }
    let requestedName = (document["filename"] as? String) ?? "rhinosmart-expenses.pdf"
    let safeName = safeFilename(requestedName)
    let outputDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("tripcost-export-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let destination = outputDirectory.appendingPathComponent(safeName)
    let locale = Locale(identifier: (document["locale"] as? String) ?? "en")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    try renderer.writePDF(to: destination) { context in
      var page = 0
      var y: CGFloat = 0
      let contentBottom = pageSize.height - margin - 24

      func beginPage() {
        context.beginPage()
        page += 1
        y = margin
        let pageText = "\(page)"
        draw(
          pageText,
          in: CGRect(x: margin, y: pageSize.height - 28, width: contentWidth, height: 16),
          font: .systemFont(ofSize: 9),
          color: .secondaryLabel,
          alignment: .right
        )
      }

      func ensureSpace(_ height: CGFloat) {
        if y + height > contentBottom {
          beginPage()
        }
      }

      func drawFlowing(
        _ text: String,
        x: CGFloat = margin,
        width: CGFloat = contentWidth,
        font: UIFont,
        color: UIColor = .label,
        alignment: NSTextAlignment = .left
      ) {
        var remaining = text
        repeat {
          let availableHeight = contentBottom - y
          let fullHeight = measuredHeight(remaining, width: width, font: font, alignment: alignment)
          if fullHeight <= availableHeight {
            y += draw(
              remaining,
              in: CGRect(x: x, y: y, width: width, height: fullHeight),
              font: font,
              color: color,
              alignment: alignment
            )
            remaining = ""
            continue
          }
          let prefix = fittingPrefix(
            remaining,
            width: width,
            height: availableHeight,
            font: font,
            alignment: alignment
          )
          if prefix.isEmpty {
            beginPage()
            continue
          }
          let prefixHeight = measuredHeight(prefix, width: width, font: font, alignment: alignment)
          y += draw(
            prefix,
            in: CGRect(x: x, y: y, width: width, height: prefixHeight),
            font: font,
            color: color,
            alignment: alignment
          )
          remaining.removeFirst(prefix.count)
          if !remaining.isEmpty {
            beginPage()
          }
        } while !remaining.isEmpty
      }

      beginPage()
      drawFlowing(title, font: .systemFont(ofSize: 22, weight: .bold))
      y += 4
      drawFlowing(
        generatedAt,
        font: .systemFont(ofSize: 10),
        color: .secondaryLabel
      )
      y += 14

      for row in rows {
        ensureSpace(36)
        let item = string(row["title"])
        let date = localizedDateTime(string(row["occurredAt"]), locale: locale)
        drawFlowing(
          item,
          font: .systemFont(ofSize: 13, weight: .semibold)
        )
        drawFlowing(
          date,
          font: .systemFont(ofSize: 9),
          color: .secondaryLabel,
          alignment: .left
        )
        y += 4

        let original = "\(label(labels, "originalAmount")): \(string(row["transactionAmount"])) \(string(row["transactionCurrency"]))"
        let categoryAndType = "\(label(labels, "category")): \(string(row["category"])) · \(label(labels, "type")): \(string(row["entryType"]))"
        let home = "\(label(labels, "homeCurrency")): \(string(row["homeCurrency"]))"
        let rateDate = localizedDate(string(row["rateDate"]), locale: locale)
        let rate = "\(label(labels, "rate")): \(string(row["rate"])) · \(label(labels, "rateDate")): \(rateDate)"
        let source = "\(label(labels, "source")): \(string(row["rateSource"]))"
        let estimated = "\(label(labels, "estimated")): \(string(row["estimatedAmount"])) \(string(row["homeCurrency"]))"
        let actualValue = string(row["actualAmount"], fallback: "—")
        let actual = "\(label(labels, "actual")): \(actualValue) \(string(row["homeCurrency"]))"
        var detailLines = [categoryAndType, original, home, rate, source, estimated, actual]
        let relatedExpenseId = string(row["relatedExpenseId"])
        if !relatedExpenseId.isEmpty {
          detailLines.append("\(label(labels, "relatedExpense")): \(relatedExpenseId)")
        }
        for line in detailLines {
          drawFlowing(line, font: .systemFont(ofSize: 10.5))
        }
        ensureSpace(21)
        y += 8
        UIColor.separator.setFill()
        UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: 0.5))
        y += 12
      }

      ensureSpace(18)
      drawFlowing(
        disclaimer,
        font: .systemFont(ofSize: 9),
        color: .secondaryLabel
      )
    }
    return destination
  }

  @discardableResult
  private static func draw(
    _ text: String,
    in rect: CGRect,
    font: UIFont,
    color: UIColor = .label,
    alignment: NSTextAlignment = .left
  ) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: paragraph,
    ]
    let height = measuredHeight(text, width: rect.width, attributes: attributes)
    (text as NSString).draw(
      with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    )
    return height
  }

  private static func measuredHeight(
    _ text: String,
    width: CGFloat,
    font: UIFont,
    alignment: NSTextAlignment = .left
  ) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.alignment = alignment
    return measuredHeight(text, width: width, attributes: [
      .font: font,
      .paragraphStyle: paragraph,
    ])
  }

  private static func measuredHeight(
    _ text: String,
    width: CGFloat,
    attributes: [NSAttributedString.Key: Any]
  ) -> CGFloat {
    ceil((text as NSString).boundingRect(
      with: CGSize(width: width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    ).height)
  }

  private static func fittingPrefix(
    _ text: String,
    width: CGFloat,
    height: CGFloat,
    font: UIFont,
    alignment: NSTextAlignment
  ) -> String {
    guard !text.isEmpty, height >= font.lineHeight else { return "" }
    let boundaries = Array(text.indices) + [text.endIndex]
    var lower = 1
    var upper = boundaries.count - 1
    var best = 0
    while lower <= upper {
      let middle = (lower + upper) / 2
      let candidate = String(text[..<boundaries[middle]])
      if measuredHeight(candidate, width: width, font: font, alignment: alignment) <= height {
        best = middle
        lower = middle + 1
      } else {
        upper = middle - 1
      }
    }
    return best == 0 ? "" : String(text[..<boundaries[best]])
  }

  private static func string(_ value: Any?, fallback: String = "") -> String {
    guard let value, !(value is NSNull) else { return fallback }
    return String(describing: value)
  }

  private static func label(_ labels: [String: String], _ key: String) -> String {
    labels[key] ?? key
  }

  private static func localizedDateTime(_ value: String, locale: Locale) -> String {
    guard let date = ISO8601DateFormatter().date(from: value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private static func localizedDate(_ value: String, locale: Locale) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }

  private static func safeFilename(_ value: String) -> String {
    let name = URL(fileURLWithPath: value).lastPathComponent
    let sanitized = name.replacingOccurrences(
      of: "[^A-Za-z0-9._-]",
      with: "-",
      options: .regularExpression
    )
    return sanitized.lowercased().hasSuffix(".pdf") ? sanitized : "\(sanitized).pdf"
  }

  enum PdfRenderError: Error {
    case invalidDocument
  }
}
