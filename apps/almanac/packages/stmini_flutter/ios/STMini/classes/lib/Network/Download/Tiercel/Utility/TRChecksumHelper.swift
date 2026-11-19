

























import Foundation

public enum TRVerificationType : Int {
    case md5
    case sha1
    case sha256
    case sha512
}

public class TRChecksumHelper {
    
    public class func validateFile(_ filePath: String,
                                   verificationCode: String,
                                   verificationType: TRVerificationType,
                                   completion: @escaping (Bool) -> ()) {
        if verificationCode.isEmpty {
            TiercelLog("verification code is empty")
            completion(false)
            return
        }
        DispatchQueue.global().async {
            guard FileManager.default.fileExists(atPath: filePath) else {
                TiercelLog("file does not exist, filePath: \(filePath)")
                completion(false)
                return
            }
            let url = URL(fileURLWithPath: filePath)

            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                var string: String
                switch verificationType {
                case .md5:
                    string = data.tr.md5
                case .sha1:
                    string = data.tr.sha1
                case .sha256:
                    string = data.tr.sha256
                case .sha512:
                    string = data.tr.sha512
                }
                let isCorrect = string.lowercased() == verificationCode.lowercased()
                completion(isCorrect)
            } catch {
                TiercelLog("can't read data, error: \(error)")
                completion(false)
            }
        }
    }
}






