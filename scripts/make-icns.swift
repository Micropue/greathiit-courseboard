import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: make-icns.swift <iconset> <output.icns>\n", stderr)
    exit(2)
}

let iconsetURL = URL(
    fileURLWithPath: CommandLine.arguments[1],
    isDirectory: true
)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

let entries: [(chunk: String, file: String)] = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) {
        data.append(contentsOf: $0)
    }
}

var chunks = Data()
for entry in entries {
    let imageURL = iconsetURL.appendingPathComponent(entry.file)
    let imageData = try Data(contentsOf: imageURL)
    let chunkSize = UInt32(imageData.count + 8)

    chunks.append(contentsOf: entry.chunk.utf8)
    appendUInt32(chunkSize, to: &chunks)
    chunks.append(imageData)
}

var iconData = Data("icns".utf8)
appendUInt32(UInt32(chunks.count + 8), to: &iconData)
iconData.append(chunks)
try iconData.write(to: outputURL, options: .atomic)
