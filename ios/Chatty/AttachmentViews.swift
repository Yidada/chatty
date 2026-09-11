import SwiftUI
import ChattyCore
import QuickLook
import ImageIO

private func thumbnail(_ data: Data) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 3000, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
    return UIImage(cgImage: image)
}

struct InlineImageView: View {
    let source: String
    let alt: String
    let context: WorkspaceContext
    @State private var image: UIImage?
    @State private var error: String?
    @State private var showing = false
    @State private var retry = 0
    var body: some View {
        Group {
            if let image {
                Button { showing = true } label: {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 300).clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                    .hoverEffect(.lift)
                    .draggable(Image(uiImage: image))
                    .accessibilityLabel(alt.isEmpty ? "查看图片" : alt).accessibilityIdentifier("attachment.inlineImage")
            } else if let error {
                VStack(alignment: .leading) { Text(alt.isEmpty ? "图片" : alt).font(.caption); Text(error).font(.caption).foregroundStyle(.secondary); Button("重试加载图片") { retry += 1 } }
            } else { ProgressView("加载图片…") }
        }
        .task(id: "\(source)-\(retry)") {
            do {
                guard let url = URL(string: source, relativeTo: context.api.baseURL)?.absoluteURL else { throw APIError.invalidURL }
                let data = try await context.api.download(url); try context.check()
                guard let value = thumbnail(data) else { throw APIError.unsafeFile }; image = value; error = nil
            } catch { self.error = await context.report(error) }
        }
        // R4: a full-screen cover fills an iPad screen and loses context. A sheet
        // is a form sheet at regular width and the familiar cover at compact width.
        .sheet(isPresented: $showing) { if let image { ImagePreview(image: image, title: alt) } }
    }
}

struct AttachmentButton: View {
    let attachment: Attachment
    let context: WorkspaceContext
    @State private var loading = false
    @State private var error: String?
    @State private var image: UIImage?
    @State private var showImage = false
    @State private var file: PreviewFile?
    @State private var retainedFile: URL?
    @State private var shareItems: [Any] = []
    @State private var sharing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await open() }
            } label: {
                HStack(spacing: 12) {
                    if loading { ProgressView() } else { Image(systemName: (attachment.contentType ?? "").hasPrefix("image/") ? "photo" : "doc.text").font(.title3) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attachment.filename).lineLimit(2)
                        if let bytes = attachment.sizeBytes { Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 8); Image(systemName: "arrow.down.doc").foregroundStyle(.secondary)
                }.frame(minHeight: 44).padding(12).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain).hoverEffect(.lift)
                .draggable(AttachmentExport(attachment: attachment, api: context.api)) {
                    Label(attachment.filename, systemImage: "doc")
                }
                .disabled(loading)
                .contextMenu {
                    Button("分享…", systemImage: "square.and.arrow.up") { Task { await share() } }
                    Button("打开", systemImage: "arrow.up.forward.app") { Task { await open() } }
                }
                .accessibilityIdentifier("attachment.\(attachment.id)")
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
        .sheet(item: $file) { value in FilePreview(url: value.url, title: attachment.filename) }
        .sheet(isPresented: $sharing, onDismiss: { shareItems = [] }) { ShareSheet(items: shareItems) }
        .onChange(of: file) { _, value in if value == nil { cleanup() } }
        .onDisappear { cleanup() }
        .sheet(isPresented: $showImage, onDismiss: { image = nil }) { if let image { ImagePreview(image: image, title: attachment.filename) } }
    }
    /// Share sheet entry: materialize the remote attachment locally first, so the
    /// receiving app gets real content instead of a URL it cannot read.
    private func share() async {
        guard !loading else { return }
        do {
            let (metadata, data) = try await context.api.attachmentData(attachment); try context.check()
            cleanup()
            let url = try context.files.preview(data, filename: metadata.filename)
            retainedFile = url
            shareItems = [url]
            sharing = true
        } catch { self.error = await context.report(error) }
    }
    private func cleanup() {
        if let retainedFile { try? context.files.removePreview(retainedFile); self.retainedFile = nil }
    }
    private func open() async {
        guard !loading else { return }; loading = true; error = nil; defer { loading = false }
        do {
            let (metadata, data) = try await context.api.attachmentData(attachment); try context.check()
            if (metadata.contentType ?? "").hasPrefix("image/"), metadata.contentType != "image/svg+xml", let value = thumbnail(data) {
                image = value; showImage = true
            } else {
                let type = (metadata.contentType ?? "").lowercased(); let ext = URL(fileURLWithPath: metadata.filename).pathExtension.lowercased()
                let sourceOnly = type.contains("html") || type.contains("svg") || ["html", "htm", "svg", "mmd", "mermaid", "js"].contains(ext)
                cleanup()
                let url = try context.files.preview(data, filename: sourceOnly ? "source.txt" : metadata.filename)
                retainedFile = url; file = PreviewFile(url: url)
            }
        } catch { self.error = await context.report(error) }
    }
}

struct ImagePreview: View {
    let image: UIImage
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZoomableImage(image: image).ignoresSafeArea(edges: .bottom)
                .navigationTitle(title.isEmpty ? "图片" : title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.accessibilityIdentifier("preview.close") }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(title.isEmpty ? "图片" : title, image: Image(uiImage: image)))
                            .accessibilityLabel("分享或保存图片")
                    }
                }
        }
    }
}

/// Drag-out payload for a remote attachment. The file is materialized on demand,
/// so dragging works even though the attachment only exists on the server.
struct AttachmentExport: Transferable {
    let attachment: Attachment
    let api: APIClient
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { item in
            try await item.api.attachmentData(item.attachment).1
        }
    }
}

/// `ShareLink` needs its item up front; the context menu downloads first and then
/// presents the standard activity sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView(); scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 5; scroll.delegate = context.coordinator
        scroll.backgroundColor = .systemBackground
        let view = UIImageView(image: image); view.contentMode = .scaleAspectFit; view.isAccessibilityElement = true; view.accessibilityLabel = "图片预览，可双指缩放"
        scroll.addSubview(view); context.coordinator.image = view; return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.image?.image = image
        context.coordinator.image?.frame = scroll.bounds
        context.coordinator.image?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var image: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { image }
    }
}

private struct PreviewFile: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
}

private struct FilePreview: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if QLPreviewController.canPreview(url as NSURL) { DocumentPreview(url: url) }
                else { ContentUnavailableView("此文件无法直接预览", systemImage: "doc", description: Text("可通过分享按钮保存到文件或选择其他应用打开。")) }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.accessibilityIdentifier("preview.close") }
                ToolbarItem(placement: .primaryAction) { ShareLink(item: url).accessibilityLabel("分享或保存文件") }
            }
        }
    }
}

private struct DocumentPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { url as NSURL }
    }
}

struct LinkedAttachmentScreen: View {
    let id: String
    let context: WorkspaceContext
    @State private var attachment: Attachment?
    @State private var error: String?
    @State private var retry = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let attachment { AttachmentButton(attachment: attachment, context: context) }
            else if let error { ErrorNotice(text: error, identifier: "attachment.linkError"); Button("重新读取") { retry += 1 } }
            else { ProgressView("读取附件…") }
            Spacer()
        }.padding(20).navigationTitle("附件")
            .task(id: retry) {
                do {
                    let value: Attachment = try await context.api.get("/api/attachments/\(APIClient.segment(id))")
                    try context.check(); attachment = value; error = nil
                } catch { self.error = await context.report(error) }
            }
    }
}
