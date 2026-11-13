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
    let onProgress: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRedirect: onRedirect, onProgress: onProgress)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Nothing from the login survives the screen: no cookies, no cache.
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.observe(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onRedirect: (URL) -> Void
        private let onProgress: (Double) -> Void
        private var isFinished = false
        private var progressObservation: NSKeyValueObservation?

        init(onRedirect: @escaping (URL) -> Void, onProgress: @escaping (Double) -> Void) {
            self.onRedirect = onRedirect
            self.onProgress = onProgress
        }

        func observe(_ webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, change in
                guard let progress = change.newValue else { return }
                Task { @MainActor in self?.onProgress(progress) }
            }
        }

        func stopObserving() {
            progressObservation = nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let target = navigationAction.request.url, LoginAttempt.isRedirect(target) else {
                return .allow
            }
            // Never load the redirect: the code in it is for the app only.
            if !isFinished {
                isFinished = true
                onRedirect(target)
            }
            return .cancel
        }
    }
}
