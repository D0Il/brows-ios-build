import SwiftUI

/// Downloads: live progress, cancel, open/share, remove, clear.
struct DownloadsSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.ignoresSafeArea()

                if model.downloads.isEmpty {
                    Text("Nothing downloaded yet.")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.panelMuted)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.downloads) { item in
                                row(item)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear", role: .destructive) { model.clearDownloads() }
                        .disabled(model.downloads.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func row(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: item.failed ? "exclamationmark.triangle" : "arrow.down.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Theme.panelMuted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.filename)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.panelInk)
                        .lineLimit(1)
                    Text(item.source)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.panelMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if item.finished, let path = item.localPath {
                    ShareLink(item: URL(fileURLWithPath: path)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.panelMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("download.share")
                }

                if item.failed {
                    Button("Retry") { model.retryDownload(item) }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.panelMuted)
                        .buttonStyle(.plain)
                }

                if !item.finished && !item.failed {
                    Button("Cancel") { model.cancelDownload(item.id) }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.panelMuted)
                        .buttonStyle(.plain)
                }

                Button {
                    model.removeDownload(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.panelMuted)
                }
                .buttonStyle(.plain)
            }

            if !item.finished && !item.failed {
                ProgressView(value: item.progress)
                    .tint(Theme.panelInk)
            } else if item.failed {
                Text("Failed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.panelMuted)
            } else {
                Text("\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(item.localPath)), countStyle: .file)) saved")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.panelMuted)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.rowFill))
    }

    private func fileSize(_ path: String?) -> Int {
        guard let path, let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber else { return 0 }
        return size.intValue
    }

}
