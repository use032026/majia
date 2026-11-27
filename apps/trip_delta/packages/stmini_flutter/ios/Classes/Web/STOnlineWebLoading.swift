import Foundation

/// 仅镜像一方 H5 的手动语言选择；自动语言始终跟随本次系统语言。
public enum STOnlineWebLaunchLanguage {
  public static func normalized(_ language: String) -> String? {
    let value = language.replacingOccurrences(of: "_", with: "-")
    guard value.count <= 35,
          value.range(of: "^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$", options: .regularExpression) != nil else { return nil }
    return value
  }

  private static func file(directory: URL?) -> URL? {
    (directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)?
      .appendingPathComponent("stmini_web_launch_languages_v1.json")
  }

  private static func entries(directory: URL?) -> [String: String] {
    guard let url = file(directory: directory), let data = try? Data(contentsOf: url), data.count <= 8192,
          let entries = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] else { return [:] }
    return entries
  }

  public static func cached(origin: String, directory: URL? = nil) -> String? {
    entries(directory: directory)[origin].flatMap(normalized)
  }

  public static func save(_ language: String?, origin: String, directory: URL? = nil) {
    if let language, normalized(language) == nil { return }
    let value = language.flatMap(normalized)
    var values = entries(directory: directory)
    guard values[origin] != value, let url = file(directory: directory) else { return }
    values[origin] = value
    do {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONSerialization.data(withJSONObject: values).write(to: url, options: .atomic)
    } catch {
      // 启动语言只是显示偏好；读取失败时仍可使用系统语言打开网页。
    }
  }

  public static func imageKey(manualLanguage: String?, systemLanguage: String) -> String {
    (manualLanguage ?? systemLanguage).lowercased().hasPrefix("zh") ? "zh" : "default"
  }
}

/// 每次顶层导航只维护一份加载状态；旧文档和失败后的迟到通知不能揭开遮罩。
public struct STOnlineWebLoadingState {
  public enum Phase: Equatable { case loading, ready, failed }
  public private(set) var generation = 0
  public private(set) var phase: Phase = .loading

  public init() {}

  @discardableResult public mutating func begin() -> Int {
    generation += 1
    phase = .loading
    return generation
  }

  @discardableResult public mutating func ready(_ generation: Int) -> Bool {
    guard self.generation == generation, phase == .loading else { return false }
    phase = .ready
    return true
  }

  @discardableResult public mutating func fail(_ generation: Int) -> Bool {
    guard self.generation == generation, phase == .loading else { return false }
    phase = .failed
    return true
  }
}

/// Keep one automatic attempt per lost document, even if WebKit terminates
/// the replacement process before the recovered page becomes ready.
enum STOnlineWebProcessRecovery: Equatable {
  case idle
  case pending(URL)
  case attempted

  mutating func recordTermination(at url: URL, documentWasReady: Bool) -> Bool {
    if documentWasReady { self = .idle }
    switch self {
    case .idle: self = .pending(url)
    case .pending: break
    case .attempted: return false
    }
    return true
  }

  mutating func takeReloadURL(isActivePage: Bool) -> URL? {
    guard isActivePage, case let .pending(url) = self else { return nil }
    self = .attempted
    return url
  }
}

#if canImport(UIKit) && canImport(WebKit)
import UIKit
import Flutter
@preconcurrency import WebKit

