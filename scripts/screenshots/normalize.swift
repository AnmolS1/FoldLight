import AppKit
import Foundation

// normalize <in.png> <out.png> <canvasW> <canvasH> <hexBG>
// Scales the input to fit within the canvas (with a small margin), centers it on an
// opaque canvas of the given background color, and writes an opaque PNG — flattening
// the capture's transparent rounded corners in the process.
let a = CommandLine.arguments
guard a.count == 6,
      let inImg = NSImage(contentsOfFile: a[1]),
      let canvasW = Int(a[3]), let canvasH = Int(a[4]) else {
	FileHandle.standardError.write(Data("usage: normalize in out W H hex\n".utf8)); exit(1)
}
let hex = a[5].hasPrefix("#") ? String(a[5].dropFirst()) : a[5]
var v: UInt64 = 0; Scanner(string: hex).scanHexInt64(&v)
let bg = NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                 green: CGFloat((v >> 8) & 0xFF) / 255,
                 blue: CGFloat(v & 0xFF) / 255, alpha: 1)

// Source pixel size (use the bitmap rep, not the point-based NSImage.size).
let rep0 = inImg.representations.first!
let srcW = CGFloat(rep0.pixelsWide), srcH = CGFloat(rep0.pixelsHigh)

// Fit within canvas leaving a margin (top/bottom ~6%).
let margin: CGFloat = 0.90
let scale = min(CGFloat(canvasW) * margin / srcW, CGFloat(canvasH) * margin / srcH)
let drawW = (srcW * scale).rounded(), drawH = (srcH * scale).rounded()
let x = ((CGFloat(canvasW) - drawW) / 2).rounded()
let y = ((CGFloat(canvasH) - drawH) / 2).rounded()

guard let ctx = CGContext(data: nil, width: canvasW, height: canvasH, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(2) }
ctx.setFillColor(bg.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))

var proposed = CGRect(x: 0, y: 0, width: srcW, height: srcH)
guard let cg = inImg.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { exit(3) }
ctx.interpolationQuality = .high
ctx.draw(cg, in: CGRect(x: x, y: y, width: drawW, height: drawH))

guard let out = ctx.makeImage() else { exit(4) }
let rep = NSBitmapImageRep(cgImage: out)
guard let data = rep.representation(using: .png, properties: [:]) else { exit(5) }
try! data.write(to: URL(fileURLWithPath: a[2]))
