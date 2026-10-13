import SwiftUI
import WebKit

enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "隐私政策"
        case .terms: return "用户协议"
        }
    }

    /// GitHub Pages（把 `legal/` 下 HTML 发布到同名仓库 Pages 后即可）
    var url: URL {
        switch self {
        case .privacy:
            return URL(string: "https://loomiskoo.github.io/CostLedger-pages/privacy.html")!
        case .terms:
            return URL(string: "https://loomiskoo.github.io/CostLedger-pages/terms.html")!
        }
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
        let view = WKWebView(frame: .zero)
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

    final class Coordinator {
        var loadedURL: URL?

        func load(_ url: URL, in view: WKWebView) {
            loadedURL = url
            view.load(URLRequest(url: url))
        }
    }
}
