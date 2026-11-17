import PDFKit
import UIKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testEnglishReportCopyUsesEnglishLabels() {
    let copy = ReportCopy(languageCode: "en")
    XCTAssertEqual(copy.reportTitle("Sample Site"), "Sample Site On-site Photo Records")
    XCTAssertEqual(copy.severityPriority("高"), "High priority")
    XCTAssertEqual(copy.projectLine("Sample Site"), "Project: Sample Site")
  }

  func testGeneratesEnglishReportText() throws {
    let project: [String: Any] = [
      "name": "Sample Site",
      "address": "8 Market Street",
      "inspectionDate": "2026-08-27",
    ]
    let issues: [[String: Any]] = [[
      "code": "A-001",
      "room": "Lobby",
      "location": "East wall",
      "category": "Wall crack",
      "severity": "高",
      "status": "待处理",
      "description": "A visible crack requires follow-up.",
      "photos": [],
    ]]
    let options: [String: Any] = [
      "layout": "concise",
      "includePosition": true,
      "includeStatus": true,
      "includeSeverity": true,
      "includeAssignee": false,
      "includeDueDate": false,
      "includeProjectDetails": false,
      "includeNotes": false,
    ]

    let reportURL = try AppDelegate().generateReport(
      project: project,
      issues: issues,
      options: options,
      copy: ReportCopy(languageCode: "en")
    )
    defer { try? FileManager.default.removeItem(at: reportURL) }

    let document = try XCTUnwrap(PDFDocument(url: reportURL))
    XCTAssertEqual(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String, "JOVFX")
    let text = (0..<document.pageCount)
      .compactMap { document.page(at: $0)?.string }
      .joined(separator: "\n")
    XCTAssertTrue(text.contains("High priority"))
    XCTAssertTrue(text.contains("Pending"))
    XCTAssertTrue(text.contains("Photo description"))
    XCTAssertTrue(text.contains("No site photos attached to this record"))

    let issuePage = try XCTUnwrap(document.page(at: 0))
    let prioritySelection = try XCTUnwrap(
      document.findString("High priority", withOptions: []).first
    )
    let statusSelection = try XCTUnwrap(
      document.findString("Pending", withOptions: []).first
    )
    XCTAssertEqual(
      prioritySelection.bounds(for: issuePage).midY,
      statusSelection.bounds(for: issuePage).midY,
      accuracy: 1
    )
  }

  func testGeneratesAnnotatedChineseReport() throws {
    let imageURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("photo-report-test.jpg")
    let image = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 180)).image { context in
      UIColor(red: 0.84, green: 0.84, blue: 0.81, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
      UIColor(red: 0.54, green: 0.56, blue: 0.53, alpha: 1).setFill()
      context.fill(CGRect(x: 55, y: 25, width: 210, height: 130))
    }
    try XCTUnwrap(image.jpegData(compressionQuality: 0.9)).write(to: imageURL)

    let project: [String: Any] = [
      "name": "云栖花园验收",
      "address": "8号楼1202室",
      "companyName": "现场质量检查",
      "inspectorName": "张工",
      "clientName": "李先生",
      "inspectionDate": "2026-08-26",
      "notes": "整改完成后复验。",
    ]
    let issues: [[String: Any]] = [[
      "code": "A-007",
      "room": "主卫",
      "location": "东侧墙面",
      "category": "瓷砖空鼓",
      "severity": "中",
      "status": "待整改",
      "description": "距地面约1.2米处检测到空鼓",
      "assignee": "施工方",
      "dueDate": "2026-09-05",
      "photos": [[
        "path": imageURL.path,
        "phase": "整改前",
        "annotations": [
          ["kind": "rectangle", "x1": 0.15, "y1": 0.2, "x2": 0.75, "y2": 0.8, "text": "", "color": 0xFF22C55E],
          ["kind": "arrow", "x1": 0.1, "y1": 0.1, "x2": 0.4, "y2": 0.45, "text": "", "color": 0xFF2F80ED],
          ["kind": "text", "x1": 0.46, "y1": 0.2, "x2": 0.46, "y2": 0.2, "text": "空鼓处", "color": 0xFFFFFFFF],
        ],
      ]],
    ]]

    let reportURL = try AppDelegate().generateReport(project: project, issues: issues)
    defer {
      try? FileManager.default.removeItem(at: imageURL)
      try? FileManager.default.removeItem(at: reportURL)
    }

    let data = try Data(contentsOf: reportURL)
    XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
    XCTAssertGreaterThan(data.count, 10_000)

    let document = try XCTUnwrap(PDFDocument(url: reportURL))
    XCTAssertEqual(document.pageCount, 3)
    let text = (0..<document.pageCount)
      .compactMap { document.page(at: $0)?.string }
      .joined(separator: "\n")
    XCTAssertTrue(text.contains("A-007"))
    XCTAssertTrue(text.contains("主卫"))
    XCTAssertTrue(text.contains("瓷砖空鼓"))
  }
}
