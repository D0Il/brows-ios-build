import SwiftUI
import UIKit
import WebKit

/// Reader mode: the article, stripped of chrome, set in a readable column with its
/// images kept. The extraction is WebKit's view of the article; the typography is
/// applied here so it does not inherit the site's CSS.
struct ReaderSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss
    let content: ReaderContent

    @State private var size: CGFloat = 18

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.98).ignoresSafeArea()

                if content.html.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(content.title)
                                .scaledFont(26, .bold, design: .serif)
                                .foregroundColor(Color(white: 0.1))
                            Divider()
                            Text(content.text)
                                .scaledFont(size, design: .serif)
                                .lineSpacing(5)
                                .foregroundColor(Color(white: 0.12))
                        }
                        .padding(20)
                    }
                } else {
                    HTMLReader(document: document, baseURL: URL(string: content.url))
                        .id(size)
                }
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Button { size = max(14, size - 1) } label: { Image(systemName: "textformat.size.smaller") }
                        Button { size = min(26, size + 1) } label: { Image(systemName: "textformat.size.larger") }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var document: String {
        """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          :root { color-scheme: light; }
          body {
            margin: 0; padding: 20px;
            background: #fbfbfd; color: #14181f;
            font-family: "New York", Georgia, "Times New Roman", serif;
            font-size: \(Int(size))px; line-height: 1.62;
          }
          h1 { font-size: 1.6em; line-height: 1.2; margin: 0 0 6px; letter-spacing: -0.3px; }
          .source { font-family: -apple-system, system-ui, sans-serif; font-size: 11px; color: #7b8494; margin-bottom: 18px; word-break: break-all; }
          hr { border: 0; border-top: 1px solid #e3e5ea; margin: 14px 0 18px; }
          img { max-width: 100%; height: auto; border-radius: 10px; margin: 14px 0; display: block; }
          figure { margin: 14px 0; }
          figcaption { font-family: -apple-system, system-ui, sans-serif; font-size: 11px; color: #7b8494; }
          a { color: #1c4f9c; }
          pre, code { font-family: ui-monospace, Menlo, monospace; font-size: 0.86em; background: #f1f2f5; border-radius: 6px; }
          pre { padding: 10px; overflow-x: auto; }
          blockquote { margin: 14px 0; padding-left: 14px; border-left: 3px solid #d6d9e0; color: #4a5261; }
          table { width: 100%; border-collapse: collapse; font-family: -apple-system, system-ui, sans-serif; font-size: 0.85em; }
          td, th { border-bottom: 1px solid #e3e5ea; padding: 6px; text-align: left; }
        </style>
        </head>
        <body>
          <h1>\(escape(content.title))</h1>
          <div class="source">\(escape(content.url))</div>
          <hr>
          \(content.html)
        </body>
        </html>
        """
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Renders the article document, resolving relative image URLs against the page.
struct HTMLReader: UIViewRepresentable {
    let document: String
    let baseURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        BrowserIdentity.apply(to: webView)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(white: 0.98, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(white: 0.98, alpha: 1)
        webView.allowsLinkPreview = false
        webView.loadHTMLString(document, baseURL: baseURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

/// Find in page: the query, the match count, previous/next, and close.
struct FindBar: View {
    @EnvironmentObject var model: BrowserModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .scaledFont(12, .semibold)
                    .foregroundColor(Theme.muted)

                TextField("", text: $model.findQuery, prompt: Text("Find in page").foregroundColor(Theme.fieldPlaceholder))
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Find in page")
                    .scaledFont(14)
                    .foregroundColor(Theme.ink)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($focused)
                    .onChange(of: model.findQuery) { _ in
                        model.runFind(newQuery: true)
                    }

                Text(model.findState.total == 0 ? "0 of 0" : "\(model.findState.current) of \(model.findState.total)")
                    .scaledFont(10, .medium)
                    .foregroundColor(Theme.muted)
            }
            .padding(.horizontal, 9)
            .frame(height: 36)
            .background(Capsule().fill(Theme.rowFill))
            .layoutPriority(1)

            Button { model.runFind(backwards: true) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(GlassCircleButtonStyle())
            Button { model.runFind() } label: { Image(systemName: "chevron.down") }
                .buttonStyle(GlassCircleButtonStyle())
            Button { model.endFind() } label: { Image(systemName: "xmark") }
                .buttonStyle(GlassCircleButtonStyle())
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.rowFill))
        .padding(.horizontal, 8)
        .onAppear { focused = true }
    }
}

/// Share sheet for a finished PDF or download.
struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
