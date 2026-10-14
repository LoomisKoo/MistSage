import SwiftUI
import WebKit

enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return L("隐私政策")
        case .terms: return L("用户协议")
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

    final class Coordinator {
        var loadedURL: URL?

        func load(_ url: URL, in view: WKWebView) {
            loadedURL = url
            view.load(URLRequest(url: url))
        }
    }
}
