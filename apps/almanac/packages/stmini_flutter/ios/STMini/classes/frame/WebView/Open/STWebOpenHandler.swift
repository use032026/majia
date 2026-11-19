






import Foundation
import UIKit


@objc public class STWebOpenHandler: NSObject {
    
    
    
    
    
    @objc public class func openWeb(url: String, params: [String: String]?, crl: UIViewController? = nil, navi: UINavigationController? = nil) {
        if url.hasPrefix(STH5Prefix.http) || url.hasPrefix(STH5Prefix.https) {
            if navi != nil {
                let config = STWebConfig(webMode: .h5)
                config.allowsInsecureHttpNavigation = StminiFlutterPlugin.allowsInsecureHttpNavigation()
                guard let webURL = URL(string: url),
                      isAllowedExternalH5URL(webURL, allowInsecureHTTP: config.allowsInsecureHttpNavigation) else {
                    STProjectHelper.Log("H5 地址无效，仅支持已授权的 HTTP(S) URL")
                    return
                }
                config.bridgePolicy = StminiFlutterPlugin.externalWebBridgePolicy(for: webURL)
                
                
                if let params = params, !params.isEmpty {
                    
                    let finalUrl = appendParamsToUrl(url, params: params)
                    
                    config.params = params
                    
                    STProjectHelper.Log("H5最终URL: \(redactedURL(finalUrl))")
                    STProjectHelper.Log("H5参数键: \(parameterKeysDescription(params))")
                    STWebOpenHandler.openH5(url: finalUrl, config: config, navi: navi!)
                } else {
                    
                    STWebOpenHandler.openH5(url: url, config: config, navi: navi!)
                }
            }
            else {
                STProjectHelper.Log("打开H5需要传递navi导航栏控制器")
            }
        }
        else if url.hasPrefix(STMiniPrefix.online) {
            
            let miniUrl = url.replacingOccurrences(of: STMiniPrefix.online, with: "")
            var (name, path, existingParams) = parseMiniUrl(miniUrl)
            guard isValidMiniId(name) else {
                STProjectHelper.Log("在线小程序标识无效")
                return
            }
            if let pathParam = params?["path"] {
                path = pathParam
            }
            
            if crl != nil {
                let config = STWebConfig(webMode: .online)
                config.path = path

                
                var mergedParams: [String: String] = existingParams ?? [:]
                if let newParams = params {
                    
                    for (key, value) in newParams {
                        mergedParams[key] = value
                    }
                }
                normalizeOnlineMiniParameters(&mergedParams)
                
                if !mergedParams.isEmpty {
                    config.params = mergedParams
                }
                config.sourceLink = url
                
                STProjectHelper.Log("在线小程序参数: name=\(name), path=\(path ?? "nil"), paramKeys=\(parameterKeysDescription(mergedParams))")
                STWebOpenHandler.openMiniprogram(name: name, config: config, crl: crl!)
            }
            else {
                STProjectHelper.Log("打开小程序需要传递present父控制器")
            }
        }
        else if url.hasPrefix(STMiniPrefix.local) {
            
            let miniUrl = url.replacingOccurrences(of: STMiniPrefix.local, with: "")
            var (name, path, existingParams) = parseMiniUrl(miniUrl)
            guard isValidMiniId(name) else {
                STProjectHelper.Log("本地小程序标识无效")
                return
            }
            if let pathParam = params?["path"] {
                path = pathParam
            }
            
            if navi != nil {
                let config = STWebConfig(webMode: .local)
                config.bridgePolicy = .localMini
                config.path = path

                
                var mergedParams: [String: String] = existingParams ?? [:]
                if let newParams = params {
                    
                    for (key, value) in newParams {
                        mergedParams[key] = value
                    }
                }
                
                if !mergedParams.isEmpty {
                    config.params = mergedParams
                }
                
                STProjectHelper.Log("本地小程序参数: name=\(name), path=\(path ?? "nil"), paramKeys=\(parameterKeysDescription(mergedParams))")
                STWebOpenHandler.openLocalMiniprogram(name: name, config: config, navi: navi!)
            }
            else {
                STProjectHelper.Log("打开小程序需要传递navi导航栏控制器")
            }
        }
    }
    
    
    
    
    
    
    private class func appendParamsToUrl(_ url: String, params: [String: String]) -> String {
        guard var components = URLComponents(string: url) else {
            return url
        }
        
        
        var queryItems = components.queryItems ?? []
        
        
        for (key, value) in params {
            let queryItem = URLQueryItem(name: key, value: value)
            queryItems.append(queryItem)
        }
        
        
        components.queryItems = queryItems
        
        
        return components.string ?? url
    }
    
    
    
    
    private class func parseMiniUrl(_ url: String) -> (name: String, path: String?, params: [String: String]?) {
        
