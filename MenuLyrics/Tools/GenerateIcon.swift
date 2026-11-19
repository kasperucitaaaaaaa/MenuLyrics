import AppKit

// Vector artwork rasterized at each macOS icon resolution.
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32), ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256), ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512), ("icon_512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: Double(pixels) / 1024, y: Double(pixels) / 1024)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 204, yRadius: 204).fill()
    NSColor.black.setFill()
    // A single eighth note with a curved flag.
    NSBezierPath(roundedRect: NSRect(x: 506, y: 310, width: 58, height: 454), xRadius: 12, yRadius: 12).fill()
    let flag = NSBezierPath()
    flag.move(to: NSPoint(x: 550, y: 764))
    flag.curve(to: NSPoint(x: 686, y: 523), controlPoint1: NSPoint(x: 570, y: 672), controlPoint2: NSPoint(x: 772, y: 663))
    flag.curve(to: NSPoint(x: 558, y: 647), controlPoint1: NSPoint(x: 706, y: 619), controlPoint2: NSPoint(x: 588, y: 608))
    flag.close(); flag.fill()
    let head = NSBezierPath(ovalIn: NSRect(x: -110, y: -78, width: 220, height: 156))
    var transform = AffineTransform()
    transform.translate(x: 452, y: 316)
    transform.rotate(byDegrees: 22)
    head.transform(using: transform); head.fill()
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
}

// ICNS stores the PNG representations as typed, big-endian length records.
func lengthBytes(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}
var records = Data()
for (type, name) in [("icp4", "icon_16x16"), ("icp5", "icon_32x32"), ("icp6", "icon_32x32@2x"), ("ic07", "icon_128x128"), ("ic08", "icon_256x256"), ("ic09", "icon_512x512"), ("ic10", "icon_512x512@2x"), ("ic11", "icon_16x16@2x"), ("ic12", "icon_32x32@2x"), ("ic13", "icon_128x128@2x"), ("ic14", "icon_256x256@2x")] {
    let png = try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
    records.append(Data(type.utf8)); records.append(lengthBytes(png.count + 8)); records.append(png)
}
var icns = Data("icns".utf8); icns.append(lengthBytes(records.count + 8)); icns.append(records)
try icns.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
