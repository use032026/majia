import Flutter
import QuickLook
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, QLPreviewControllerDataSource, UIDocumentPickerDelegate {
  private var previewURL: URL?
  private var pendingDocumentResult: FlutterResult?
  private let pdfBrand = UIColor(photoReportHex: 0x0B6B63)
  private let pdfInk = UIColor(photoReportHex: 0x17312E)
  private let pdfMuted = UIColor(photoReportHex: 0x5F716D)
  private let pdfCanvas = UIColor(photoReportHex: 0xF4F7F6)
  private let pdfSoftSurface = UIColor(photoReportHex: 0xE7F0EE)
  private let pdfPending = UIColor(photoReportHex: 0xAD5417)
  private let pdfInProgress = UIColor(photoReportHex: 0x2465A8)
  private let pdfCompleted = UIColor(photoReportHex: 0x1F7650)
  private let pdfRisk = UIColor(photoReportHex: 0xB7353D)
  private let pdfAnnotation = UIColor(photoReportHex: 0xFF2D2D)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerPhotoReportPlugin(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerPhotoReportPlugin(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "PhotoReportPDF") else { return }
    let channel = FlutterMethodChannel(
      name: "com.starburst.photo_report/report",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleReportCall(call, result: result)
    }
  }

  private func handleReportCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    let copy = ReportCopy(languageCode: arguments["languageCode"] as? String ?? "zh")
    switch call.method {
    case "getPreferredLanguage":
      result(UserDefaults.standard.string(forKey: "preferredLanguage"))
    case "clearPreferredLanguage":
      UserDefaults.standard.removeObject(forKey: "preferredLanguage")
      result(nil)
    case "setPreferredLanguage":
      guard
        let languageCode = arguments["languageCode"] as? String,
        ["zh", "en"].contains(languageCode)
      else {
        result(FlutterError(code: "invalid_language", message: copy.text("语言设置无效"), details: nil))
        return
      }
      UserDefaults.standard.set(languageCode, forKey: "preferredLanguage")
      result(nil)
    case "getOnboardingComplete":
      result(UserDefaults.standard.bool(forKey: "onboardingComplete"))
    case "setOnboardingComplete":
      guard let isComplete = arguments["isComplete"] as? Bool else {
        result(FlutterError(code: "invalid_onboarding_state", message: "Invalid onboarding state", details: nil))
        return
      }
      UserDefaults.standard.set(isComplete, forKey: "onboardingComplete")
      result(nil)
    case "openPrivacyPolicy":
      guard
        let address = arguments["url"] as? String,
        let url = URL(string: address),
        url.scheme == "https",
        url.host == "jovfx1.com"
      else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    case "generateReport":
      guard
        let project = arguments["project"] as? [String: Any],
        let issues = arguments["issues"] as? [[String: Any]],
        let options = arguments["options"] as? [String: Any]
      else {
        result(FlutterError(code: "invalid_payload", message: copy.text("报告数据格式错误"), details: nil))
        return
      }
      do {
        let url = try generateReport(project: project, issues: issues, options: options, copy: copy)
        result(url.path)
      } catch {
        result(FlutterError(code: "pdf_generation_failed", message: error.localizedDescription, details: nil))
      }
    case "previewReport":
      guard let path = arguments["path"] as? String, FileManager.default.fileExists(atPath: path) else {
        result(FlutterError(code: "missing_file", message: copy.text("找不到报告文件"), details: nil))
        return
      }
      previewURL = URL(fileURLWithPath: path)
      let preview = QLPreviewController()
      preview.dataSource = self
      currentViewController()?.present(preview, animated: true)
      result(nil)
    case "shareReport":
      guard let path = arguments["path"] as? String, FileManager.default.fileExists(atPath: path) else {
        result(FlutterError(code: "missing_file", message: copy.text("找不到报告文件"), details: nil))
        return
      }
      let activity = UIActivityViewController(
        activityItems: [URL(fileURLWithPath: path)],
        applicationActivities: nil
      )
      if let popover = activity.popoverPresentationController,
         let view = currentViewController()?.view {
        popover.sourceView = view
        popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 60, width: 1, height: 1)
      }
      currentViewController()?.present(activity, animated: true)
      result(nil)
    case "pickBackup":
      guard pendingDocumentResult == nil else {
        result(FlutterError(code: "picker_busy", message: copy.text("文件选择器正在使用"), details: nil))
        return
      }
      let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.data, .json],
        asCopy: true
      )
      guard let presenter = currentViewController() else {
        result(FlutterError(code: "missing_presenter", message: copy.text("暂时无法打开文件选择器"), details: nil))
        return
      }
      pendingDocumentResult = result
      picker.delegate = self
      presenter.present(picker, animated: true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    previewURL == nil ? 0 : 1
  }

  func previewController(
    _ controller: QLPreviewController,
    previewItemAt index: Int
  ) -> QLPreviewItem {
    previewURL! as NSURL
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    pendingDocumentResult?(urls.first?.path)
    pendingDocumentResult = nil
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingDocumentResult?(nil)
    pendingDocumentResult = nil
  }

  private func currentViewController() -> UIViewController? {
    var current = window?.rootViewController
    while true {
      if let presented = current?.presentedViewController {
        current = presented
      } else if let navigation = current as? UINavigationController {
        current = navigation.visibleViewController
      } else if let tabs = current as? UITabBarController {
        current = tabs.selectedViewController
      } else {
        return current
      }
    }
  }

  func generateReport(
    project: [String: Any],
    issues: [[String: Any]]
  ) throws -> URL {
    try generateReport(
      project: project,
      issues: issues,
      options: [
        "layout": "detailed",
        "includePosition": true,
        "includeStatus": true,
        "includeSeverity": true,
        "includeAssignee": true,
        "includeDueDate": true,
        "includeProjectDetails": true,
        "includeNotes": true,
      ]
    )
  }

  func generateReport(
    project: [String: Any],
    issues: [[String: Any]],
    options: [String: Any],
    copy: ReportCopy = ReportCopy(languageCode: "zh")
  ) throws -> URL {
    let fileManager = FileManager.default
    let documents = try fileManager.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let reports = documents.appendingPathComponent("PhotoReport/Reports", isDirectory: true)
    try fileManager.createDirectory(at: reports, withIntermediateDirectories: true)
    let rawName = project.string("name", fallback: copy.text("现场报告"))
    let safeName = rawName
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let url = reports.appendingPathComponent("\(safeName)-\(formatter.string(from: Date())).pdf")

    let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
    let format = UIGraphicsPDFRendererFormat()
    format.documentInfo = [
      kCGPDFContextTitle as String: copy.reportTitle(rawName),
      kCGPDFContextCreator as String: "JOVFX",
    ]
    let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
    var pageNumber = 0
    try renderer.writePDF(to: url) { context in
      func beginPage() {
        context.beginPage()
        pageNumber += 1
        UIColor.white.setFill()
        context.cgContext.fill(pageBounds)
      }

      func footer() {
        let text = copy.footer(pageNumber: pageNumber)
        drawText(
          text,
          in: CGRect(x: 42, y: 808, width: 511, height: 22),
          font: .systemFont(ofSize: 7.4),
          color: pdfMuted,
          alignment: .center
        )
      }

      let concise = options.string("layout") == "concise"
      if !concise {
        beginPage()
        drawCover(project: project, issues: issues, options: options, copy: copy, pageBounds: pageBounds)
        footer()
      }

      for issue in issues {
        let photos = issue["photos"] as? [[String: Any]] ?? []
        let chunks: [[[String: Any]]]
        if photos.isEmpty {
          chunks = [[]]
        } else {
          chunks = stride(from: 0, to: photos.count, by: 4).map {
            Array(photos[$0..<min($0 + 4, photos.count)])
          }
        }
        for (chunkIndex, chunk) in chunks.enumerated() {
          beginPage()
          drawIssuePage(
            issue: issue,
            photos: chunk,
            continuation: chunkIndex > 0,
            options: options,
            copy: copy,
            pageBounds: pageBounds
          )
          footer()
        }
      }

      if !concise && options.bool("includeNotes") {
        beginPage()
        drawNotesPage(project: project, issues: issues, copy: copy, pageBounds: pageBounds)
        footer()
      }
    }
    return url
  }

  private func drawCover(
    project: [String: Any],
    issues: [[String: Any]],
    options: [String: Any],
    copy: ReportCopy,
    pageBounds: CGRect
  ) {
    let teal = pdfBrand
    teal.setFill()
    UIRectFill(CGRect(x: 0, y: 0, width: pageBounds.width, height: 17))

    let company = options.bool("includeProjectDetails")
      ? project.string("companyName", fallback: copy.text("现场情况记录"))
      : copy.text("现场情况记录")
    drawText(company, in: CGRect(x: 42, y: 48, width: 511, height: 24), font: .boldSystemFont(ofSize: 13), color: teal)
    drawText(
      copy.text("现场照片沟通记录"),
      in: CGRect(x: 42, y: 132, width: 511, height: 54),
      font: .boldSystemFont(ofSize: copy.isEnglish ? 30 : 34),
      color: pdfInk
    )
    drawText(
      "FIELD PHOTO NOTES",
      in: CGRect(x: 44, y: 190, width: 511, height: 22),
      font: .systemFont(ofSize: 11, weight: .semibold),
      color: pdfMuted
    )

    let infoRect = CGRect(x: 42, y: 254, width: 511, height: 190)
    pdfSoftSurface.setFill()
    UIBezierPath(roundedRect: infoRect, cornerRadius: 14).fill()
    drawText(project.string("name"), in: CGRect(x: 64, y: 278, width: 467, height: 30), font: .boldSystemFont(ofSize: 20), color: pdfInk)
    if options.bool("includeProjectDetails") {
      drawInfoRow(copy.text("记录地点"), value: project.string("address"), y: 324, labelWidth: copy.isEnglish ? 104 : 74)
      drawInfoRow(copy.text("记录日期"), value: project.string("inspectionDate"), y: 356, labelWidth: copy.isEnglish ? 104 : 74)
      drawInfoRow(copy.text("记录人员"), value: project.string("inspectorName", fallback: copy.text("未填写")), y: 388, labelWidth: copy.isEnglish ? 104 : 74)
    }

    let pending = issues.filter { $0.string("status") == "待处理" }.count
    let progress = issues.filter { $0.string("status") == "处理中" }.count
    let completed = issues.filter { $0.string("status") == "已完成" }.count
    let high = issues.filter { $0.string("severity") == "高" }.count
    var metrics: [(String, Int, UIColor)] = [
      (copy.text("记录总数"), issues.count, pdfInk),
    ]
    if options.bool("includeStatus") {
      metrics.append((copy.text("待处理"), pending, pdfPending))
      metrics.append((copy.text("处理中"), progress, pdfInProgress))
      metrics.append((copy.text("已完成"), completed, pdfCompleted))
    }
    if options.bool("includeSeverity") {
      metrics.append((copy.text("高优先级"), high, pdfRisk))
    }
    let metricWidth = min(120, (511 - CGFloat(metrics.count - 1) * 10) / CGFloat(metrics.count))
    for (index, metric) in metrics.enumerated() {
      let x = 42 + CGFloat(index) * (metricWidth + 10)
      drawMetric(label: metric.0, value: metric.1, color: metric.2, rect: CGRect(x: x, y: 482, width: metricWidth, height: 88))
    }

    if options.bool("includePosition") {
      let rooms = Array(Set(issues.map { $0.string("room") })).filter { !$0.isEmpty }.sorted()
      drawText(copy.text("记录范围"), in: CGRect(x: 42, y: 618, width: 511, height: 24), font: .boldSystemFont(ofSize: 15), color: pdfInk)
      drawText(
        rooms.isEmpty ? copy.text("尚未记录区域") : rooms.joined(separator: "  ·  "),
        in: CGRect(x: 42, y: 650, width: 511, height: 64),
        font: .systemFont(ofSize: 12),
        color: pdfMuted
      )
    }
    drawText(
      copy.text("内容仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见。"),
      in: CGRect(x: 42, y: 756, width: 511, height: 28),
      font: .systemFont(ofSize: 9),
      color: pdfMuted
    )
  }

  private func drawInfoRow(_ label: String, value: String, y: CGFloat, labelWidth: CGFloat) {
    drawText(label, in: CGRect(x: 64, y: y, width: labelWidth, height: 22), font: .systemFont(ofSize: 10), color: pdfMuted)
    let valueX = 64 + labelWidth + 7
    drawText(value, in: CGRect(x: valueX, y: y, width: 531 - valueX, height: 22), font: .systemFont(ofSize: 11, weight: .medium), color: pdfInk)
  }

  private func drawMetric(label: String, value: Int, color: UIColor, rect: CGRect) {
    color.withAlphaComponent(0.09).setFill()
    UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
    drawText("\(value)", in: CGRect(x: rect.minX + 13, y: rect.minY + 15, width: rect.width - 26, height: 30), font: .boldSystemFont(ofSize: 23), color: color)
    drawText(label, in: CGRect(x: rect.minX + 13, y: rect.minY + 53, width: rect.width - 26, height: 18), font: .systemFont(ofSize: 9), color: pdfMuted)
  }

  private func drawIssuePage(
    issue: [String: Any],
    photos: [[String: Any]],
    continuation: Bool,
    options: [String: Any],
    copy: ReportCopy,
    pageBounds: CGRect
  ) {
    let teal = pdfBrand
    let code = issue.string("code")
    teal.setFill()
    UIBezierPath(roundedRect: CGRect(x: 42, y: 38, width: 76, height: 29), cornerRadius: 7).fill()
    drawText(code, in: CGRect(x: 42, y: 45, width: 76, height: 16), font: .boldSystemFont(ofSize: 11), color: .white, alignment: .center)
    drawText(
      continuation ? copy.text("补充照片") : issue.string("category"),
      in: CGRect(x: 130, y: 40, width: 423, height: 26),
      font: .boldSystemFont(ofSize: 19),
      color: pdfInk
    )
    var pills: [(String, UIColor)] = []
    let severity = issue.string("severity")
    if options.bool("includeSeverity") && severity != "未设置" {
      pills.append((copy.severityPriority(severity), severityColor(severity)))
    }
    let status = issue.string("status")
    if options.bool("includeStatus") && status != "未设置" {
      pills.append((copy.text(status), statusColor(status)))
    }
    if !pills.isEmpty {
      let pillWidth: CGFloat = 98
      let pillGap: CGFloat = 8
      let totalWidth = CGFloat(pills.count) * pillWidth + CGFloat(pills.count - 1) * pillGap
      var pillX = 553 - totalWidth
      for pill in pills {
        drawPill(pill.0, x: pillX, y: 74, color: pill.1)
        pillX += pillWidth + pillGap
      }
    }

    let detailY: CGFloat = pills.isEmpty ? 92 : 110
    var photosY: CGFloat = pills.isEmpty ? 104 : 116
    if !continuation {
      let concise = options.string("layout") == "concise"
      let detailHeight: CGFloat = concise
        ? (options.bool("includePosition") ? 132 : 112)
        : 151
      let detailRect = CGRect(x: 42, y: detailY, width: 511, height: detailHeight)
      pdfSoftSurface.setFill()
      UIBezierPath(roundedRect: detailRect, cornerRadius: 12).fill()
      var descriptionY: CGFloat = detailY + 19
      if options.bool("includePosition") {
        let room = issue.string("room")
        let location = issue.string("location")
        let position = location.isEmpty ? room : "\(room) / \(location)"
        drawDetailPair(label: copy.text("位置"), value: position, x: 58, y: detailY + 15, width: 292)
        descriptionY = detailY + 59
      }
      if !concise && options.bool("includeAssignee") {
        drawDetailPair(label: copy.text("负责人"), value: issue.string("assignee", fallback: copy.text("未填写")), x: 365, y: detailY + 15, width: 168)
      }
      if !concise && options.bool("includeDueDate") {
        drawDetailPair(label: copy.text("处理期限"), value: issue.string("dueDate", fallback: copy.text("未设置")), x: 365, y: detailY + 58, width: 168)
      }
      drawText(copy.text("照片说明"), in: CGRect(x: 58, y: descriptionY, width: copy.isEnglish ? 118 : 72, height: 17), font: .systemFont(ofSize: 9), color: pdfMuted)
      drawText(issue.string("description"), in: CGRect(x: 58, y: descriptionY + 20, width: concise ? 475 : 292, height: concise ? 43 : 50), font: .systemFont(ofSize: 10.5), color: pdfInk)
      photosY = detailY + detailHeight + 22
    }

    if photos.isEmpty {
      pdfCanvas.setFill()
      UIBezierPath(roundedRect: CGRect(x: 42, y: photosY, width: 511, height: 250), cornerRadius: 12).fill()
      drawText(copy.text("此记录未附现场照片"), in: CGRect(x: 42, y: photosY + 112, width: 511, height: 24), font: .systemFont(ofSize: 12), color: pdfMuted, alignment: .center)
      return
    }

    let cellWidth: CGFloat = 248
    let cellHeight: CGFloat = 238
    for (index, photo) in photos.enumerated() {
      let column = index % 2
      let row = index / 2
      let cell = CGRect(
        x: 42 + CGFloat(column) * 263,
        y: photosY + CGFloat(row) * 252,
        width: cellWidth,
        height: cellHeight
      )
      drawPhoto(photo, copy: copy, in: cell)
    }
  }

  private func drawDetailPair(label: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat) {
    drawText(label, in: CGRect(x: x, y: y, width: width, height: 16), font: .systemFont(ofSize: 9), color: pdfMuted)
    drawText(value, in: CGRect(x: x, y: y + 18, width: width, height: 20), font: .systemFont(ofSize: 10.5, weight: .semibold), color: pdfInk)
  }

  private func drawPill(_ text: String, x: CGFloat, y: CGFloat, color: UIColor) {
    let rect = CGRect(x: x, y: y, width: 98, height: 24)
    color.withAlphaComponent(0.1).setFill()
    UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
    drawText(text, in: CGRect(x: x, y: y + 6, width: 98, height: 13), font: .boldSystemFont(ofSize: 8.5), color: color, alignment: .center)
  }

  private func drawPhoto(_ photo: [String: Any], copy: ReportCopy, in rect: CGRect) {
    pdfCanvas.setFill()
    UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
    drawText(copy.text(photo.string("phase")), in: CGRect(x: rect.minX + 9, y: rect.minY + 7, width: rect.width - 18, height: 16), font: .boldSystemFont(ofSize: 9), color: pdfMuted)
    let frame = CGRect(x: rect.minX + 7, y: rect.minY + 28, width: rect.width - 14, height: rect.height - 35)
    guard let image = UIImage(contentsOfFile: photo.string("path")) else {
      drawText(copy.text("照片文件不可用"), in: frame, font: .systemFont(ofSize: 10), color: pdfMuted, alignment: .center)
      return
    }
    let imageRect = aspectFit(image.size, inside: frame)
    UIColor(red: 0.09, green: 0.12, blue: 0.12, alpha: 1).setFill()
    UIRectFill(frame)
    image.draw(in: imageRect)
    let annotations = photo["annotations"] as? [[String: Any]] ?? []
    for annotation in annotations {
      drawAnnotation(annotation, in: imageRect)
    }
  }

  private func drawAnnotation(_ annotation: [String: Any], in rect: CGRect) {
    func number(_ key: String) -> CGFloat {
      CGFloat((annotation[key] as? NSNumber)?.doubleValue ?? 0)
    }
    let start = CGPoint(x: rect.minX + number("x1") * rect.width, y: rect.minY + number("y1") * rect.height)
    let end = CGPoint(x: rect.minX + number("x2") * rect.width, y: rect.minY + number("y2") * rect.height)
    let color = (annotation["color"] as? NSNumber).map {
      UIColor(photoReportHex: $0.uint32Value & 0x00FF_FFFF)
    } ?? pdfAnnotation
    let path = UIBezierPath()
    path.lineWidth = 2.4
    color.setStroke()
    switch annotation.string("kind") {
    case "rectangle":
      path.append(UIBezierPath(rect: CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))))
      path.stroke()
    case "arrow":
      path.move(to: start)
      path.addLine(to: end)
      let angle = atan2(end.y - start.y, end.x - start.x)
      let length: CGFloat = 12
      path.move(to: end)
      path.addLine(to: CGPoint(x: end.x - cos(angle - 0.58) * length, y: end.y - sin(angle - 0.58) * length))
      path.move(to: end)
      path.addLine(to: CGPoint(x: end.x - cos(angle + 0.58) * length, y: end.y - sin(angle + 0.58) * length))
      path.stroke()
    case "text":
      let text = annotation.string("text")
      let textRect = CGRect(x: start.x, y: start.y, width: min(130, rect.maxX - start.x), height: 32)
      color.withAlphaComponent(0.88).setFill()
      UIBezierPath(roundedRect: textRect, cornerRadius: 4).fill()
      drawText(
        text,
        in: textRect.insetBy(dx: 5, dy: 6),
        font: .boldSystemFont(ofSize: 8),
        color: color.photoReportContrastingTextColor
      )
    default:
      break
    }
  }

  private func drawNotesPage(
    project: [String: Any],
    issues: [[String: Any]],
    copy: ReportCopy,
    pageBounds: CGRect
  ) {
    let teal = pdfBrand
    teal.setFill()
    UIRectFill(CGRect(x: 0, y: 0, width: pageBounds.width, height: 17))
    drawText(copy.text("补充说明"), in: CGRect(x: 42, y: 58, width: 511, height: 38), font: .boldSystemFont(ofSize: 26), color: pdfInk)
    drawText(copy.projectLine(project.string("name")), in: CGRect(x: 42, y: 108, width: 511, height: 22), font: .systemFont(ofSize: 11, weight: .semibold), color: pdfMuted)

    let notesRect = CGRect(x: 42, y: 164, width: 511, height: 210)
    pdfSoftSurface.setFill()
    UIBezierPath(roundedRect: notesRect, cornerRadius: 12).fill()
    drawText(copy.text("补充说明"), in: CGRect(x: 60, y: 184, width: 180, height: 22), font: .boldSystemFont(ofSize: 13), color: teal)
    drawText(project.string("notes", fallback: copy.text("无")), in: CGRect(x: 60, y: 219, width: 475, height: 132), font: .systemFont(ofSize: 11), color: pdfInk)

    let unfinished = issues.filter {
      let status = $0.string("status")
      return status == "待处理" || status == "处理中"
    }.count
    drawText(
      copy.summary(total: issues.count, unfinished: unfinished),
      in: CGRect(x: 42, y: 411, width: 511, height: 52),
      font: .systemFont(ofSize: 10),
      color: pdfMuted
    )

    drawText(
      copy.text("内容仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见。"),
      in: CGRect(x: 42, y: 530, width: 511, height: 50),
      font: .systemFont(ofSize: 10),
      color: pdfMuted,
      alignment: .center
    )
  }

  private func aspectFit(_ imageSize: CGSize, inside rect: CGRect) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else { return rect }
    let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
    let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(
      x: rect.midX - size.width / 2,
      y: rect.midY - size.height / 2,
      width: size.width,
      height: size.height
    )
  }

  private func severityColor(_ value: String) -> UIColor {
    switch value {
    case "高": return pdfRisk
    case "中": return pdfPending
    default: return pdfMuted
    }
  }

  private func statusColor(_ value: String) -> UIColor {
    switch value {
    case "已完成": return pdfCompleted
    case "处理中": return pdfInProgress
    default: return pdfPending
    }
  }

  private func drawText(
    _ text: String,
    in rect: CGRect,
    font: UIFont,
    color: UIColor,
    alignment: NSTextAlignment = .left
  ) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 2
    (text as NSString).draw(
      in: rect,
      withAttributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
      ]
    )
  }
}

