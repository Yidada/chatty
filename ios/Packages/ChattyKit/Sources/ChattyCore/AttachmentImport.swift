import Foundation
import UniformTypeIdentifiers

/// A file that has been read into memory and validated against the same limits
/// the composer enforces for picker-based attachments. Drag-and-drop from
/// Files / Photos / other apps and the composer's file picker share this path so
/// neither can bypass the size and regular-file checks.
public struct ImportedAttachment: Sendable, Equatable {
    public let data: Data
    public let filename: String
    public let contentType: String
    public init(data: Data, filename: String, contentType: String) {
        self.data = data; self.filename = filename; self.contentType = contentType
    }
}

public enum AttachmentImport {
    /// Reads a security-scoped file URL (picker result or a Files/other-app drop).
    public static func read(fileURL url: URL) throws -> ImportedAttachment {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentTypeKey])
        guard values.isRegularFile == true else { throw APIError.unsafeFile }
        guard (values.fileSize ?? Int.max) <= APIClient.maximumFileBytes else { throw APIError.oversizedFile }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try prepared(data: data, filename: url.lastPathComponent, contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream")
    }

    /// Validates in-memory data dropped by an app that does not hand over a file URL.
    public static func prepared(data: Data, filename: String, contentType: String) throws -> ImportedAttachment {
        guard !data.isEmpty else { throw APIError.unsafeFile }
        guard data.count <= APIClient.maximumFileBytes else { throw APIError.oversizedFile }
        return ImportedAttachment(data: data,
                                  filename: filename.isEmpty ? "attachment" : filename,
                                  contentType: contentType.isEmpty ? "application/octet-stream" : contentType)
    }
}
