






import Foundation
import UIKit



public struct STWebResourceManager {

    private struct MiniPackageManifest: Codable {
        let miniId: String
        let miniName: String?
        let miniNameEn: String?
        let version: String
        let entry: String
        let icon: String
        /// Quant Mini packages use this for their brand/channel authorization.
        /// It is intentionally optional for ordinary Mini packages.
        let channel: String?
        /// "1": the Mini checks its own version; "0": it calls the host
        /// update-check JS API. Omitted legacy manifests default to "1".
        let updateself: String?
        /// "1" makes the Mini root replace the host surface: it has no
        /// native capsule and cannot be dismissed with the root edge swipe.
        /// Omitted values keep the normal Mini presentation.
        let ishome: String?
    }

    /// The locally installed record is derived only from the package manifest.
    /// It is read without migration, repair or remote package installation.
    private struct InstalledMiniPackageRecord: Codable {
        let miniId: String
        let version: String
        let entry: String
        /// Optional package-specific channel metadata. Ordinary Mini packages
        /// do not need to declare a channel.
        let channel: String?
        /// Last successful mini:// source link. Optional for packages created
        /// before this field existed or through descriptor-only installation.
        var launchLink: String?
    }

    private static let installedMetadataFileName = ".st-mini-package.json"
    private static let packageManifestFileName = "mini-manifest.json"
    /// WKURLSchemeHandler cannot take over http(s), so verified downloaded
    /// packages use STMini's own origin.  The host is the verified miniId:
    /// `stmini://asterquant.stmini.local/index.html`.  Root and package-owned
    /// child pages therefore share one origin, while different Minis never
    /// share Web Storage or cached relative resources. Cookie behavior for a
    /// custom URL scheme is WebKit-owned and must not be used as package state.
    static let installedMiniResourceScheme = "stmini"
    private static let installedMiniResourceHostSuffix = ".stmini.local"
    
    
    
    
    
    
    public static func imageNamed(name: String) -> UIImage? {
        guard !name.isEmpty else {
            return nil
        }

        // Resource.bundle is a plain nested resource directory (it has no
        // Info.plist), so creating a Bundle from it is not reliable across
        // static and dynamic CocoaPods integrations. Resolve it by its real
        // directory URL first; keep UIImage's normal bundle lookup as a
        // compatibility fallback for future resource layouts.
        let image = imageFromResourceDirectory(named: name)
            ?? Bundle.STMiniBundle.flatMap { UIImage(named: name, in: $0, compatibleWith: nil) }

        return image?.withRenderingMode(.alwaysOriginal)
    }

    private static func imageFromResourceDirectory(named name: String) -> UIImage? {
        guard let resourceDirectoryURL = resourceDirectoryURL() else {
            return nil
        }

        let fileName = (name as NSString).deletingPathExtension
        let suppliedExtension = (name as NSString).pathExtension
        let extensions = suppliedExtension.isEmpty ? ["png"] : [suppliedExtension]
        let baseNames = [fileName, "\(fileName)@2x", "\(fileName)@3x"]

        for baseName in baseNames {
            for fileExtension in extensions {
                let fileURL = resourceDirectoryURL
                    .appendingPathComponent(baseName)
                    .appendingPathExtension(fileExtension)
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let image = UIImage(contentsOfFile: fileURL.path) {
                    return image
                }
            }
        }
        return nil
    }

