import KretaKit
import SwiftUI
import WebKit

/// Shows KRÉTA's own login page and catches the OAuth redirect.
///
/// The redirect target is an `https` address that belongs to KRÉTA, not a
/// custom scheme, so the system login sheet cannot hand it back to the app.
/// Instead the navigation to that address is cancelled here and its URL,
/// which carries the authorization code, goes to the app.
struct LoginWebView: UIViewRepresentable {
    let url: URL
    let onRedirect: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRedirect: onRedirect)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Nothing from the login survives the sheet: no cookies, no cache.
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onRedirect: (URL) -> Void
        private var isFinished = false

        init(onRedirect: @escaping (URL) -> Void) {
            self.onRedirect = onRedirect
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let target = navigationAction.request.url, LoginAttempt.isRedirect(target) else {
                decisionHandler(.allow)
                return
            }
            // Never load the redirect: the code in it is for the app only.
            decisionHandler(.cancel)
            guard !isFinished else { return }
            isFinished = true
            onRedirect(target)
        }
    }
}
