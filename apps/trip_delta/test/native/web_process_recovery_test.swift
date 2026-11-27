import Foundation

@main
struct WebProcessRecoveryTest {
  static func main() {
    let current = URL(string: "https://example.test/guide#/details")!
    let later = URL(string: "https://example.test/another")!
    var recovery = STOnlineWebProcessRecovery.idle

    precondition(recovery.takeReloadURL(isActivePage: true) == nil, "Normal foregrounding never reloads")
    precondition(recovery.recordTermination(at: current, documentWasReady: true))
    precondition(recovery.takeReloadURL(isActivePage: false) == nil, "Wait for the page to be active and visible")
    precondition(recovery.recordTermination(at: later, documentWasReady: false))
    precondition(recovery.takeReloadURL(isActivePage: true) == current, "Preserve the original page and fragment")
    precondition(recovery.takeReloadURL(isActivePage: true) == nil, "Multiple foreground callbacks reload once")
    precondition(!recovery.recordTermination(at: later, documentWasReady: false), "A killed replacement shows retry")
    precondition(recovery.takeReloadURL(isActivePage: true) == nil, "Further foregrounding cannot loop")
    precondition(recovery.recordTermination(at: later, documentWasReady: true), "A ready document gets a fresh attempt")
    precondition(recovery.takeReloadURL(isActivePage: true) == later)
    var request = URLRequest(url: current)
    precondition(STOnlineWebProcessRecovery.isBodyFreeGET(request))
    request.httpMethod = "POST"
    precondition(!STOnlineWebProcessRecovery.isBodyFreeGET(request))
    request.httpMethod = "GET"
    request.httpBody = Data([1])
    precondition(!STOnlineWebProcessRecovery.isBodyFreeGET(request))
    request.httpBodyStream = InputStream(data: Data([1]))
    precondition(!STOnlineWebProcessRecovery.isBodyFreeGET(request))
    let previousFragment = URL(string: current.absoluteString.components(separatedBy: "#")[0] + "#start")!
    precondition(STOnlineWebProcessRecovery.isSameDocumentFragmentLink(current, currentURL: previousFragment))
    precondition(!STOnlineWebProcessRecovery.isSameDocumentFragmentLink(current, currentURL: current))
    let anotherDocument = URL(string: "https://example.test/other#/same")!
    precondition(!STOnlineWebProcessRecovery.isSameDocumentFragmentLink(current, currentURL: anotherDocument))
    precondition(STOnlineWebProcessRecovery.canReloadHistory(
      url: current, currentItemURL: current, didCommitKnownGET: true, isNavigating: false))
    precondition(!STOnlineWebProcessRecovery.canReloadHistory(
      url: current, currentItemURL: current, didCommitKnownGET: false, isNavigating: false), "POST or unknown method uses a fresh GET")
    precondition(!STOnlineWebProcessRecovery.canReloadHistory(
      url: current, currentItemURL: current, didCommitKnownGET: true, isNavigating: true), "A pending navigation cannot reuse the history item")
    precondition(!STOnlineWebProcessRecovery.canReloadHistory(
      url: current, currentItemURL: later, didCommitKnownGET: true, isNavigating: false), "A different history entry uses GET fallback")

    var loading = STOnlineWebLoadingState()
    let original = loading.begin()
    let pending = loading.begin()
    precondition(!loading.fail(original), "The earlier navigation timeout cannot show retry while waiting")
    let replacement = loading.begin()
    precondition(!loading.ready(pending), "A stale ready event cannot uncover the replacement")
    precondition(loading.fail(replacement), "A failed replacement remains available for manual retry")
    precondition(!loading.ready(replacement), "Late readiness cannot clear an already displayed error")
    print("Web process recovery checks passed")
  }
}
