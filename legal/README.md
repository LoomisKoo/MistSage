# 法律文案与支持页（GitHub Pages）

线上仓库：`LoomisKoo/MistSage-pages`（本目录是源文件，改完要同步过去）

1. 把本目录的 `privacy.html`、`terms.html`、`support.html` 及对应的 `-en.html` 放到仓库根目录
2. 开启 GitHub Pages（Deploy from branch / root）
3. 确认可访问：
   - `https://loomiskoo.github.io/MistSage-pages/support.html`（中文，支持与帮助）
   - `https://loomiskoo.github.io/MistSage-pages/privacy.html`（中文）
   - `https://loomiskoo.github.io/MistSage-pages/terms.html`（中文）
   - 对应 `-en.html` 为英文版（support-en / privacy-en / terms-en）

App 里中文界面打开中文版，其余语言打开 `-en` 英文版。改了文案要中英文两份一起改。
4. 若用户名/仓库名不同，改 App 内 `LegalDocument.url`（`LegalWebView.swift`）

当前 App 默认指向：`https://loomiskoo.github.io/MistSage-pages/`

- 支持页地址 `.../support.html` 同时用作 App Store Connect 的「支持 URL」
- 联系方式：`magaxy@163.com`（支持页与隐私政策里都写了这个邮箱，改动时保持一致）
