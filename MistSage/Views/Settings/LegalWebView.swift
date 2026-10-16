import SwiftUI
import WebKit

enum LegalDocument: String, Identifiable {
    case privacy
    case terms
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return L("隐私政策")
        case .terms: return L("用户协议")
        case .support: return L("支持与帮助")
        }
    }

    /// GitHub Pages（把 `legal/` 下 HTML 发布到同名仓库 Pages 后即可）；中文界面打开中文版，其余打开英文版
    var url: URL {
        let suffix = LanguageOverride.current.isChinese ? "" : "-en"
        return URL(string: "https://loomiskoo.github.io/MistSage-pages/\(rawValue)\(suffix).html")!
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        LegalWebView(url: document.url)
            .background(Theme.paper)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: Self.darkStyleScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = context.coordinator
        context.coordinator.load(url, in: view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.load(url, in: view)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 页面自带浅色配色，深色模式下覆盖文字颜色（线上 HTML 未更新时也生效）
    private static let darkStyleScript = """
    var s = document.createElement('style');
    s.textContent = ':root{color-scheme:light dark}@media (prefers-color-scheme: dark){body,h1,h2,h3{color:#E8ECF4!important}p,li{color:#B4BDCC!important}}';
    document.head.appendChild(s);
    """

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedURL: URL?

        func load(_ url: URL, in view: WKWebView) {
            loadedURL = url
            view.load(URLRequest(url: url))
        }

        /// 支持页里的 mailto: 等链接交给系统打开，网页内仍只走 http(s)
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            if let scheme, !["http", "https", "about", "file", "data"].contains(scheme),
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
