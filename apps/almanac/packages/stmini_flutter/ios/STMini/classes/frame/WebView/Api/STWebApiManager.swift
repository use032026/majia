






import Foundation
import UIKit


@objc public class STWebApiManager: NSObject, STWebApiHandler {

    /// Quant APIs are a Mini capability, not ordinary H5 APIs.  Keep the
    /// recognition and isolation inside STMini even though an embedding App
    /// supplies the account/MCP implementation through `quantMiniApiHandle`.
    private static let quantMiniMethods: Set<String> = [
        "getQuantSession",
        "refreshQuantSession",
        "getQuantBootstrap",
        "saveQuantLocalSnapshot",
        "resetQuantLocalRecords",
    ]

    /// These helpers do not expose account/session/configuration data and are
    /// safe for a top-level external H5 document. Every other host-provided
    /// API requires a verified local Mini origin.
    private static let nonSensitiveExternalHostMethods: Set<String> = [
        "showToast",
        "showLoading",
        "hideLoading",
        "close",
        "more",
        "setStatusBarTextColor",
        "getStatusBarHeight",
        "applog",
        "logNetworkRequest",
    ]

    /// `JSONSerialization` raises an Objective-C exception (rather than a
    /// Swift `throw`) for NaN / +/-Infinity.  API data ultimately comes from
    /// the trading bridge, so one malformed numeric value must never be able
    /// to terminate the host process while replying to H5.
    private static func jsonCompatibleObject(_ value: Any) -> Any {
        if value is NSNull || value is String {
            return value
        }
        if let number = value as? NSNumber {
            // CFBoolean is also bridged as NSNumber.  It is always a valid
            // JSON value and must not be treated as a floating-point number.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number
            }
            if number.doubleValue.isFinite {
                return number
            }
            STProjectHelper.Log("STWebApiManager: 非有限数值已替换为 null，避免 JSON 回调导致宿主闪退")
            return NSNull()
        }
        if let dictionary = value as? [String: Any] {
            var sanitized: [String: Any] = [:]
            dictionary.forEach { key, item in
                sanitized[key] = jsonCompatibleObject(item)
            }
            return sanitized
        }
        if let dictionary = value as? [AnyHashable: Any] {
            var sanitized: [String: Any] = [:]
            dictionary.forEach { key, item in
                sanitized[String(describing: key)] = jsonCompatibleObject(item)
            }
            return sanitized
        }
        if let array = value as? [Any] {
            return array.map { jsonCompatibleObject($0) }
        }
        // The bridge contract is JSON only.  Preserve the callback shape for
        // unexpected Foundation/custom objects without serializing them via
        // description (which could leak implementation details to H5).
        STProjectHelper.Log("STWebApiManager: 非 JSON 回调值已替换为 null，type=\(String(describing: type(of: value)))")
        return NSNull()
    }

    private static func jsonString(_ object: [String: Any]) -> String? {
        guard let sanitized = jsonCompatibleObject(object) as? [String: Any],
              JSONSerialization.isValidJSONObject(sanitized) else {
            STProjectHelper.Log("STWebApiManager: 回调对象不是有效 JSON")
            return nil
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: sanitized, options: [])
            return String(data: data, encoding: .utf8)
        } catch {
            STProjectHelper.Log("STWebApiManager: JSON 回调序列化失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// Bridge responses frequently contain a complete local-storage snapshot.
    /// Formatting that payload for a debug log can take longer than the
    /// callback itself and also exposes credentials in Xcode.  Keep the
    /// diagnostic useful without walking or printing user data.
    private static func callbackLogSummary(_ params: [String: Any], method: String, methodId: String) -> String {
        let code = params["code"].map { String(describing: $0) } ?? "<none>"
        let dataSummary: String
        switch params["data"] {
        case let value as [String: Any]:
            dataSummary = "object(count=\(value.count))"
        case let value as [Any]:
            dataSummary = "array(count=\(value.count))"
        case let value as String:
            dataSummary = "string(length=\(value.utf8.count))"
        case nil:
            dataSummary = "none"
        default:
            dataSummary = "type=\(String(describing: type(of: params["data"]!)))"
        }
        return "api callback method=\(method) code=\(code) methodId=\(methodId) data=\(dataSummary)"
    }
    
    
    static func dealWithApiMessage(_ message: Any, webView: STMiniWebView) {
        guard Thread.isMainThread, webView.hasNativeEffectAuthority else { return }
        
        guard let messageDic = message as? [String: Any] else {
            STProjectHelper.Log("js调用原生api方法：消息不是map")
            return
        }
        guard (messageDic["method"] as? String) != nil else {
            STProjectHelper.Log("js调用原生api方法：method不是string")
            return
        }
        guard (messageDic["params"] as? [String: Any]) != nil else {
            STProjectHelper.Log("js调用原生api方法：params不是map")
            return
        }
                
        
        if let params = messageDic["params"] as? [String: Any],
           let methodId = params["methodId"], !(methodId is String) { return }
        var model = STWebApiModel.init(dict: messageDic)
        model.webview = webView
        if model.method == "open" {
            let router = model.params["router"] as? String ?? "<empty>"
            let link = (model.params["link"] as? String ?? "<empty>").split(separator: "?").first ?? "<empty>"
            let caller = String(describing: type(of: webView.bindCrl))
#if DEBUG
            NSLog("[STMini][bridge-open] router=%@ link=%@ caller=%@", router, String(link), caller)
#endif
        }
        // A Mini must not hand its `/web` route back to the host router.  It
        // stays in the Mini navigation stack so root identity and Mini API
        // permissions continue to apply to the online second-level page.
        if webView.allowsLocalMiniBridge {
            if let miniOpenResult = STWebRouterApi().openInternalWebIfNeeded(model: model) {
                STWebApiManager.callBack(miniOpenResult, model: model)
                return
            }
            // `/mini` remains an STMini runtime operation. It must be
            // considered before the legacy route-forward fallback, otherwise
            // a target Mini link would be mistaken for a local page route.
            if let miniOpenResult = STWebRouterApi().openInternalMiniIfNeeded(model: model) {
                STWebApiManager.callBack(miniOpenResult, model: model)
                return
            }
            if let miniRouteResult = STWebRouterApi().forwardMiniRouteOpenIfNeeded(model: model) {
                STWebApiManager.callBack(miniRouteResult, model: model)
                return
            }
        }

        
        
        // A host-forwarded online-Web request must preserve methodId so its
        // asynchronous Flutter response can resolve the exact CMS callback.
        // Local Mini APIs keep the same fields and behavior as before.
        let infoDic: [String : Any] = [
            "method": model.method,
            "methodId": model.methodId,
            "params": model.params,
        ]
        var result: [String : Any] = [:]
        if quantMiniMethods.contains(model.method) {
            // A quant method may only originate from a Mini root or from an
            // H5 page pushed by that root through mini_navigateTo.  Local
            // downloaded Minis are deliberately included here; package and
            // channel ownership are then verified by the host adapter.
            guard webView.allowsLocalMiniBridge,
                  miniRootController(for: webView) != nil else {
                STWebApiManager.callBack([
                    "code": "0",
                    "data": ["msg": STMiniLocalized("mini.api_quant_only", "仅量化小程序页面可调用该能力")],
                ], model: model)
                return
            }
            guard let quantHandle = STWebPersonalHandle.sharedInstance().quantMiniApiHandle else {
                STWebApiManager.callBack([
                    "code": "0",
                    "data": ["msg": STMiniLocalized("mini.api_quant_host_unavailable", "宿主未提供量化小程序能力")],
                ], model: model)
                return
            }
            result = quantHandle(infoDic, webView)
            if let handled = result["handled"] as? Int {
                result.removeValue(forKey: "params")
                result.removeValue(forKey: "handled")
                if handled == 1 {
                    STWebApiManager.callBack(result, model: model)
                } else if handled != 2 {
                    STWebApiManager.callBack([
                        "code": "0",
                        "data": ["msg": STMiniLocalized("mini.api_quant_unhandled", "量化小程序 API 未处理")],
                    ], model: model)
                }
                return
            }
            // A host adapter must explicitly finish or mark an async request.
            // Do not fall through to the ordinary H5 handler and accidentally
            // expose a quant method to a non-Mini implementation.
            STWebApiManager.callBack([
                "code": "0",
                "data": ["msg": STMiniLocalized("mini.api_quant_invalid_response", "量化小程序 API 返回无效")],
            ], model: model)
            return
        }
        if model.method.hasPrefix("mini_"), !webView.allowsLocalMiniBridge {
            STWebApiManager.callBack([
                "code": "0",
                "data": ["msg": "当前页面未获小程序 Bridge 授权"],
            ], model: model)
            return
        }
        if (STWebPersonalHandle.sharedInstance().apiHandle != nil) {
            guard webView.allowsHostSensitiveBridge || nonSensitiveExternalHostMethods.contains(model.method) else {
                STProjectHelper.Log("STMini Bridge 拒绝未受信外部页面的宿主 API method=\(model.method)")
                STWebApiManager.callBack([
                    "code": "0",
                    "data": ["msg": "当前页面未获宿主 Bridge 授权"],
                ], model: model)
                return
            }
            result = STWebPersonalHandle.sharedInstance().apiHandle!(infoDic, webView)
        }
        if result["handled"] != nil {
            if result["handled"] as! Int == 1 {
                result.removeValue(forKey: "params")
                result.removeValue(forKey: "handled")
                STWebApiManager.callBack(result, model: model)
                return
            }
            else if result["handled"] as! Int == 2 {
                STProjectHelper.Log("method<\(model.method)>延迟处理")
                return
            }
        }
        
        
        result.removeValue(forKey: "params")
        result.removeValue(forKey: "handled")
        if model.method == "mini_getMiniProgramContinuousKeepAlive" {
            result = STWebApiManager.continuousKeepAliveState(model: model, enabled: nil)
        }
        else if model.method == "mini_setMiniProgramContinuousKeepAlive" {
            let rawEnabled = model.params["enabled"]
            let enabled: Bool
            if let boolValue = rawEnabled as? Bool {
                enabled = boolValue
            } else if let numberValue = rawEnabled as? NSNumber {
                enabled = numberValue.boolValue
            } else if let textValue = rawEnabled as? String {
                enabled = ["1", "true", "yes", "on"].contains(textValue.lowercased())
            } else {
                result = ["code": "0", "data": ["msg": "缺少 enabled"]]
                STWebApiManager.callBack(result, model: model)
                return
            }
            result = STWebApiManager.continuousKeepAliveState(model: model, enabled: enabled)
        }
        else if model.method == "mini_getMiniPackageInfo" {
            result = STWebApiManager.miniPackageInfo(model: model)
        }
        else if model.method == "mini_checkMiniProgramUpdate" {
            result = STWebApiManager.checkMiniProgramUpdate(model: model)
        }
        else if model.method == "mini_downloadMiniProgramUpdate" {
            result = STWebApiManager.downloadMiniProgramUpdate(model: model)
        }
        else if model.method == "mini_navigateTo" {
            result = STWebRouterApi().navigateTo(model: model)
        }
        else if model.method == "mini_notifySessionChanged" {
            result = STWebApiManager.notifyMiniSessionChanged(model: model)
        }
        else if model.method == "open" {
            // `/web` is handled above by STWebRouterApi. Other routes belong
            // to the H5 application's own router, so return a precise bridge
            // error rather than incorrectly claiming that the `open` API is
            // unsupported.
            let route = model.params["router"] as? String
            let message = route?.isEmpty == false
                ? "路由<\(route!)>不存在"
                : "缺少 router"
            result = ["code": "0", "data": ["msg": message]]
        }
        else if model.method == "close" {
            // A package route pushed from an online `/web` page has no native
            // navigation bar. Its H5 back action calls `close`; pop only this
            // marked child so the original online page remains on the stack.
            if let child = webView.bindCrl as? STWebH5Crl,
               child.isMiniRouteChild,
               let navigation = child.navigationController,
               let effectLease = STWebBridgeEffectLease(webView: webView, generation: model.documentGeneration, requiresMiniRoot: true) {
                DispatchQueue.main.async {
                    guard effectLease.isCurrent(), navigation.topViewController === child else { return }
                    navigation.popViewController(animated: true)
                }
                result = ["code": "1", "data": ["closed": true]]
            }
            else if webView.environment == STWebEnv.pop {
                if let popView = webView.superview as? STWebPopView {
                    popView.dismiss()
                }
                result = ["code": "1", "data": ["closed": true]]
            }
        }
        else {

            result["code"] = "0"
            result["data"] = ["msg": "method<\(model.method)>尚未支持"]
            STWebApiManager.callBack(result, model: model)
            return
        }
        STWebApiManager.callBack(result, model: model)















        
    }

    /// Resolves the owning Mini root for either the root WebView or a page
    /// pushed by `mini_navigateTo`. Ordinary `/web` H5 pages do not carry
    /// `isMiniInternalPage`, so they never gain Mini-only APIs merely because
    /// they also use STMiniWebView internally. Both online and locally
    /// installed Mini packages are valid roots.
    static func miniRootController(for webView: STMiniWebView?) -> STWebMiniprogramCrl? {
        guard let webView,
              webView.allowsLocalMiniBridge,
              let controller = webView.bindCrl else { return nil }
        if let root = controller as? STWebMiniprogramCrl {
            guard !root.isChild else { return nil }
            return root
        }
        guard let child = controller as? STWebH5Crl,
              child.isMiniInternalPage,
              let navigationController = child.navigationController,
              let root = navigationController.viewControllers.first as? STWebMiniprogramCrl,
              !root.isChild else {
            return nil
        }
        return root
    }

    /// APIs that require a remotely managed Mini retain the online-only
    /// boundary. Quant APIs use `miniRootController(for:)` above because the
    /// supported package is normally a verified local download.
    static func onlineMiniRootController(for webView: STMiniWebView?) -> STWebMiniprogramCrl? {
        guard let root = miniRootController(for: webView), root.config.webMode == .online else {
            return nil
        }
        return root
    }

    /// All pages in one Mini navigation stack share the same Mini identity.
    /// A generic API is therefore rooted at that Mini, rather than restricted
    /// to whichever page happens to be visible.  Ordinary H5 remains outside
    /// this resolver and keeps only its existing H5 API surface.


    private static func continuousKeepAliveState<T>(model: T, enabled: Bool?) -> [String: Any] where T: STWebApiForm {
        guard let miniCrl = onlineMiniRootController(for: model.webview),
              let miniId = miniCrl.name,
              !miniId.isEmpty else {
            return ["code": "0", "data": ["msg": STMiniLocalized("mini.api_keep_alive_only", "仅小程序页面可设置持续保活")]]
        }
        let supported = STWebMiniProgramKeepAliveStore.shared.supportsContinuousKeepAlive(miniId: miniId)
        if let enabled = enabled, supported {
            STWebMiniProgramKeepAliveStore.shared.setContinuousKeepAlive(enabled, for: miniId)
        }
        return ["code": "1", "data": [
            "enabled": supported && STWebMiniProgramKeepAliveStore.shared.isContinuousKeepAliveEnabled(miniId: miniId),
            "supported": supported,
        ]]
    }

    /// Returns the identity of the package that STMini has already verified
    /// and is currently running.  H5 must never infer this from a route or a
    /// download link: those values can be stale, while the installed record
    /// and manifest are the source of truth after an atomic package swap.
    private static func miniPackageInfo<T>(model: T) -> [String: Any] where T: STWebApiForm {
        guard let miniCrl = miniRootController(for: model.webview),
              let miniId = STWebResourceManager.miniNameHandle(name: miniCrl.name).0,
              !miniId.isEmpty,
              let version = STWebResourceManager.installedMiniPackageVersion(name: miniId) else {
            return ["code": "0", "data": ["msg": STMiniLocalized("mini.api_package_verification_failed", "小程序包校验失败")]]
        }
        return ["code": "1", "data": [
            "miniId": miniId,
            "version": version,
            "updateself": STWebResourceManager.installedMiniPackageUpdateSelf(name: miniId) ?? "",
        ]]
    }

    /// Common host update-check entry for first-party Mini programs. The
    /// Local manifest metadata never grants package update capability.
    private static func checkMiniProgramUpdate<T>(model: T) -> [String: Any] where T: STWebApiForm {
        ["code": "0", "data": ["msg": "Mini package downloads, installation and updates are unsupported in this local-only runtime", "supported": false]]
    }

    /// Recognized legacy method; no package update implementation is compiled.
    private static func downloadMiniProgramUpdate<T>(model: T) -> [String: Any] where T: STWebApiForm {
        ["code": "0", "data": ["msg": "Mini package downloads, installation and updates are unsupported in this local-only runtime", "supported": false]]
    }
    
    
    static func sendScriptMessageWithMethod(_ method: String, params: [String: Any], webview: STMiniWebView) {
        var mutableDict =  [String: Any]()
        mutableDict["method"] = method;
        mutableDict["params"] = params;
        guard let result = jsonString(mutableDict) else { return }
        STProjectHelper.Log("sendMsg method: \(method) \nparams: \(params)")
        // Lifecycle events may arrive while the document is still parsing its
        // entry module.  Calling an undeclared global at that point throws a
        // JavaScript exception and loses the event.  The H5 bridge queues
        // later events itself, so native only needs to skip the pre-bridge
        // delivery safely.
        webview.evaluateJavaScript("if (typeof window.CMSCallJsMessage === 'function') { window.CMSCallJsMessage(\(result)); true; } else { false; }") { (info, error) in
            if error != nil {
                STProjectHelper.Log("js方法<\(method)>调用失败 错误：\(String(describing: error?.localizedDescription))")
            } else if (info as? Bool) == false {
                STProjectHelper.Log("js方法<\(method)>暂未投递：H5 Bridge 尚未就绪")
            } else {
                STProjectHelper.Log("js方法<\(method)>调用成功")
            }
        }
    }

    /// Mini-owned pages have separate JavaScript runtimes. Broadcast a
    /// credential-free session signal after either login or logout so every
    /// sibling rehydrates the exact shared auth snapshot through getStorage.
    private static func notifyMiniSessionChanged<T>(model: T) -> [String: Any] where T: STWebApiForm {
        guard let sourceWebView = model.webview,
              let source = sourceWebView.bindCrl,
              let navigationController = source.navigationController,
              miniRootController(for: model.webview) != nil else {
            return ["code": "0", "data": ["msg": STMiniLocalized("mini.api_session_change_only", "仅小程序页面可通知会话变更")]]
        }

        let rawReason = model.params["reason"] as? String ?? "sessionChanged"
        let reason = String(rawReason.prefix(64))
        let targets: [STMiniWebView] = navigationController.viewControllers.compactMap { controller in
            if let h5Controller = controller as? STWebH5Crl,
               h5Controller.webView !== sourceWebView {
                return h5Controller.webView
            }
            if let miniController = controller as? STWebMiniprogramCrl,
               miniController.webView !== sourceWebView {
                return miniController.webView
            }
            return nil
        }

        guard let sourceLease = STWebBridgeEffectLease(webView: sourceWebView, generation: model.documentGeneration, requiresMiniRoot: true) else {
            return ["code": "0", "data": ["msg": "原页面授权已失效"]]
        }
        let targetLeases = targets.compactMap { target -> (STMiniWebView, STWebBridgeEffectLease)? in
            guard let lease = STWebBridgeEffectLease(webView: target, generation: target.bridgeDocumentGeneration, requiresMiniRoot: true) else { return nil }
            return (target, lease)
        }
        DispatchQueue.main.async {
            guard sourceLease.isCurrent() else { return }
            STWebMiniProgramKeepAliveStore.shared.invalidateSession()
            let currentTargets = targetLeases.compactMap { target, lease in
                lease.isCurrent() && sourceLease.ownsTarget(target) ? target : nil
            }
            // Session changes retire queued authority before notifying active sibling pages.
            currentTargets.forEach { $0.invalidateBridgeDocumentSession() }
            currentTargets.forEach { webView in
                guard sourceLease.isCurrent(), sourceLease.ownsTarget(webView) else { return }
                STWebApiManager.sendScriptMessageWithMethod(
                    "miniSessionChanged",
                    params: ["reason": reason],
                    webview: webView
                )
            }
        }
        return ["code": "1", "data": ["notified": targets.count]]
    }


    
    
    static func callBack<T>(_ params: [String: Any], model: T) where T: STWebApiForm {
        guard let view = model.webview, let generation = model.documentGeneration,
              view.bridgeDocumentGeneration == generation else { return }
        callBack(params, method: model.method, methodId: model.methodId, webView: view, generation: generation)
    }

    /// Web-only host forwarding completes asynchronously through Flutter, so
    /// it cannot retain an STWebApiModel. Reuse the exact same envelope and
    /// CMSJsCallBack delivery path as synchronous Mini/H5 APIs.
    static func callBack(
        _ params: [String: Any],
        method: String,
        methodId: String,
        webView: STMiniWebView?,
        generation: UInt64? = nil
    ) {
        // The online-Web core owns the public callback envelope.  Mini API
        // handlers still choose their result data, but ordinary H5 and a Mini
        // `/web` child now receive the same `data`/`data.msg` structure as a
        // future Web-only package.
        let resultDic = STOnlineWebCore.callbackPayload(
            response: params,
            method: method,
            methodId: methodId
        )
        guard let result = jsonString(resultDic) else {
            STProjectHelper.Log("api<\(method)>回调已取消：无法构造安全 JSON")
            return
        }
        STProjectHelper.Log(callbackLogSummary(resultDic, method: method, methodId: methodId))
        guard let webView else { return }
        let capturedGeneration = generation ?? webView.bridgeDocumentGeneration
        DispatchQueue.main.async { [weak webView] in
          guard let webView, webView.bridgeDocumentGeneration == capturedGeneration,
                webView.allowsHostSensitiveBridge else { return }
          webView.evaluateJavaScript(STOnlineWebCore.callbackJavaScript(jsonPayload: result)) { (info, error) in
            if error != nil {
                STProjectHelper.Log("api<\(method)>回调失败 错误：\(String(describing: error?.localizedDescription))")
            } else if (info as? Bool) == false {
                STProjectHelper.Log("api<\(method)>回调暂未投递：H5 Bridge 尚未就绪")
            } else {
                STProjectHelper.Log(callbackLogSummary(resultDic, method: method, methodId: methodId))
            }
          }
        }
    }
    
}