struct ReportCopy {
  let isEnglish: Bool

  init(languageCode: String) {
    isEnglish = languageCode.lowercased().hasPrefix("en")
  }

  func text(_ chinese: String) -> String {
    guard isEnglish else { return chinese }
    return Self.english[chinese] ?? chinese
  }

  func reportTitle(_ projectName: String) -> String {
    isEnglish ? "\(projectName) On-site Photo Records" : "\(projectName) 现场照片记录"
  }

  func footer(pageNumber: Int) -> String {
    isEnglish
      ? "For site communication and documentation only; not a professional assessment, acceptance decision, or legal opinion  ·  Page \(pageNumber)"
      : "仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见  ·  第 \(pageNumber) 页"
  }

  func severityPriority(_ severity: String) -> String {
    isEnglish ? "\(text(severity)) priority" : "\(severity)优先级"
  }

  func projectLine(_ projectName: String) -> String {
    isEnglish ? "Project: \(projectName)" : "项目：\(projectName)"
  }

  func summary(total: Int, unfinished: Int) -> String {
    isEnglish
      ? "At generation time, \(total) records were organized and \(unfinished) were marked unfinished. Generate again to reflect the latest content."
      : "截至生成时，共整理 \(total) 条记录，其中 \(unfinished) 条标记为尚未完成处理。再次生成时会反映最新内容。"
  }

