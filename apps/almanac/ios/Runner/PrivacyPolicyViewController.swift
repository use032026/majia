import UIKit
import WebKit

final class PrivacyPolicyViewController: UIViewController, WKNavigationDelegate {
  private let policyURL: URL
  private let chinese: Bool
  private var webView: WKWebView!
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let errorView = UIStackView()
  private let errorScrollView = UIScrollView()
  private var policyTask: URLSessionDataTask?
  private var requestID: UUID?
  private lazy var policySession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.waitsForConnectivity = true
    configuration.timeoutIntervalForResource = 30
    return URLSession(configuration: configuration)
  }()

  init(url: URL, chinese: Bool) {
    policyURL = url
    self.chinese = chinese
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = text("隐私政策", "Privacy policy")
    view.backgroundColor = .systemBackground
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: text("关闭", "Close"), style: .done, target: self, action: #selector(close)
    )
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .refresh, target: self, action: #selector(loadPolicy)
    )
    navigationItem.rightBarButtonItem?.accessibilityLabel = text("重新加载", "Reload")

    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self
    webView.allowsBackForwardNavigationGestures = true
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
    ])

    spinner.hidesWhenStopped = true
    spinner.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(spinner)
    NSLayoutConstraint.activate([
      spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    let message = UILabel()
    message.text = text(
      "网页加载失败。请检查网络连接和 Deynu 的网络授权后重试，或复制网址到浏览器打开。",
      "Unable to load the page. Check your connection and Deynu's network access, then retry or copy the address to your browser."
    )
    message.font = .preferredFont(forTextStyle: .body)
    message.adjustsFontForContentSizeCategory = true
    message.numberOfLines = 0
    message.textAlignment = .center

    let address = UILabel()
    address.text = policyURL.absoluteString
    address.font = .preferredFont(forTextStyle: .footnote)
    address.adjustsFontForContentSizeCategory = true
    address.numberOfLines = 0
    address.textAlignment = .center

    let retry = UIButton(type: .system)
    retry.setTitle(text("重试", "Retry"), for: .normal)
    retry.addTarget(self, action: #selector(loadPolicy), for: .touchUpInside)
    let copy = UIButton(type: .system)
    copy.setTitle(text("复制网址", "Copy address"), for: .normal)
    copy.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
    errorView.axis = .vertical
    errorView.spacing = 16
    [message, address, retry, copy].forEach { errorView.addArrangedSubview($0) }
    errorView.translatesAutoresizingMaskIntoConstraints = false
    errorScrollView.translatesAutoresizingMaskIntoConstraints = false
    errorScrollView.isHidden = true
    view.addSubview(errorScrollView)
    errorScrollView.addSubview(errorView)
    NSLayoutConstraint.activate([
      errorScrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      errorScrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
      errorScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      errorScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      errorView.leadingAnchor.constraint(equalTo: errorScrollView.contentLayoutGuide.leadingAnchor, constant: 24),
      errorView.trailingAnchor.constraint(equalTo: errorScrollView.contentLayoutGuide.trailingAnchor, constant: -24),
      errorView.topAnchor.constraint(equalTo: errorScrollView.contentLayoutGuide.topAnchor, constant: 24),
      errorView.bottomAnchor.constraint(equalTo: errorScrollView.contentLayoutGuide.bottomAnchor, constant: -24),
      errorView.widthAnchor.constraint(equalTo: errorScrollView.frameLayoutGuide.widthAnchor, constant: -48),
    ])

    loadPolicy()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isBeingDismissed || navigationController?.isBeingDismissed == true {
      cancelLoading()
    }
  }

  private func text(_ zh: String, _ en: String) -> String {
    chinese ? zh : en
  }

  @objc private func loadPolicy() {
    let identifier = UUID()
    requestID = identifier
    policyTask?.cancel()
    webView.stopLoading()
    errorScrollView.isHidden = true
    webView.isHidden = true
    spinner.startAnimating()
    // Fetch the actual policy through the app's network session, only after an explicit tap.
    let request = URLRequest(url: policyURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
    policyTask = policySession.dataTask(with: request) { [weak self] data, response, error in
      DispatchQueue.main.async { [weak self] in
        guard let self = self, self.requestID == identifier else { return }
        self.policyTask = nil
        guard error == nil, let data = data, !data.isEmpty,
          let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
        else {
          self.showFailure()
          return
        }
        var pageRequest = request
        pageRequest.url = response.url ?? self.policyURL
        // Reuse the downloaded response and its URL, preserving language and relative assets.
        self.webView.loadSimulatedRequest(pageRequest, response: response, responseData: data)
      }
    }
    policyTask?.resume()
  }

  private func cancelLoading() {
    requestID = nil
    policyTask?.cancel()
    policyTask = nil
    policySession.invalidateAndCancel()
    webView.stopLoading()
  }

  @objc private func close() {
    cancelLoading()
    dismiss(animated: true)
  }

  @objc private func copyAddress() {
    UIPasteboard.general.string = policyURL.absoluteString
    UIAccessibility.post(notification: .announcement, argument: text("网址已复制", "Address copied"))
  }

  private func showFailure() {
    spinner.stopAnimating()
    webView.isHidden = true
    errorScrollView.isHidden = false
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    errorScrollView.isHidden = true
    webView.isHidden = false
    spinner.startAnimating()
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    spinner.stopAnimating()
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    if (error as NSError).code != NSURLErrorCancelled { showFailure() }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    if (error as NSError).code != NSURLErrorCancelled { showFailure() }
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    showFailure()
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationResponse: WKNavigationResponse,
    decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
  ) {
    if navigationResponse.isForMainFrame,
      let response = navigationResponse.response as? HTTPURLResponse,
      response.statusCode >= 400
    {
      decisionHandler(.cancel)
      showFailure()
      return
    }
    decisionHandler(.allow)
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = navigationAction.request.url else {
      decisionHandler(.cancel)
      return
    }
    if url.scheme == "mailto" {
      UIApplication.shared.open(url)
      decisionHandler(.cancel)
    } else if url.scheme == "https" || url.scheme == "http" {
      if navigationAction.targetFrame == nil {
        webView.load(navigationAction.request)
        decisionHandler(.cancel)
      } else {
        decisionHandler(.allow)
      }
    } else {
      decisionHandler(.cancel)
    }
  }
}
