

























import UIKit

public class TRCache {
    
    public static let `default` = TRCache("default")
    
    private let ioQueue: DispatchQueue
    
    public let downloadPath: String

    public let downloadTmpPath: String
    
    public let downloadFilePath: String
    
    public let name: String
    
    private let fileManager = FileManager.default
    
    private final class func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    
    
    
    
    
    
    public init(_ name: String) {
        self.name = name
        
        let ioQueueName = "com.Daniels.Tiercel.Cache.ioQueue.\(name)"
        ioQueue = DispatchQueue(label: ioQueueName)
        
        let cacheName = "com.Daniels.Tiercel.Cache.\(name)"
        
        let diskCachePath = TRCache.defaultDiskCachePathClosure(cacheName)
        
        downloadPath = (diskCachePath as NSString).appendingPathComponent("Downloads")

        downloadTmpPath = (downloadPath as NSString).appendingPathComponent("Tmp")
        
        downloadFilePath = (downloadPath as NSString).appendingPathComponent("File")
        
        createDirectory()
        
    }

}



extension TRCache {
    internal func createDirectory() {

        if !fileManager.fileExists(atPath: downloadTmpPath) {
            do {
                try fileManager.createDirectory(atPath: downloadTmpPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                TiercelLog("createDirectory error: \(error)")
            }
        }
        
        if !fileManager.fileExists(atPath: downloadFilePath) {
            do {
                try fileManager.createDirectory(atPath: downloadFilePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                TiercelLog("createDirectory error: \(error)")
            }
        }
    }
    
    
    public func filePath(fileName: String) -> String? {
        if fileName.isEmpty {
            return nil
        }
        let path = (downloadFilePath as NSString).appendingPathComponent(fileName)
        return path
    }
    
    public func fileURL(fileName: String) -> URL? {
        guard let path = filePath(fileName: fileName) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    public func fileExists(fileName: String) -> Bool {
        guard let path = filePath(fileName: fileName) else { return false }
        return fileManager.fileExists(atPath: path)
    }
    
    public func filePath(URLString: String) -> String? {
        guard let url = URL(string: URLString) else { return nil }
        let fileName = url.tr.fileName
        return filePath(fileName: fileName)
    }
    
    public func fileURL(URLString: String) -> URL? {
        guard let path = filePath(URLString: URLString) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    public func fileExists(URLString: String) -> Bool {
        guard let path = filePath(URLString: URLString) else { return false }
        return fileManager.fileExists(atPath: path)
    }
    
    
    
    public func clearDiskCache() {
        ioQueue.async {
            guard self.fileManager.fileExists(atPath: self.downloadPath) else { return }
            do {
                try self.fileManager.removeItem(atPath: self.downloadPath)
            } catch {
                TiercelLog("removeItem error: \(error)")
            }
            self.createDirectory()
        }
    }
}



extension TRCache {
    internal func retrieveAllTasks() -> [TRTask]? {
        let path = (self.downloadPath as NSString).appendingPathComponent("\(self.name)Tasks.plist")
        
        let tasks = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? [TRTask]
        tasks?.forEach({ (task) in
            task.cache = self
            if task.status == .waiting || task.status == .running {
                task.status = .suspended
            }
        })
        return tasks
    }

    internal func retrievTmpFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let path1 = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            guard self.fileManager.fileExists(atPath: path1) else { return }

            if self.fileManager.fileExists(atPath: path2) {
                do {
                    try self.fileManager.removeItem(atPath: path1)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            } else {
                do {
                    try self.fileManager.moveItem(atPath: path1, toPath: path2)
                } catch {
                    TiercelLog("moveItem error: \(error)")
                }
            }
        }
    }


}



extension TRCache {
    internal func storeTasks(_ tasks: [TRTask]) {
        ioQueue.sync {
            let path = (self.downloadPath as NSString).appendingPathComponent("\(self.name)Tasks.plist")
            NSKeyedArchiver.archiveRootObject(tasks, toFile: path)
        }
    }
    
    internal func storeFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            guard let location = task.tmpFileURL else { return }
            let destination = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
            do {
                try self.fileManager.moveItem(at: location, to: URL(fileURLWithPath: destination))
            } catch {
                TiercelLog("moveItem error: \(error)")
            }
        }
    }
    
    internal func storeTmpFile(_ task: TRDownloadTask) {
        ioQueue.sync {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let tmpPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            let destination = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: destination) {
                do {
                    try self.fileManager.removeItem(atPath: destination)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }
            if self.fileManager.fileExists(atPath: tmpPath) {
                do {
                    try self.fileManager.copyItem(atPath: tmpPath, toPath: destination)
                } catch {
                    TiercelLog("copyItem error: \(error)")
                }
            }
        }
    }
    
    
}



extension TRCache {
    internal func remove(_ task: TRDownloadTask, completely: Bool) {
        removeTmpFile(task)
        
        if completely {
            removeFile(task)
        }
    }
    
    internal func removeFile(_ task: TRDownloadTask) {
        ioQueue.async {
            if task.fileName.isEmpty { return }
            let path = (self.downloadFilePath as NSString).appendingPathComponent(task.fileName)
            if self.fileManager.fileExists(atPath: path) {
                do {
                    try self.fileManager.removeItem(atPath: path)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }
        }
    }
    

    
    
    
    
    internal func removeTmpFile(_ task: TRDownloadTask) {
        ioQueue.async {
            guard let tmpFileName = task.tmpFileName, !tmpFileName.isEmpty else { return }
            let path1 = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: path1) {
                do {
                    try self.fileManager.removeItem(atPath: path1)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }

            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            if self.fileManager.fileExists(atPath: path2) {
                do {
                    try self.fileManager.removeItem(atPath: path2)
                } catch {
                    TiercelLog("removeItem error: \(error)")
                }
            }
        }
    }
}

extension URL: TiercelCompatible { }
extension Tiercel where Base == URL {
    public var fileName: String {
        var fileName = base.absoluteString.tr.md5
        if !base.pathExtension.isEmpty {
            fileName += ".\(base.pathExtension)"
        }
        return fileName
    }
}