        let components = url.split(separator: "?", maxSplits: 1)
        let namePart = String(components[0])
        
        var path: String? = nil
        var params: [String: String]? = nil
        
        if components.count > 1 {
            let queryPart = String(components[1])
            let queryParams = parseQueryString(queryPart)
            
            
            if let extractedPath = queryParams["path"] {
                path = extractedPath
                
                
                var mutableParams = queryParams
                mutableParams.removeValue(forKey: "path")
                if !mutableParams.isEmpty {
                    params = mutableParams
                }
            } else {
                if !queryParams.isEmpty {
                    params = queryParams
                }
            }
        }
        
        return (namePart, path, params)
    }

    /// Both a CMS Grid link and a QR payload use this same mini:// contract.
    /// Keep the documented camelCase spelling internally while accepting the
    /// old snake_case aliases already emitted by earlier QR tools.
    private class func normalizeOnlineMiniParameters(_ params: inout [String: String]) {
        let aliases = [
            "download_url": "downloadUrl",
            "icon_url": "iconUrl",
            "mini_name": "miniName",
            "mini_name_en": "miniNameEn",
            "current_version": "currentVersion",
            "min_support_version": "minSupportVersion"
        ]
        for (alias, canonical) in aliases {
            if (params[canonical]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
               let value = params[alias]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                params[canonical] = value
            }
            params.removeValue(forKey: alias)
        }
    }

    private class func isValidMiniId(_ value: String) -> Bool {
        !value.isEmpty && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }

    private class func parameterKeysDescription(_ params: [String: String]?) -> String {
        guard let params, !params.isEmpty else { return "[]" }
        return "[\(params.keys.sorted().joined(separator: ","))]"
    }

    private class func redactedURL(_ value: String) -> String {
        guard var components = URLComponents(string: value) else { return "[invalid-url]" }
        components.query = nil
        components.fragment = nil
        return components.string ?? "[url]"
    }

    
    
    
    private class func parseQueryString(_ queryString: String) -> [String: String] {
        var params: [String: String] = [:]
        
