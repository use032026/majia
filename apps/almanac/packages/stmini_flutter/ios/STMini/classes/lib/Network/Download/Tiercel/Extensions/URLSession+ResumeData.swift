

























import Foundation

extension URLSession {
    
    
    
    
    
    internal func correctedDownloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
        
        let task = downloadTask(withResumeData: resumeData)
        
        if let resumeDictionary = TRResumeDataHelper.getResumeDictionary(resumeData) {
            if task.originalRequest == nil, let originalReqData = resumeDictionary[NSURLSessionResumeOriginalRequest] as? Data, let originalRequest = NSKeyedUnarchiver.unarchiveObject(with: originalReqData) as? NSURLRequest {
                task.setValue(originalRequest, forKey: "originalRequest")
            }
            if task.currentRequest == nil, let currentReqData = resumeDictionary[NSURLSessionResumeCurrentRequest] as? Data, let currentRequest = NSKeyedUnarchiver.unarchiveObject(with: currentReqData) as? NSURLRequest {
                task.setValue(currentRequest, forKey: "currentRequest")
            }
        }
        
        return task
    }
}