/// 读取宿主已有启动资源，无需在插件配置中重复声明品牌。
enum STOnlineWebHostLaunchScreen {
  static func make(bundle: Bundle = .main, information: [String: Any]? = nil) -> UIViewController? {
    let info = information ?? bundle.infoDictionary ?? [:]
    let suffix = UIDevice.current.userInterfaceIdiom == .pad ? "~ipad" : "~iphone"
    var name = (info["UILaunchStoryboardName" + suffix] ?? info["UILaunchStoryboardName"]) as? String
    if name == nil, let group = info["UILaunchStoryboards"] as? [String: Any],
       let identifier = group["UIDefaultLaunchStoryboard"] as? String,
       let definitions = group["UILaunchStoryboardDefinitions"] as? [[String: Any]] {
      name = definitions.first { $0["UILaunchStoryboardIdentifier"] as? String == identifier }?["UILaunchStoryboardFile"] as? String
    }
    if let value = name, ["storyboard", "xib", "nib"].contains((value as NSString).pathExtension) {
      name = (value as NSString).deletingPathExtension
    }
    if let name, !name.isEmpty,
       bundle.url(forResource: name, withExtension: "storyboardc") != nil,
       let controller = UIStoryboard(name: name, bundle: bundle).instantiateInitialViewController() {
      return controller
    }
    if let name, bundle.url(forResource: name, withExtension: "nib") != nil,
       let view = bundle.loadNibNamed(name, owner: nil)?.first(where: { $0 is UIView }) as? UIView {
      let controller = UIViewController()
      controller.view = view
      return controller
    }
    var selectedDefinition = info["UILaunchScreen"] as? [String: Any]
    if selectedDefinition == nil, let group = info["UILaunchScreens"] as? [String: Any],
       let identifier = group["UIDefaultLaunchScreen"] as? String,
       let definitions = group["UILaunchScreenDefinitions"] as? [[String: Any]] {
      selectedDefinition = definitions.first { $0["UILaunchScreenIdentifier"] as? String == identifier }
    }
    guard let definition = selectedDefinition else { return nil }
    let controller = UIViewController()
    let view = UIView()
    view.backgroundColor = (definition["UIColorName"] as? String)
      .flatMap { UIColor(named: $0, in: bundle, compatibleWith: nil) } ?? .systemBackground
    controller.view = view
    if let name = definition["UIImageName"] as? String,
       let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
      let imageView = UIImageView(image: image)
      imageView.contentMode = .scaleAspectFit
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
      view.addSubview(imageView)
      let guide: UILayoutGuide = definition["UIImageRespectsSafeAreaInsets"] as? Bool == true
        ? view.safeAreaLayoutGuide : view.layoutMarginsGuide
      if definition["UIImageRespectsSafeAreaInsets"] as? Bool != true { view.layoutMargins = .zero }
      NSLayoutConstraint.activate([
        imageView.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
        imageView.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
        imageView.widthAnchor.constraint(lessThanOrEqualTo: guide.widthAnchor),
        imageView.heightAnchor.constraint(lessThanOrEqualTo: guide.heightAnchor),
      ])
    }
    return controller
  }
}

/// 通用在线网页加载层。默认复用宿主启动页，业务就绪事件可选配置。
final class STOnlineWebLoadingController {
  static let handlerName = "STMiniWebLoading"
  private let configuration: [String: Any]
  private let readyOrigin: String?
  private var state = STOnlineWebLoadingState()
  private var deadline: DispatchWorkItem?
  private weak var webView: WKWebView?
  private let cover = UIView()
  private var launchScreen: UIViewController?
  private var localizedImage: UIImageView?
  private let errorView = UIView()
  private let message = UILabel()
  private let retryButton = UIButton(type: .system)
  var retry: (() -> Void)?
  private var released = false
  private var hasCommittedDocument = false

  init(configuration: [String: Any]?, readyOrigin: String?) {
    self.configuration = configuration ?? [:]
    self.readyOrigin = readyOrigin
  }

  private var readyEvent: String? {
    guard let value = configuration["readyEvent"] as? String, !value.isEmpty else { return nil }
    return value
  }