    private static func resourceDirectoryURL() -> URL? {
        let ownerBundle = Bundle(for: STMiniWebView.self)
        let rootURLs = [ownerBundle.resourceURL, Bundle.main.resourceURL].compactMap { $0 }
        let relativePaths = ["STMini.bundle/Resource.bundle", "Resource.bundle"]

        for rootURL in rootURLs {
            for relativePath in relativePaths {
                let candidateURL = rootURL.appendingPathComponent(relativePath, isDirectory: true)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    return candidateURL
                }
            }
        }
        return nil
    }
    
    
    
    
    
    
    
    
    static func miniNameHandle(name: String) -> (String?, String?) {
        
        var miniName = name
        
        var pathParams = ""
        if miniName.contains("#") {
            miniName = name.components(separatedBy: "#").first!
        }
        pathParams = name.replacingOccurrences(of: miniName, with: "")
        return (miniName, pathParams)
    }
    
    
    
    
    
    
    
    static func isMiniProgramExist(name: String) -> Bool {
        
        let (miniName, _) = STWebResourceManager.miniNameHandle(name: name)
        
        var miniPath = NSHomeDirectory() + "/Documents/STMini"
        
        miniPath = miniPath + "/\(miniName!)"
        
        let isExist = STFlieManager.isDirectoryExist(path: miniPath)
        return isExist
    }

    /// A local package is valid only if its entry, packaged manifest and the
    /// installed online descriptor all agree. A mere directory is not enough.
    static func isInstalledMiniPackageUsable(name: String) -> Bool {
        guard let miniName = miniNameHandle(name: name).0, isSafeMiniName(miniName),
              let packages = try? LocalPackageInventory(home: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)).read(check: {}) else { return false }
        // Revalidate on every use. A previous positive cache cannot authorize
        // a modified record, manifest, path or symbolic link.
        return packages.contains { $0["miniId"] == miniName }
    }

    static func installedMiniPackageEntry(name: String) -> String? {
        guard let miniName = miniNameHandle(name: name).0,
              isInstalledMiniPackageUsable(name: miniName),
              let manifest = packageManifest(name: miniName) else {
            return nil
        }
        return manifest.entry
    }

    /// Resolves a package-owned secondary page without allowing a Mini to
    /// escape its verified directory. Query and fragment are retained. The
    /// returned resource URL has the same isolated origin as the Mini root.
    static func installedMiniPackageLocalPageURL(name: String, path: String) -> URL? {
        guard let miniName = miniNameHandle(name: name).0,
              isInstalledMiniPackageUsable(name: miniName),
              let components = URLComponents(string: path.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == nil,
              components.host == nil,
              isSafeEntryPath(components.path),
              !components.path.split(separator: "/").contains(".") else {
            return nil
        }
        guard installedMiniPackageResourceURL(name: miniName, relativePath: components.path) != nil else {
            return nil
        }
        return installedMiniPackageResourceURL(
            miniId: miniName,
            relativePath: components.path,
            query: components.query,
            fragment: components.fragment
        )
    }

    /// Root entry URL for an already verified downloaded Mini package.
    static func installedMiniPackageRootURL(name: String, entry: String) -> URL? {
        guard let miniName = miniNameHandle(name: name).0,
              isInstalledMiniPackageUsable(name: miniName),
              isSafeEntryPath(entry),
              installedMiniPackageResourceURL(name: miniName, relativePath: entry) != nil else {
            return nil
        }
        let pathParams = miniNameHandle(name: name).1 ?? ""
        let fragment = pathParams.hasPrefix("#") ? String(pathParams.dropFirst()) : nil
        return installedMiniPackageResourceURL(miniId: miniName, relativePath: entry, query: nil, fragment: fragment)
    }

    /// Resolves an STMini internal resource request to a single regular file
    /// within its owning verified package. It is intentionally the only path
    /// resolver used by both the root page and `mini_navigateTo` children.
    static func installedMiniPackageResourceURL(forInternalURL url: URL) -> URL? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == installedMiniResourceScheme, parts.user == nil, parts.password == nil, parts.port == nil,
              let host = parts.host?.lowercased(), host.hasSuffix(installedMiniResourceHostSuffix) else { return nil }
        let miniName = String(host.dropLast(installedMiniResourceHostSuffix.count))
        parts.query = nil; parts.fragment = nil; parts.host = host
        guard let plain = parts.url,
              let relativePath = LocalMiniResource.decodePath(plain, scheme: installedMiniResourceScheme, host: host) else { return nil }
        return installedMiniPackageResourceURL(name: miniName, relativePath: relativePath)
    }

    static func installedMiniPackageVersion(name: String) -> String? {
        guard let miniName = miniNameHandle(name: name).0,
              isInstalledMiniPackageUsable(name: miniName) else {
            return nil
        }
        return installedRecord(name: miniName)?.version
    }

    /// Reads the verified package's update owner. Existing packages that
    /// predate this field remain self-updating for backward compatibility.
    static func installedMiniPackageUpdateSelf(name: String) -> String? {
        guard let miniName = miniNameHandle(name: name).0,
              isInstalledMiniPackageUsable(name: miniName),
              let manifest = packageManifest(name: miniName) else {
            return nil
        }
        return manifest.updateself?.trimmingCharacters(in: .whitespacesAndNewlines) == "0" ? "0" : "1"
    }

    /// Root-only presentation policy read from the package itself.  Link
    /// parameters must never be able to make a Mini impersonate the App home.
    /// Installed packages are already integrity-checked; bundled local Minis
    /// use the same optional manifest field when one is present.
    static func miniPackageIsHome(name: String) -> Bool {
        guard let miniName = miniNameHandle(name: name).0,
              isSafeMiniName(miniName) else {
            return false
        }
        let manifest: MiniPackageManifest?
        if isInstalledMiniPackageUsable(name: miniName) {
            manifest = packageManifest(name: miniName)
        } else if let bundlePath = Bundle.main.path(forResource: miniName, ofType: nil) {
            let localManifestURL = URL(fileURLWithPath: bundlePath)
                .appendingPathComponent(packageManifestFileName)
            manifest = (try? Data(contentsOf: localManifestURL)).flatMap {
                try? JSONDecoder().decode(MiniPackageManifest.self, from: $0)
            }
        } else {
            manifest = nil
        }
        return manifest?.miniId == miniName
            && manifest?.ishome?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    static func installedMiniPackageLaunchLink(name: String) -> String? {
        guard let miniName = miniNameHandle(name: name).0,
              isInstalledMiniPackageUsable(name: miniName) else {
            return nil
        }
        return installedRecord(name: miniName)?.launchLink
    }



    /// Remote package mutation is unavailable; inspect every supplied intent.
    static func requestsPackageMutation(parameters: [String: String]?) -> Bool {
        let keys = ["downloadUrl", "downloadURL", "download_url", "__st_force_self_update", "isforce", "isForce", "forceUpdate"]
        return keys.contains { !(parameters?[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
    }

    static func requestsPackageMutation(link: String) -> Bool {
        let keys: Set<String> = ["downloadUrl", "downloadURL", "download_url", "__st_force_self_update", "isforce", "isForce", "forceUpdate"]
        return URLComponents(string: link)?.queryItems?.contains {
            keys.contains($0.name) && !($0.value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        } ?? false
    }

    static func isInstalledMiniPackageRunnable(link: String) -> Bool {
        guard let components = URLComponents(string: link), let miniId = components.host,
              !requestsPackageMutation(link: link) else { return false }
        // Match the existing Mini opener: last non-empty duplicate wins,
        // then a non-blank canonical value takes precedence over its alias.
        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value, !value.isEmpty { params[item.name] = value }
        }
        func parameter(_ canonical: String, alias: String) -> String? {
            for key in [canonical, alias] {
                if let value = params[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
            }
            return nil
        }
        return isInstalledMiniPackageRunnable(name: miniId,
            currentVersion: parameter("currentVersion", alias: "current_version"),
            minSupportVersion: parameter("minSupportVersion", alias: "min_support_version"))
    }

    static func isInstalledMiniPackageRunnable(name: String, currentVersion: String?, minSupportVersion: String?) -> Bool {
        guard let installed = installedMiniPackageVersion(name: name) else { return false }
        func normalized(_ value: String?) -> String? {
            guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        guard let floor = normalized(minSupportVersion) ?? normalized(currentVersion) else { return true }
        return compareMiniPackageVersion(installed, floor) >= 0
    }



    static func compareMiniPackageVersion(_ lhs: String, _ rhs: String) -> Int {
        compareVersion(lhs, rhs)
    }

    static func installedMiniPackageDisplayName(name: String) -> String? {
        guard isInstalledMiniPackageUsable(name: name) else { return nil }
        return packageManifest(name: name)?.miniName
    }

    /// A generated Home Grid entry contains only `mini://<miniId>`. The
    /// native loading screen therefore reads the localized package identity
    /// from the verified manifest rather than depending on scan query fields.
    static func installedMiniPackagePreferredDisplayName(name: String, preferEnglish: Bool) -> String? {
        guard isInstalledMiniPackageUsable(name: name), let manifest = packageManifest(name: name) else {
            return nil
        }
        if preferEnglish, let englishName = manifest.miniNameEn?.trimmingCharacters(in: .whitespacesAndNewlines), !englishName.isEmpty {
            return englishName
        }
        return manifest.miniName
    }

    static func installedMiniPackageIconURL(name: String) -> URL? {
        guard let miniName = miniNameHandle(name: name).0,
              isInstalledMiniPackageUsable(name: miniName),
              let icon = packageManifest(name: miniName)?.icon else {
            return nil
        }
        return packageDirectoryURL(name: miniName).appendingPathComponent(icon)
    }

    /// Installs an archive addressed by a mini:// link. The package manifest
    /// is the version source of truth after download. The archive is unpacked in a
    /// staging directory and atomically swapped into place only after its ID,
    /// entry, icon and channel are validated.


    private static func miniRootDirectoryURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/STMini", isDirectory: true)
    }

    private static func packageDirectoryURL(name: String) -> URL {
        miniRootDirectoryURL().appendingPathComponent(name, isDirectory: true)
    }







    /// Build the public URL only after the corresponding on-disk regular file
    /// has passed the same package-boundary validation as every resource load.
    private static func installedMiniPackageResourceURL(
        miniId: String,
        relativePath: String,
        query: String?,
        fragment: String?
    ) -> URL? {
        guard installedMiniPackageResourceURL(name: miniId, relativePath: relativePath) != nil else {
            return nil
        }
        var components = URLComponents()
        components.scheme = installedMiniResourceScheme
        components.host = "\(miniId.lowercased())\(installedMiniResourceHostSuffix)"
        components.path = "/\(relativePath)"
        components.query = query
        components.fragment = fragment
        return components.url
    }

    private static func installedMiniPackageResourceURL(name: String, relativePath: String) -> URL? {
        guard isSafeMiniName(name), LocalPackageInventory.safePath(relativePath),
              let record = installedRecord(name: name) else { return nil }
        return try? LocalPackageInventory(home: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
            .verifiedResource(miniId: name, version: record.version, entry: record.entry, path: relativePath, check: {})
    }

    private static func installedRecord(name: String) -> InstalledMiniPackageRecord? {
        let url = packageDirectoryURL(name: name).appendingPathComponent(installedMetadataFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(InstalledMiniPackageRecord.self, from: data)
    }

    private static func packageManifest(name: String) -> MiniPackageManifest? {
        let url = packageDirectoryURL(name: name).appendingPathComponent(packageManifestFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MiniPackageManifest.self, from: data)
    }







    private static func isSafeMiniName(_ value: String) -> Bool {
        !value.isEmpty && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }

    private static func isValidUpdateSelf(_ value: String?) -> Bool {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return true
        }
        return value == "0" || value == "1"
    }

    private static func isSafeEntryPath(_ value: String) -> Bool {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.contains("\\") else { return false }
        return !value.split(separator: "/").contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
    }

    private static func compareVersion(_ lhs: String, _ rhs: String) -> Int {
        let left = lhs.split(separator: "-", maxSplits: 1).first?.split(separator: ".").map { Int($0) ?? 0 } ?? []
        let right = rhs.split(separator: "-", maxSplits: 1).first?.split(separator: ".").map { Int($0) ?? 0 } ?? []
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? -1 : 1 }
        }
        return 0
    }
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    static func miniProgramPath(name: String, entry: String = "index.html") -> (String?, String?) {
        
        let (miniName, pathParams) = STWebResourceManager.miniNameHandle(name: name)
        
        var miniPath = NSHomeDirectory() + "/Documents/STMini"
        
        miniPath = miniPath + "/\(miniName!)"
        
        return ("file://" + miniPath + "/" + entry + pathParams!, "file://" + miniPath)
    }
    
    
    
    
    
    
    
    static func localMiniProgramPath(name: String) -> (String?, String?) {
        
        let (miniName, pathParams) = STWebResourceManager.miniNameHandle(name: name)
        
        guard let path = Bundle.main.path(forResource: "\(miniName!)", ofType: nil) else {
            return ("", "")
        }
        












        return ("file://" + path + "/index.html" + pathParams!, "file://" + path)
    }
    
}

/// Read-only registry for packages that have completed STMini's installed
/// package integrity checks. It lives in this source file intentionally: the
/// existing CocoaPods target already compiles this file, so the API is also
/// available to Objective-C hosts without a Pod project regeneration.
@objcMembers
public final class STMiniPackageInfo: NSObject {
    public let miniId: String
    public let miniName: String
    public let iconURL: String
    public let launchLink: String

    init(miniId: String, miniName: String, iconURL: String, launchLink: String) {
        self.miniId = miniId
        self.miniName = miniName
        self.iconURL = iconURL
        self.launchLink = launchLink
        super.init()
    }
}

@objcMembers
public final class STMiniPackageRegistry: NSObject {
    private static let installedPackagesDidChangeNotification = Notification.Name("STMiniPackageRegistryDidChangeNotification")

    /// Objective-C hosts subscribe using this name, rather than duplicating a
    /// string literal in every host integration.
    public class func installedPackagesDidChangeNotificationName() -> String {
        installedPackagesDidChangeNotification.rawValue
    }

    /// Sent on the main thread after a package has passed validation and is
    /// atomically available under Documents/STMini/<miniId>.
    class func postInstalledPackagesDidChange(miniId: String, version: String) {
        NotificationCenter.default.post(
            name: installedPackagesDidChangeNotification,
            object: nil,
            userInfo: ["miniId": miniId, "version": version]
        )
    }

    /// Returns only runnable packages. Failed-download staging directories and
    /// incomplete packages are intentionally absent from this list.
    public class func installedPackages() -> [STMiniPackageInfo] {
        let rootURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/STMini", isDirectory: true)
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return children.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }
            let miniId = url.lastPathComponent
            guard STWebResourceManager.isInstalledMiniPackageUsable(name: miniId) else {
                return nil
            }
            let miniName = STWebResourceManager.installedMiniPackageDisplayName(name: miniId) ?? miniId
            let iconURL = STWebResourceManager.installedMiniPackageIconURL(name: miniId)?.absoluteString ?? ""
            let version = STWebResourceManager.installedMiniPackageVersion(name: miniId) ?? ""
            let launchLink = "mini://\(miniId)?currentVersion=\(version)"
            return STMiniPackageInfo(miniId: miniId, miniName: miniName, iconURL: iconURL, launchLink: launchLink)
        }
        .sorted { $0.miniId.localizedStandardCompare($1.miniId) == .orderedAscending }
    }
}