        let pairs = queryString.split(separator: "&")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0])
                let valueString = String(keyValue[1])
                let decodedValue = valueString.removingPercentEncoding ?? valueString
                
                params[key] = decodedValue
            }
        }
        
        return params
    }

    private class func isAllowedExternalH5URL(_ url: URL, allowInsecureHTTP: Bool) -> Bool {
        guard url.host?.isEmpty == false,
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || (allowInsecureHTTP && scheme == "http")
    }
    
    
    
    
    
    
    
    public class func openH5(url: String, config: STWebConfig, navi: UINavigationController) {
        
        config.params?.removeValue(forKey: "link")
        config.params?.removeValue(forKey: "permission")

        var finalUrl = url
        
        if let params = config.params, !params.isEmpty {
            finalUrl = appendParamsToUrl(url, params: params)
        }

        STProjectHelper.Log("打开H5: \(redactedURL(finalUrl))")
        STProjectHelper.Log("H5参数键: \(parameterKeysDescription(config.params))")
        let h5Crl = STWebH5Crl(url: finalUrl, config: config)
        navi.isNavigationBarHidden = false
        h5Crl.hidesBottomBarWhenPushed = true
        
        
        if shouldReplaceCurrentController(config: config, navigationController: navi) {
            replaceCurrentController(with: h5Crl, in: navi)
        } else {
            navi.pushViewController(h5Crl, animated: true)
        }
    }
    
    
    
    
    
    
    
    public class func openMiniprogram(name: String, config: STWebConfig, crl: UIViewController) {
        guard isValidMiniId(name) else {
            STProjectHelper.Log("在线小程序标识无效")
            return
        }
        config.params?.removeValue(forKey: "link")
        config.params?.removeValue(forKey: "permission")
        if let cachedNavigationController = STWebMiniProgramKeepAliveStore.shared.take(miniId: name, config: config) {
            // A cached Mini was hosted in a 1×1 invisible view. UIKit normally
            // lays it out again during `present`, but a custom transition can
            // begin before that layout pass and retain the old scale/frame as
            // a shrunken card. Reset its visible geometry before presentation.
            cachedNavigationController.loadViewIfNeeded()
            cachedNavigationController.view.transform = .identity
            cachedNavigationController.view.frame = crl.view.bounds
            cachedNavigationController.view.alpha = 1
            cachedNavigationController.view.backgroundColor = .white
            cachedNavigationController.modalPresentationStyle = .custom
            cachedNavigationController.hidesBottomBarWhenPushed = true
            let miniCrl = cachedNavigationController.viewControllers.first as? STWebMiniprogramCrl
            if let miniCrl {
                cachedNavigationController.transitioningDelegate = miniCrl
            }
            // A retained runtime is hosted at 1×1 while cached.  Notify its
            // H5 only after UIKit has restored its real presentation bounds;
            // otherwise a resumed page can retain the cache host viewport.
            crl.present(cachedNavigationController, animated: true) {
                miniCrl?.setKeepAliveRuntimeHidden(false)
            }
            return
        }
        let miniCrl = STWebMiniprogramCrl(name: name, config: config, isChild: false)
        let naviCrl = STWebNavigationController(rootViewController: miniCrl)
        naviCrl.view.backgroundColor = .white
        // STMini's first-page edge dismissal uses its transitioning delegate;
        // UIKit invokes that delegate only for a custom presentation.
        naviCrl.modalPresentationStyle = .custom
        naviCrl.transitioningDelegate = miniCrl
        naviCrl.hidesBottomBarWhenPushed = true
        crl.present(naviCrl, animated: true)
    }
    
    
    
    
    
    
    
    public class func openLocalMiniprogram(name: String, config: STWebConfig, navi: UINavigationController) {
        guard isValidMiniId(name) else {
            STProjectHelper.Log("本地小程序标识无效")
            return
        }
        config.params?.removeValue(forKey: "link")
        config.params?.removeValue(forKey: "permission")
        let miniCrl = STWebMiniprogramCrl(name: name, config: config, isChild: false)

        // Local Mini programs normally follow the existing navigation-stack flow.
        // Opt-in entries use the same full-screen Mini program container as online Mini programs.
        if shouldPresentAsMiniProgram(config: config) {
            let miniNaviCrl = STWebNavigationController(rootViewController: miniCrl)
            miniNaviCrl.view.backgroundColor = .white
            miniNaviCrl.modalPresentationStyle = .custom
            miniNaviCrl.transitioningDelegate = miniCrl
            miniNaviCrl.hidesBottomBarWhenPushed = true
            navi.present(miniNaviCrl, animated: true)
            return
        }

        navi.isNavigationBarHidden = false
        miniCrl.hidesBottomBarWhenPushed = true
        
        
        if shouldReplaceCurrentController(config: config, navigationController: navi) {
            replaceCurrentController(with: miniCrl, in: navi)
        } else {
            navi.pushViewController(miniCrl, animated: true)
        }
    }

    private class func shouldPresentAsMiniProgram(config: STWebConfig) -> Bool {
        guard let value = config.params?["presentAsMiniProgram"]?.lowercased() else {
            return false
        }
        return value == "1" || value == "true" || value == "yes"
    }
    
    
    class func reOpenMiniprogram(animated: Bool = true) {
        let miniInfo = STWebInfoStorage.sharedInstance()
        let miniCrl = STWebMiniprogramCrl(name: miniInfo.name, config: miniInfo.config, isChild: false)
        let naviCrl = STWebNavigationController(rootViewController: miniCrl)
        naviCrl.view.backgroundColor = .white
        naviCrl.modalPresentationStyle = .custom
        naviCrl.transitioningDelegate = miniCrl
        naviCrl.hidesBottomBarWhenPushed = true
        STTool.currentViewController()!.present(naviCrl, animated: animated)
    }
    
    
    
    
    
    
    private class func shouldReplaceCurrentController(config: STWebConfig, navigationController: UINavigationController) -> Bool {
        
        if let params = config.params,
           let isReplaceValue = params["isReplace"] {
            
            
            let lowercased = isReplaceValue.lowercased()
            return lowercased == "1" || lowercased == "true" || lowercased == "yes"
        }
        
        return false
    }
    
    
    
    
    
    private class func replaceCurrentController(with newController: UIViewController, in navigationController: UINavigationController) {
        
        
        guard let currentController = navigationController.topViewController else {
            
            navigationController.pushViewController(newController, animated: true)
            return
        }
        
        
        var viewControllers = navigationController.viewControllers
        
        
        if let currentIndex = viewControllers.firstIndex(of: currentController) {
            
            viewControllers.remove(at: currentIndex)
            viewControllers.append(newController)
            
            
            navigationController.setViewControllers(viewControllers, animated: true)
            
            
            addReplaceTransitionAnimation(to: navigationController)
            
        } else {
            
            navigationController.pushViewController(newController, animated: true)
        }
    }
    
    
    
    private class func addReplaceTransitionAnimation(to navigationController: UINavigationController) {
        
        let transition = CATransition()
        transition.duration = 0.35
        transition.type = .fade
        navigationController.view.layer.add(transition, forKey: nil)
    }
}