  /// 两次 rAF 后发送通知，保证事件触发后的 DOM 更新有绘制机会。
  /// 每个文档有独立标识，原生回查当前文档，拒绝同源旧文档的迟到回调。
  var script: WKUserScript {
    let values: [String: Any] = [
      "readyEvent": readyEvent ?? "",
      "failureEvent": configuration["failureEvent"] as? String ?? "",
      "handler": Self.handlerName,
      "readyOrigin": readyOrigin ?? "",
      "languageStorage": configuration["languageStorage"] as? [String: String] ?? [:],
    ]
    let json = String(data: try! JSONSerialization.data(withJSONObject: values), encoding: .utf8)!
    return WKUserScript(source: """
      (() => {
        const options = \(json);
        const token = String(Date.now()) + '-' + Math.random().toString(36);
        let sent = false;
        function send(kind) {
          if (sent) return;
          sent = true;
          window.webkit.messageHandlers[options.handler].postMessage({kind, token});
        }
        function ready() {
          requestAnimationFrame(() => requestAnimationFrame(() => send('ready')));
        }
        window.__stminiFirstContent = {token, ready};
        if (location.origin === options.readyOrigin) {
          if (options.readyEvent) window.addEventListener(options.readyEvent, ready, {once:true});
          if (options.failureEvent) window.addEventListener(options.failureEvent, () => send('failed'), {once:true});
          const keys = options.languageStorage;
          if (keys.valueKey && keys.manualKey) {
            function publishLanguage() {
              try {
                const language = localStorage.getItem(keys.manualKey) === '1'
                  ? (localStorage.getItem(keys.valueKey) || '') : '';
                if (language && !/^[A-Za-z]{2,3}([-_][A-Za-z0-9]{2,8})*$/.test(language)) return;
                window.webkit.messageHandlers[options.handler].postMessage({kind:'language', token, language});
              } catch (_) {}
            }
            for (const method of ['setItem', 'removeItem', 'clear']) {
              const original = Storage.prototype[method];
              Storage.prototype[method] = function(...args) {
                const result = original.apply(this, args);
                if (this === localStorage && (method === 'clear' || args[0] === keys.valueKey || args[0] === keys.manualKey)) publishLanguage();
                return result;
              };
            }
            window.addEventListener('storage', publishLanguage);
            document.addEventListener('DOMContentLoaded', publishLanguage, {once:true});
            window.addEventListener('load', publishLanguage, {once:true});
            publishLanguage();
          }
        }
      })();
      """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
  }

  func attach(to container: UIView, webView: WKWebView, parent: UIViewController? = nil, showsLaunchScreen: Bool) {
    self.webView = webView
    container.backgroundColor = .systemBackground
    cover.backgroundColor = .systemBackground
    cover.accessibilityIdentifier = "stmini_web_loading"
    cover.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(cover)
    NSLayoutConstraint.activate([
      cover.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      cover.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      cover.topAnchor.constraint(equalTo: container.topAnchor),
      cover.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    if showsLaunchScreen, let launch = makeLaunchScreen() {
      launchScreen = launch
      parent?.addChild(launch)
      let launchView = launch.view!
      launchView.isUserInteractionEnabled = false
      launchView.translatesAutoresizingMaskIntoConstraints = false
      cover.addSubview(launchView)
      NSLayoutConstraint.activate([
        launchView.leadingAnchor.constraint(equalTo: cover.leadingAnchor),
        launchView.trailingAnchor.constraint(equalTo: cover.trailingAnchor),
        launchView.topAnchor.constraint(equalTo: cover.topAnchor),
        launchView.bottomAnchor.constraint(equalTo: cover.bottomAnchor),
      ])
      if let parent { launch.didMove(toParent: parent) }
    }
    errorView.translatesAutoresizingMaskIntoConstraints = false
    errorView.backgroundColor = .systemBackground
    cover.addSubview(errorView)
    NSLayoutConstraint.activate([
      errorView.leadingAnchor.constraint(equalTo: cover.leadingAnchor),
      errorView.trailingAnchor.constraint(equalTo: cover.trailingAnchor),
      errorView.topAnchor.constraint(equalTo: cover.topAnchor),
      errorView.bottomAnchor.constraint(equalTo: cover.bottomAnchor),
    ])
    let content = UIStackView()
    content.axis = .vertical
    content.alignment = .center
    content.spacing = 23
    content.translatesAutoresizingMaskIntoConstraints = false
    errorView.addSubview(content)
    message.numberOfLines = 0
    message.textAlignment = .center
    message.textColor = .label
    message.font = .preferredFont(forTextStyle: .body)
    content.addArrangedSubview(message)
    retryButton.setTitle(isChinese ? "重试" : "Retry", for: .normal)
    retryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    retryButton.tintColor = .label
    retryButton.accessibilityIdentifier = "stmini_web_loading_retry"
    retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    content.addArrangedSubview(retryButton)
    NSLayoutConstraint.activate([
      content.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
      content.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
      content.widthAnchor.constraint(lessThanOrEqualTo: errorView.widthAnchor, constant: -48),
      retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
    showLoading()
  }

  var isReady: Bool { state.phase == .ready }

  func begin(showsLaunchScreen: Bool = true, startsDeadline: Bool = true) {
    guard !released else { return }
    deadline?.cancel()
    deadline = nil
    let generation = state.begin()
    hasCommittedDocument = false
    showLoading(showsLaunchScreen: showsLaunchScreen)
    guard startsDeadline else { return }
    let timeout = min(120, max(5, (configuration["timeoutSeconds"] as? NSNumber)?.doubleValue ?? 25))
    let task = DispatchWorkItem { [weak self] in self?.fail(generation) }
    deadline = task
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: task)
  }

  func documentCommitted() { hasCommittedDocument = true }

  func documentFinished() {
    let currentOrigin = webView?.url.flatMap { STOnlineWebCore.normalizedBridgeOrigin($0, allowInsecureHTTP: true) }
    guard readyEvent == nil || currentOrigin != readyOrigin else { return }
    guard !released, state.phase == .loading else { return }
    webView?.evaluateJavaScript("window.__stminiFirstContent?.ready()", completionHandler: nil)
  }

  /// 调用方必须先执行标准的主 frame 和当前文档来源校验。
  func receive(_ body: Any) {
    guard !released,
          let body = body as? [String: Any],
          let token = body["token"] as? String, token.count < 100,
          let kind = body["kind"] as? String, ["ready", "failed", "language"].contains(kind),
          let data = try? JSONSerialization.data(withJSONObject: [token]),
          let json = String(data: data, encoding: .utf8) else { return }
    if kind != "language" && (!hasCommittedDocument || state.phase != .loading) { return }
    let generation = state.generation
    webView?.evaluateJavaScript("window.__stminiFirstContent?.token === \(json)[0]") { [weak self] result, _ in
      guard let self, !self.released, self.state.generation == generation, result as? Bool == true else { return }
      if kind == "language" {
        guard self.configuration["languageStorage"] != nil,
              let origin = self.readyOrigin,
              self.webView?.url.flatMap({ STOnlineWebCore.normalizedBridgeOrigin($0, allowInsecureHTTP: true) }) == origin,
              let language = body["language"] as? String,
              language.isEmpty || STOnlineWebLaunchLanguage.normalized(language) != nil else { return }
        STOnlineWebLaunchLanguage.save(language.isEmpty ? nil : language, origin: origin)
        if let image = self.localizedImage { _ = self.refreshImage(image) }
        return
      }
      if kind == "failed" { self.fail(generation); return }
      guard self.state.ready(generation) else { return }
      self.deadline?.cancel()
      self.deadline = nil
      self.cover.isHidden = true
      #if DEBUG
      print("[STMini][web_loading] first_content_ready")
      #endif
    }
  }

  func navigationFailed() { fail(state.generation) }

  func release() {
    released = true
    deadline?.cancel()
    deadline = nil
    retry = nil
    launchScreen?.willMove(toParent: nil)
    launchScreen?.view.removeFromSuperview()
    launchScreen?.removeFromParent()
    launchScreen = nil
    localizedImage = nil
  }

  private func showLoading(showsLaunchScreen: Bool = true) {
    launchScreen?.view.isHidden = !showsLaunchScreen
    cover.isHidden = false
    errorView.isHidden = true
    message.isHidden = true
    retryButton.isHidden = true
  }

  private func fail(_ generation: Int) {
    guard !released, state.fail(generation) else { return }
    deadline?.cancel()
    deadline = nil
    errorView.isHidden = false
    message.text = isChinese ? "页面暂时无法打开，请重试。" : "Unable to load this page. Please retry."
    message.isHidden = false
    retryButton.isHidden = false
    #if DEBUG
    print("[STMini][web_loading] failed")
    #endif
  }

  @objc private func retryTapped() { retry?() }

  private var isChinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }

  private func makeLaunchScreen() -> UIViewController? {
    let imageView = UIImageView()
    if refreshImage(imageView) {
      imageView.contentMode = .scaleAspectFill
      imageView.clipsToBounds = true
      localizedImage = imageView
      let controller = UIViewController()
      controller.view = imageView
      return controller
    }
    let controller = STOnlineWebHostLaunchScreen.make()
    controller?.view.accessibilityIdentifier = "stmini_host_launch_screen"
    return controller
  }

  @discardableResult private func refreshImage(_ view: UIImageView) -> Bool {
    guard let images = configuration["launchImages"] as? [String: String] else { return false }
    let language = readyOrigin.flatMap { STOnlineWebLaunchLanguage.cached(origin: $0) }
    let key = STOnlineWebLaunchLanguage.imageKey(manualLanguage: language,
      systemLanguage: Locale.preferredLanguages.first ?? "en")
    guard let asset = images[key] ?? images["default"] else { return false }
    let flutterKey = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: flutterKey, ofType: nil),
          let image = UIImage(contentsOfFile: path) else { return false }
    view.image = image
    view.accessibilityIdentifier = "stmini_web_launch_image_" + key
    return true
  }

}
#endif