  private static let english: [String: String] = [
    "缺少报告参数": "Missing report parameters",
    "报告数据格式错误": "Invalid report data",
    "找不到报告文件": "Report file not found",
    "文件选择器正在使用": "The file picker is already in use",
    "暂时无法打开文件选择器": "The file picker is temporarily unavailable",
    "语言设置无效": "Invalid language setting",
    "现场报告": "Site report",
    "现场情况记录": "Site condition records",
    "现场照片沟通记录": "On-site Photo Communication Record",
    "记录地点": "Location",
    "记录日期": "Record date",
    "记录人员": "Recorder",
    "未填写": "Not provided",
    "记录总数": "Total records",
    "待处理": "Pending",
    "处理中": "In progress",
    "已完成": "Completed",
    "高优先级": "High priority",
    "记录范围": "Recorded areas",
    "尚未记录区域": "No areas recorded",
    "内容仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见。":
      "For site communication and documentation only. This is not a professional assessment, acceptance decision, or legal opinion.",
    "补充照片": "Additional photos",
    "未设置": "Not set",
    "低": "Low",
    "中": "Medium",
    "高": "High",
    "位置": "Location",
    "负责人": "Assignee",
    "处理期限": "Due date",
    "照片说明": "Photo description",
    "此记录未附现场照片": "No site photos attached to this record",
    "处理前": "Before",
    "处理后": "After",
    "照片文件不可用": "Photo file unavailable",
    "补充说明": "Additional notes",
    "无": "None",
  ]
}

private extension UIColor {
  convenience init(photoReportHex hex: UInt32, alpha: CGFloat = 1) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: alpha
    )
  }

  var photoReportContrastingTextColor: UIColor {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      return .white
    }
    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
    return luminance > 0.5 ? .black : .white
  }
}

private extension Dictionary where Key == String, Value == Any {
  func string(_ key: String, fallback: String = "") -> String {
    let value = self[key] as? String ?? ""
    return value.isEmpty ? fallback : value
  }

  func bool(_ key: String) -> Bool {
    self[key] as? Bool ?? false
  }
}
