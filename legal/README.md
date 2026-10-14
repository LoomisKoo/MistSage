# 法律文案（GitHub Pages）

1. 新建公开仓库，例如 `MistSage-pages`
2. 把本目录的 `privacy.html`、`terms.html`、`privacy-en.html`、`terms-en.html` 放到仓库根目录
3. 开启 GitHub Pages（Deploy from branch / root）
4. 确认可访问：
   - `https://<user>.github.io/MistSage-pages/privacy.html`（中文）
   - `https://<user>.github.io/MistSage-pages/terms.html`（中文）
   - `https://<user>.github.io/MistSage-pages/privacy-en.html`（英文）
   - `https://<user>.github.io/MistSage-pages/terms-en.html`（英文）

App 里中文界面打开中文版，其余语言打开 `-en` 英文版。改了文案要中英文两份一起改。
5. 若用户名/仓库名不同，改 App 内 `LegalDocument.url`（`LegalWebView.swift`）

当前 App 默认指向：`https://loomiskoo.github.io/MistSage-pages/`
