import SwiftUI
import ChattyCore
import Quartz
import AppKit
import ImageIO

private func thumbnail(_ data: Data) -> NSImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 3000, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
    return NSImage(cgImage: image, size: .zero)
}

struct InlineImageView: View {
    let source: String
    let alt: String
    let context: WorkspaceContext
    @State private var image: NSImage?
    @State private var error: String?
    @State private var showing = false
    @State private var retry = 0
    var body: some View {
        Group {
            if let image {
                Button { showing = true } label: {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 300).clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityLabel(alt.isEmpty ? "查看图片" : alt).accessibilityIdentifier("attachment.inlineImage")
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
        .sheet(isPresented: $showing) { if let image { ImagePreview(image: image, title: alt) } }
    }
}

struct AttachmentButton: View {
    let attachment: Attachment
    let context: WorkspaceContext
    @State private var loading = false
    @State private var error: String?
    @State private var image: NSImage?
    @State private var showImage = false
    @State private var file: PreviewFile?
    @State private var retainedFile: URL?
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
            }.buttonStyle(.plain).disabled(loading).accessibilityIdentifier("attachment.\(attachment.id)")
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
        .sheet(item: $file) { value in FilePreview(url: value.url, title: attachment.filename) }
        .onChange(of: file) { _, value in if value == nil { cleanup() } }
        .onDisappear { cleanup() }
        .sheet(isPresented: $showImage, onDismiss: { image = nil }) { if let image { ImagePreview(image: image, title: attachment.filename) } }
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
    let image: NSImage
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZoomableImage(image: image).ignoresSafeArea(edges: .bottom)
                .navigationTitle(title.isEmpty ? "图片" : title)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.accessibilityIdentifier("preview.close") } }
        }
    }
}

private struct ZoomableImage: View {
    let image: NSImage
    @State private var scale = 1.0
    var body: some View {
        VStack {
            HStack { Text("缩放"); Slider(value: $scale, in: 0.5...3); Text("\(Int(scale * 100))%").monospacedDigit() }.padding()
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 640 * scale).padding()
            }
        }.frame(width: 720, height: 560)
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
                DocumentPreview(url: url).frame(width: 720, height: 560)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.accessibilityIdentifier("preview.close") }
                ToolbarItem(placement: .primaryAction) { ShareLink(item: url).accessibilityLabel("分享或保存文件") }
            }
        }
    }
}

private struct DocumentPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = false
        view.previewItem = url as NSURL
        return view
    }
    func updateNSView(_ view: QLPreviewView, context: Context) { view.previewItem = url as NSURL }
    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) { view.previewItem = nil; view.close() }
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
