






import Foundation
import UIKit


struct STWebRouterApi {
    
    
    
    
    
    /// Opens a package-owned local page.  It is intentionally not an online
    /// H5 navigation API; online pages use the ordinary `open` API and are
    /// intercepted below when their caller belongs to an STMini stack.
    func navigateTo<T>(model: T) -> [String: Any] where T: STWebApiForm {
        guard let path = model.params["path"] as? String, !path.isEmpty else {
            STProjectHelper.Log("api<mini_navigateTo>path没有传")
            return failure(STMiniLocalized("mini.api_missing_path", "缺少 path"))
        }
        guard let root = STWebApiManager.miniRootController(for: model.webview) else {
            return failure(STMiniLocalized("mini.api_navigate_only", "mini_navigateTo 仅支持 STMini 小程序"))
        }
        guard let localPage = STWebResourceManager.installedMiniPackageLocalPageURL(name: root.name, path: path) else {
            return failure(STMiniLocalized("mini.api_local_page_invalid", "小程序本地页面无效"))
        }
        guard let navigationController = model.webview?.bindCrl?.navigationController else {
            return failure(STMiniLocalized("mini.api_navigation_unavailable", "小程序导航容器不可用"))
        }
        let title = model.params["title"] as? String
        guard let effectLease = STWebBridgeEffectLease(webView: model.webview, generation: model.documentGeneration, requiresMiniRoot: true) else {
            return failure(STMiniLocalized("mini.api_navigation_unavailable", "原页面授权已失效"))
        }
        DispatchQueue.main.async {
            guard effectLease.isCurrent() else { return }
            var params = ["isNeedNavigationBar": "true"]
            if let title, !title.isEmpty {
                params["title"] = title
            }
            let config = STWebConfig(webMode: .local, params: params)
            config.bridgePolicy = .localMini
            config.openSource = .mini
            let controller = STWebH5Crl(url: localPage.absoluteString, config: config, isChild: true)
            controller.isMiniInternalPage = true
            if let title, !title.isEmpty {
                controller.title = title
            }
            navigationController.pushViewController(controller, animated: true)
        }
        return ["code": "1", "data": ["opened": true]]
    }

    /// Handles `open({ router: "/web", link })` before the host's ordinary
    /// router does.  The page is online, but its controller is part of the
    /// caller's Mini navigation stack and therefore preserves Mini identity.
    func openInternalWebIfNeeded<T>(model: T) -> [String: Any]? where T: STWebApiForm {
        guard model.method == "open",
              (model.params["router"] as? String) == "/web",
              let root = STWebApiManager.miniRootController(for: model.webview) else {
            return nil
        }
        // Keep credentials and invitation parameters out of the console while
        // retaining enough information to diagnose route resolution.
        let debugRawLink = model.params["link"] as? String ?? "<empty>"
        let navigationRaw = Self.navigationParameterDescription(model.params["isNeedNavigationBar"])
        let miniId = root.name
        Self.trace("received caller=\(String(describing: type(of: model.webview?.bindCrl))) miniId=\(miniId) link=\(Self.safeLogURL(debugRawLink)) navigationRaw=\(navigationRaw)")
        guard let navigationController = model.webview?.bindCrl?.navigationController else {
            Self.trace("reject: navigation controller unavailable")
            return failure(STMiniLocalized("mini.api_navigation_unavailable", "小程序导航容器不可用"))
        }
        guard let rawLink = model.params["link"] as? String,
              let link = Self.resolvedExternalWebURL(rawLink, relativeTo: model.webview?.url) else {
            Self.trace("reject: unsafe or empty link")
            return failure(STMiniLocalized("mini.api_https_only", "仅支持安全的 HTTPS 页面"))
        }
        let title = model.params["title"] as? String
        guard let effectLease = STWebBridgeEffectLease(webView: model.webview, generation: model.documentGeneration, requiresMiniRoot: true) else {
            return failure(STMiniLocalized("mini.api_navigation_unavailable", "原页面授权已失效"))
        }
        DispatchQueue.main.async {
            guard effectLease.isCurrent() else { return }
            // This is an online page, but it is still owned by the Mini
            // navigation stack.  Navigation-bar visibility is an H5 choice:
            // when the parameter is absent, STMini keeps the Mini default
            // (hidden). H5 opts in only for pages that need native back
            // navigation, such as the external usage guide.
            var params = [String: String]()
            if let value = model.params["isNeedNavigationBar"] as? String {
                params["isNeedNavigationBar"] = value
            } else if let value = model.params["isNeedNavigationBar"] as? NSNumber {
                params["isNeedNavigationBar"] = value.stringValue
            }
            if let title, !title.isEmpty { params["title"] = title }
            let navigationEffective = params["isNeedNavigationBar"] ?? "<absent>"
            let navigationVisible = Self.isNavigationBarVisible(navigationEffective)
            let stackBefore = navigationController.viewControllers.count
            Self.trace("open /web miniId=\(miniId) url=\(Self.safeLogURL(link.absoluteString)) navigationRaw=\(navigationRaw) navigationEffective=\(navigationEffective) navigationVisible=\(navigationVisible) titlePresent=\(title?.isEmpty == false) stackBefore=\(stackBefore)")
            let config = STWebConfig(webMode: .h5, params: params)
            config.allowsInsecureHttpNavigation = StminiFlutterPlugin.allowsInsecureHttpNavigation()
            // Match native STMini: a Mini-pushed online child may use the
            // ordinary host bridge without an embedding-app origin allowlist.
            // It remains in the verified root Mini's navigation stack, so its
            // Mini bridge identity is retained as well.
            config.bridgePolicy = .miniExternal
            config.openSource = .mini
            let controller = STWebH5Crl(url: link.absoluteString, config: config, isChild: true)
            // The Mini-root guard above is the same boundary used by native
            // iOS STMini. Ordinary host `/web` calls are not intercepted.
            controller.isMiniInternalPage = true
            if let title, !title.isEmpty { controller.title = title }
            navigationController.pushViewController(controller, animated: true)
            Self.trace("pushed /web miniId=\(miniId) url=\(Self.safeLogURL(link.absoluteString)) navigationVisible=\(navigationVisible) stackAfter=\(navigationController.viewControllers.count)")
        }
        return ["code": "1", "data": ["opened": true]]
    }

