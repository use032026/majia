import CloudKit
import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testExpensePdfRendererPaginatesChineseContent() throws {
    let row: [String: Any] = [
      "occurredAt": "2026-08-17T08:00:00Z",
      "title": "东京晚餐与交通消费明细",
      "transactionAmount": "12800",
      "transactionCurrency": "JPY",
      "homeCurrency": "CNY",
      "rate": "0.05",
      "rateDate": "2026-08-17",
      "rateSource": "Frankfurter",
      "estimatedAmount": "640",
      "actualAmount": "645.50",
    ]
    let labels = [
      "originalAmount": "原币金额",
      "homeCurrency": "本位币",
      "rate": "汇率",
      "rateDate": "汇率日期",
      "source": "汇率来源",
      "estimated": "预计金额",
      "actual": "实际入账金额",
    ]
    let url = try ExpensePdfRenderer.render(document: [
      "filename": "expenses-中文.pdf",
      "title": "RhinoSmart 消费导出",
      "generatedAt": "2026年8月17日 16:00",
      "labels": labels,
      "rows": Array(repeating: row, count: 30),
      "disclaimer": "结果仅供参考，实际入账以最终处理结果为准。",
    ])
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }

    let data = try Data(contentsOf: url)
    XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
    let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
    XCTAssertGreaterThan(document.numberOfPages, 1)
  }

  func testExpensePdfRendererPaginatesLongSingleFieldsWithoutClipping() throws {
    let longText = String(repeating: "很长的商户名称与来源说明", count: 500)
    let row: [String: Any] = [
      "occurredAt": "2026-08-17T08:00:00Z",
      "title": longText,
      "category": "food",
      "entryType": "purchase",
      "transactionAmount": "12800",
      "transactionCurrency": "JPY",
      "homeCurrency": "CNY",
      "rate": "0.05",
      "rateDate": "2026-08-17",
      "rateSource": longText,
      "estimatedAmount": "640",
      "actualAmount": "645.50",
    ]
    let labels = [
      "category": "分类",
      "type": "类型",
      "originalAmount": "原币金额",
      "homeCurrency": "本位币",
      "rate": "汇率",
      "rateDate": "汇率日期",
      "source": "汇率来源",
      "estimated": "预计金额",
      "actual": "实际入账金额",
    ]

    let url = try ExpensePdfRenderer.render(document: [
      "filename": "long-fields.pdf",
      "title": "RhinoSmart 消费导出",
      "generatedAt": "2026年8月17日 16:00",
      "labels": labels,
      "rows": [row],
      "disclaimer": longText,
    ])
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }

    let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
    XCTAssertGreaterThan(document.numberOfPages, 2)
  }

  func testPreferredLanguagesUseOnlyDeviceSupportedValues() {
    let result = VisionOcrSupport.matchedLanguages(
      preferred: ["zh_Hans", "en", "fr-FR"],
      supported: ["en-US", "zh-Hans", "de-DE"]
    )

    XCTAssertEqual(result, ["zh-Hans", "en-US"])
  }

  func testImageOrientationDefaultsToUpAndReadsMetadata() {
    XCTAssertEqual(VisionOcrSupport.imageOrientation(from: nil), .up)
    XCTAssertEqual(
      VisionOcrSupport.imageOrientation(from: [
        kCGImagePropertyOrientation: NSNumber(value: CGImagePropertyOrientation.right.rawValue)
      ]),
      .right
    )
  }

  func testUnsupportedContractReturnsStructuredError() {
    let completed = expectation(description: "OCR rejects incompatible contract")
    let service = VisionOcrService()
    service.recognizeImage(
      request: OcrRequest(
        contractVersion: 99,
        imagePath: "/tmp/not-used.png",
        mode: .accurate,
        preferredLanguages: []
      )
    ) { result in
      guard case .failure(let error as PigeonError) = result else {
        XCTFail("Expected a PigeonError")
        completed.fulfill()
        return
      }
      XCTAssertEqual(error.code, "unsupported-contract")
      completed.fulfill()
    }
    wait(for: [completed], timeout: 1)
  }

  func testRecognizesProgrammaticallyRenderedPrice() throws {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 140)).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 480, height: 140))
      NSString(string: "TOTAL USD 12.50").draw(
        at: CGPoint(x: 20, y: 36),
        withAttributes: [
          .font: UIFont.systemFont(ofSize: 44, weight: .bold),
          .foregroundColor: UIColor.black,
        ]
      )
    }
    let imageUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent("vision-ocr-\(UUID().uuidString).png")
    try XCTUnwrap(image.pngData()).write(to: imageUrl)
    addTeardownBlock { try? FileManager.default.removeItem(at: imageUrl) }

    let completed = expectation(description: "Vision recognizes a rendered price")
    VisionOcrService().recognizeImage(
      request: OcrRequest(
        contractVersion: VisionOcrSupport.contractVersion,
        imagePath: imageUrl.path,
        mode: .accurate,
        preferredLanguages: ["en-US"]
      )
    ) { result in
      switch result {
      case .success(let value):
        XCTAssertTrue(
          value.candidates.map(\.text).joined(separator: " ").contains("12.50")
        )
      case .failure(let error):
        XCTFail("Unexpected OCR error: \(error)")
      }
      completed.fulfill()
    }
    wait(for: [completed], timeout: 10)
  }

  func testCloudRecordValidationRejectsReceiptPath() {
    let value = SyncRecord(
      contractVersion: CloudSyncSupport.contractVersion,
      id: "expense-1",
      recordType: "expense",
      schemaVersion: CloudSyncSupport.recordSchemaVersion,
      deviceId: "device-1",
      changeId: "change-1",
      payloadJson: "{\"id\":\"expense-1\",\"receipt_local_path\":\"private/image.jpg\"}",
      modifiedAtUtc: "2026-08-17T08:00:00Z",
      deleted: false
    )

    XCTAssertThrowsError(try CloudSyncSupport.validate(value)) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "invalid-record")
    }
  }

  func testCloudRecordValidationAcceptsSchemaVersionsOneAndTwo() {
    for schemaVersion: Int64 in [1, 2] {
      let value = SyncRecord(
        contractVersion: CloudSyncSupport.contractVersion,
        id: "trip-1",
        recordType: "trip",
        schemaVersion: schemaVersion,
        deviceId: "device-1",
        changeId: "change-1",
        payloadJson: "{\"id\":\"trip-1\"}",
        modifiedAtUtc: "2026-08-17T08:00:00Z",
        deleted: false
      )

      XCTAssertNoThrow(try CloudSyncSupport.validate(value))
    }
  }

  func testCloudRecordValidationRejectsFutureSchemaVersion() {
    let value = SyncRecord(
      contractVersion: CloudSyncSupport.contractVersion,
      id: "trip-1",
      recordType: "trip",
      schemaVersion: 3,
      deviceId: "device-1",
      changeId: "change-1",
      payloadJson: "{\"id\":\"trip-1\"}",
      modifiedAtUtc: "2026-08-17T08:00:00Z",
      deleted: false
    )

    XCTAssertThrowsError(try CloudSyncSupport.validate(value)) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "unsupported-record-schema")
    }
  }

  func testCloudErrorsMapWithoutExposingRecordDetails() {
    let quota = CloudSyncSupport.mappedError(CKError(.quotaExceeded))
    XCTAssertEqual(quota.code, "cloud-quota-exceeded")
    XCTAssertNil(quota.details)
  }

  func testCloudPushUsesDeterministicLastWriteWins() {
    let zoneID = CKRecordZone.ID(
      zoneName: "test-zone",
      ownerName: CKCurrentUserDefaultName
    )
    let existing = CKRecord(
      recordType: CloudSyncSupport.recordType,
      recordID: CKRecord.ID(recordName: "trip__one", zoneID: zoneID)
    )
    existing["modifiedAtUtc"] = "2026-08-17T08:00:00Z" as CKRecordValue
    existing["changeId"] = "change-b" as CKRecordValue

    let older = SyncRecord(
      contractVersion: CloudSyncSupport.contractVersion,
      id: "one",
      recordType: "trip",
      schemaVersion: CloudSyncSupport.recordSchemaVersion,
      deviceId: "device-1",
      changeId: "change-z",
      payloadJson: "{\"id\":\"one\"}",
      modifiedAtUtc: "2026-08-17T07:59:59Z",
      deleted: false
    )
    let equalTimeWinner = SyncRecord(
      contractVersion: CloudSyncSupport.contractVersion,
      id: "one",
      recordType: "trip",
      schemaVersion: CloudSyncSupport.recordSchemaVersion,
      deviceId: "device-2",
      changeId: "change-c",
      payloadJson: "{\"id\":\"one\"}",
      modifiedAtUtc: "2026-08-17T08:00:00Z",
      deleted: false
    )

    XCTAssertFalse(CloudSyncSupport.incomingWins(older, over: existing))
    XCTAssertTrue(CloudSyncSupport.incomingWins(equalTimeWinner, over: existing))
  }
}
