

























import UIKit

internal class TRSessionDelegate: NSObject {
    internal var manager: TRManager?

}


extension TRSessionDelegate: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        manager?.didBecomeInvalidWithError(error)
    }
    
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        manager?.didFinishEvents(forBackgroundURLSession: session)
    }
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let manager = manager,
            let currentURLString = downloadTask.currentRequest?.url?.absoluteString,
            let task = manager.fetchTask(currentURLString: currentURLString) as? TRDownloadTask
            else { return }
        task.didWriteData(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let manager = manager,
            let currentURLString = downloadTask.currentRequest?.url?.absoluteString,
            let task = manager.fetchTask(currentURLString: currentURLString) as? TRDownloadTask
            else { return }
        task.didFinishDownloadingTo(location: location)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let manager = manager,
            let currentURLString = task.currentRequest?.url?.absoluteString,
            let downloadTask = manager.fetchTask(currentURLString: currentURLString) as? TRDownloadTask
            else { return }
        downloadTask.didComplete(task: task, error: error)
    }
    
    
}