    /// Mini-to-Mini navigation is owned by STMini, never by an embedding
    /// application's router. Only the verified Mini root may use this route:
    /// package subpages and external `/web` documents must not use their
    /// position in a navigation stack to acquire Mini-opening authority.
    ///
    /// The target still goes through `STWebOpenHandler`, which is the normal
    /// Mini entry point for source persistence, package download, manifest
    /// verification and version checks.
    func openInternalMiniIfNeeded<T>(model: T) -> [String: Any]? where T: STWebApiForm {
        guard model.method == "open", (model.params["router"] as? String) == "/mini" else {
            return nil
        }
        guard let webView = model.webview,
              let presenter = webView.bindCrl as? STWebMiniprogramCrl else {
            return failure(STMiniLocalized("mini.api_mini_route_only", "仅小程序根页面可打开其他小程序"))
        }
        guard let link = Self.authorizedInternalMiniLink(
            allowsLocalMiniBridge: webView.allowsLocalMiniBridge,
            isRootMini: !presenter.isChild,
            rawLink: model.params["link"] as? String
        ) else {
            return failure(STMiniLocalized(
                webView.allowsLocalMiniBridge && !presenter.isChild
                    ? "mini.api_mini_link_invalid" : "mini.api_mini_route_only",
                webView.allowsLocalMiniBridge && !presenter.isChild
                    ? "小程序链接无效" : "仅小程序根页面可打开其他小程序"
            ))
        }
        guard !STWebResourceManager.requestsPackageMutation(link: link) else {
            return ["code": "0", "data": ["msg": "Mini package installation is unsupported", "supported": false]]
        }
        guard STWebResourceManager.isInstalledMiniPackageRunnable(link: link) else {
            return failure("No verified local Mini package meets the required version")
        }
        guard let effectLease = STWebBridgeEffectLease(webView: model.webview, generation: model.documentGeneration, requiresMiniRoot: true) else {
            return failure(STMiniLocalized("mini.api_navigation_unavailable", "原页面授权已失效"))
        }
        DispatchQueue.main.async {
            guard effectLease.isCurrent(), STWebResourceManager.isInstalledMiniPackageRunnable(link: link) else { return }
            STWebOpenHandler.openWeb(url: link, params: nil, crl: presenter)
        }
        return ["code": "1", "data": ["opened": true]]
    }

