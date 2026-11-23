






import Foundation
import WebKit

@available(iOS 11.0, *)
final class STWebSchemeHandler: NSObject, WKURLSchemeHandler {

    static let shared = STWebSchemeHandler()
    /// Package resources may include images, WASM or media. Keep a bounded
    /// concurrent reader so one large asset cannot queue every Mini behind a
    /// single serial `Data(contentsOf:)` operation.
    private let resourceQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.stmini.installed-package-resource"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    private let taskStateLock = NSLock()
    private var activeTaskIDs = Set<ObjectIdentifier>()
    private let chunkSize = 64 * 1024

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        setTask(taskID, active: true)
        guard let requestURL = urlSchemeTask.request.url else {
            fail(urlSchemeTask, taskID: taskID, error: resourceError(STMiniLocalized("mini.resource_url_invalid", "小程序资源地址无效")))
            return
        }
        let miniWebView = webView as? STMiniWebView
        resourceQueue.addOperation { [weak self, weak miniWebView] in
            guard let self, self.isTaskActive(taskID) else { return }
            guard let miniWebView, let lease = miniWebView.boundResourceLease(requestURL) else {
                self.fail(urlSchemeTask, taskID: taskID, error: self.resourceError(STMiniLocalized("mini.resource_unavailable", "小程序资源不存在或未通过校验")))
                return
            }
            do {
                // The lease owns verified immutable bytes, never a lock.
                // WK task callbacks can synchronously enter the main runloop;
                // holding a package lock here would deadlock marker validation.
                try self.stream(lease.fileURL, requestURL: requestURL, to: urlSchemeTask, taskID: taskID) {
                    miniWebView.isCurrentBoundResourceLease(lease)
                }
            } catch {
                self.fail(urlSchemeTask, taskID: taskID, error: error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // WebKit can cancel a request while the serial reader is still waiting
        // on a previous asset. Mark it inactive so that late callbacks are
        // never sent to a stopped WKURLSchemeTask.
        onMain { setTask(ObjectIdentifier(urlSchemeTask as AnyObject), active: false) }
    }

    private func stream(_ fileURL: URL, requestURL: URL, to task: WKURLSchemeTask, taskID: ObjectIdentifier, identityIsCurrent: () -> Bool) throws {
        guard identityIsCurrent(), let input = InputStream(url: fileURL) else {
            throw resourceError(STMiniLocalized("mini.resource_unreadable", "小程序资源无法读取"))
        }
        guard let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              fileSize >= 0, fileSize <= 80 * 1024 * 1024 else { throw resourceError("Bound Mini resource exceeds its byte limit") }
        var receivedBytes = 0
        let mimeType = mimeType(for: fileURL.pathExtension)
        let encoding = mimeType.hasPrefix("text/") || mimeType.contains("javascript") || mimeType.contains("json") ? "utf-8" : nil
        let response = URLResponse(
            url: requestURL,
            mimeType: mimeType,
            expectedContentLength: fileSize,
            textEncodingName: encoding
        )
        guard deliverIfActive(task, taskID: taskID, identityIsCurrent: identityIsCurrent, block: { task.didReceive(response) }) else { return }

        input.open()
        defer { input.close() }
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        while isTaskActive(taskID) {
            guard identityIsCurrent() else { throw resourceError("Bound Mini package identity changed") }
            let count = input.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                guard identityIsCurrent() else { throw resourceError("Bound Mini package identity changed") }
                guard count <= fileSize - receivedBytes else { throw resourceError("Bound Mini resource size changed") }
                receivedBytes += count
                let chunk = Data(buffer[0..<count])
                guard deliverIfActive(task, taskID: taskID, identityIsCurrent: identityIsCurrent, block: { task.didReceive(chunk) }) else { return }
            } else if count == 0 {
                guard receivedBytes == fileSize else { throw resourceError("Bound Mini resource was truncated") }
                finish(task, taskID: taskID, identityIsCurrent: identityIsCurrent)
                return
            } else {
                throw input.streamError ?? resourceError(STMiniLocalized("mini.resource_read_failed", "小程序资源读取失败"))
            }
        }
    }

    /// Stop, ownership recheck and every WebKit callback share the main queue.
    /// All validation helpers return (and release their locks) before callbacks.
    private func onMain<T>(_ work: () -> T) -> T {
        if Thread.isMainThread { return work() }
        return DispatchQueue.main.sync(execute: work)
    }

    private func finish(_ task: WKURLSchemeTask, taskID: ObjectIdentifier, identityIsCurrent: () -> Bool) {
        onMain {
            guard isTaskActive(taskID) else { return }
            guard identityIsCurrent() else {
                fail(task, taskID: taskID, error: resourceError("Bound Mini package identity changed")); return
            }
            guard takeActiveTask(taskID) else { return }
            task.didFinish()
        }
    }

    private func fail(_ task: WKURLSchemeTask, taskID: ObjectIdentifier, error: Error) {
        onMain {
            guard takeActiveTask(taskID) else { return }
            task.didFailWithError(error)
        }
    }

    private func deliverIfActive(_ task: WKURLSchemeTask, taskID: ObjectIdentifier, identityIsCurrent: () -> Bool, block: () -> Void) -> Bool {
        onMain {
            guard isTaskActive(taskID) else { return false }
            guard identityIsCurrent() else {
                fail(task, taskID: taskID, error: resourceError("Bound Mini package identity changed")); return false
            }
            block()
            return true
        }
    }

    private func isTaskActive(_ taskID: ObjectIdentifier) -> Bool {
        taskStateLock.lock()
        defer { taskStateLock.unlock() }
        return activeTaskIDs.contains(taskID)
    }

    private func setTask(_ taskID: ObjectIdentifier, active: Bool) {
        taskStateLock.lock()
        defer { taskStateLock.unlock() }
        if active {
            activeTaskIDs.insert(taskID)
        } else {
            activeTaskIDs.remove(taskID)
        }
    }

    private func takeActiveTask(_ taskID: ObjectIdentifier) -> Bool {
        taskStateLock.lock()
        defer { taskStateLock.unlock() }
        guard activeTaskIDs.contains(taskID) else { return false }
        activeTaskIDs.remove(taskID)
        return true
    }

    private func resourceError(_ message: String) -> NSError {
        NSError(domain: "STMini.Resource", code: 404, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js", "mjs": return "application/javascript"
        case "json", "map": return "application/json"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "wasm": return "application/wasm"
        default: return "application/octet-stream"
        }
    }
}
