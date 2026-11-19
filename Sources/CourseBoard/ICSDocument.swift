import SwiftUI
import UniformTypeIdentifiers

struct ICSDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [icsType]
    }

    static var writableContentTypes: [UTType] {
        [icsType]
    }

    static let icsType = UTType(filenameExtension: "ics")
        ?? UTType(importedAs: "com.apple.ical.ics")

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents: Data(text.utf8)
        )
    }
}