    /// A `/web` page is a separate native WebView, so its H5 JavaScript no
    /// longer has the Mini root as `window.parent`. Keep that page in the
    /// stack, then push a package-owned H5 child carrying the requested
    /// route. The child H5 resolves the route through its own Vue Router and
    /// a back action returns to the original `/web` page.
    func forwardMiniRouteOpenIfNeeded<T>(model: T) -> [String: Any]? where T: STWebApiForm {
        guard model.method == "open",
              let router = model.params["router"] as? String,
              !router.isEmpty,
              router != "/web",
              let caller = model.webview?.bindCrl as? STWebH5Crl,
              let navigationController = caller.navigationController,
              let miniRoot = navigationController.viewControllers.first(where: {
                  guard let controller = $0 as? STWebMiniprogramCrl else { return false }
                  return !controller.isChild
              }) as? STWebMiniprogramCrl else {
            return nil
        }

        var routeParams = model.params
        routeParams.removeValue(forKey: "methodId")
        // A login requested by an online `/web` is an authentication detour,
        // not a normal entry into the package profile page. The local H5
        // consumes this marker through its existing `isBack` contract and
        // pops this child back to the original `/web` after success.
        if router == "/login" || router == "/mine/login" {
            routeParams["isBack"] = "1"
        }
        guard JSONSerialization.isValidJSONObject(routeParams),
              let routeData = try? JSONSerialization.data(withJSONObject: routeParams),
              let localPage = STWebResourceManager.installedMiniPackageLocalPageURL(
                  name: miniRoot.name,
                  // `__mini_child` is also used by ordinary mini_navigateTo.
                  // Keep a distinct marker so H5 only closes the route child
                  // that was pushed from an online `/web` page.
                  path: "index.html#/?__mini_child=1&__mini_route_child=1&__mini_open_route=\(base64URL(routeData))"
              ) else {
            return failure(STMiniLocalized("mini.api_route_page_invalid", "小程序路由页面无效"))
        }

        Self.trace("push Mini route=\(router) without closing /web")
        guard let effectLease = STWebBridgeEffectLease(webView: model.webview, generation: model.documentGeneration, requiresMiniRoot: true) else {
            return failure(STMiniLocalized("mini.api_navigation_unavailable", "原页面授权已失效"))
        }
        DispatchQueue.main.async {
            guard effectLease.isCurrent() else { return }
            // The routed H5 page (for example login) renders its own back
            // affordance. Showing a native header here produces two back
            // buttons and is inconsistent with regular Mini routes.
            let config = STWebConfig(webMode: .local, params: ["isNeedNavigationBar": "false"])
            config.bridgePolicy = .localMini
            config.openSource = .mini
            let controller = STWebH5Crl(url: localPage.absoluteString, config: config, isChild: true)
            controller.isMiniInternalPage = true
            controller.isMiniRouteChild = true
            navigationController.pushViewController(controller, animated: true)
        }
        return ["code": "1", "data": ["opened": true]]
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func failure(_ message: String) -> [String: Any] {
        return ["code": "0", "data": ["msg": message]]
    }

    private static func isAllowedExternalWebURL(_ rawURL: String) -> Bool {
        guard let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.host != nil else {
            return false
        }
        let scheme = url.scheme?.lowercased()
        return scheme == "https" || (StminiFlutterPlugin.allowsInsecureHttpNavigation() && scheme == "http")
    }

    private static func resolvedExternalWebURL(_ rawURL: String, relativeTo baseURL: URL?) -> URL? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let resolved = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL,
              isAllowedExternalWebURL(resolved.absoluteString) else {
            return nil
        }
        return resolved
    }

    /// Keep this intentionally narrower than a general URL check. The
    /// existing Mini opener accepts `mini://<miniId>?...`; path-style Mini
    /// identifiers, credentials, ports and fragments are not part of that
    /// contract and must fail before the asynchronous open request is
    /// acknowledged.
    static func isValidInternalMiniLink(_ rawLink: String) -> Bool {
        // STWebOpenHandler intentionally recognizes the canonical lowercase
        // prefix. Reject case variants here rather than acknowledging an open
        // that its downstream entry point would silently ignore.
        guard rawLink.hasPrefix(STMiniPrefix.online),
              let components = URLComponents(string: rawLink),
              components.scheme == "mini",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let miniId = components.host,
              miniId.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil,
              components.path.isEmpty else {
            return false
        }
        return true
    }

    /// Pure authorization decision kept separate from UIKit/WebKit so the
    /// root/child/external boundary is executable in the plugin XCTest target.
    /// A nil result means callers must not invoke the package opener.
    static func authorizedInternalMiniLink(
        allowsLocalMiniBridge: Bool,
        isRootMini: Bool,
        rawLink: String?
    ) -> String? {
        guard allowsLocalMiniBridge, isRootMini,
              let rawLink else { return nil }
        let link = rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValidInternalMiniLink(link) ? link : nil
    }

    private static func safeLogURL(_ rawURL: String?) -> String {
        guard let rawURL, let components = URLComponents(string: rawURL) else {
            return rawURL?.prefix(160).description ?? "<empty>"
        }
        var redacted = components
        redacted.query = nil
        redacted.fragment = nil
        return redacted.string ?? rawURL.prefix(160).description
    }

    private static func navigationParameterDescription(_ value: Any?) -> String {
        guard let value else { return "<absent>" }
        if let string = value as? String { return string.prefix(32).description }
        if let number = value as? NSNumber { return number.stringValue }
        return "<unsupported:\(String(describing: type(of: value)))>"
    }

    private static func isNavigationBarVisible(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized == "1" || normalized == "true" || normalized == "yes"
    }

    private static func trace(_ message: String) {
        // STProjectHelper writes to the Xcode console only in DEBUG and
        // forwards the same transient event to an embedding Flutter host.
        // It does not persist a Release log on device.
        STProjectHelper.Log("[web-router] \(message)")
    }

    
}
