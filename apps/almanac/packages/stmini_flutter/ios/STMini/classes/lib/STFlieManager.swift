






import Foundation

public class STFlieManager: NSObject {
    
    
    @objc public class func createDirectory(path: String!) {
        var isDirectory: ObjCBool = ObjCBool(true)
        let isExist = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if !isExist {
          do {
              try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
          } catch {
              STProjectHelper.Log("文件夹创建失败：\n 路径：\(String(describing: path)) \n 错误：\(error)")
          }
        }
    }
    
    
    @objc public class func deleteDirectory(path: String!) {
        var isDirectory: ObjCBool = ObjCBool(true)
        let isExist = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if isExist {
          do {
              try FileManager.default.removeItem(atPath: path)
          } catch {
              STProjectHelper.Log("文件夹删除失败：\n 路径：\(String(describing: path)) \n 错误：\(error)")
          }
        }
    }
    
    
    @objc public class func deleteFile(path: String!) {
        var isDirectory: ObjCBool = ObjCBool(false)
        let isExist = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if isExist {
          do {
              try FileManager.default.removeItem(atPath: path)
          } catch {
              STProjectHelper.Log("文件删除失败：\n 路径：\(String(describing: path)) \n 错误：\(error)")
          }
        }
    }
    
    
    @objc public class func isDirectoryExist(path: String!) -> Bool {
        var isDirectory: ObjCBool = ObjCBool(true)
        let isExist = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isExist
    }
    
    
    @objc public class func isFileExist(path: String!) -> Bool {
        var isDirectory: ObjCBool = ObjCBool(false)
        let isExist = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isExist
    }
    
    
    @objc public class func copyFile(from: String!, to: String!) {
        do {
            try  FileManager.default.copyItem(atPath: from, toPath: to)
        }
        catch {
            STProjectHelper.Log("拷贝文件失败：\n 路径：\(String(describing: from)) \n 错误：\(error)")
        }
    }

}
