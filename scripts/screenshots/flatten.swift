import AppKit
import Foundation

// flatten <file.png> — rewrite the PNG with no alpha channel (opaque), same pixel
// size. simctl screenshots are opaque but carry an alpha channel, which App Store
// Connect rejects.
let a = CommandLine.arguments
guard a.count == 2, let img = NSImage(contentsOfFile: a[1]),
      let rep0 = img.representations.first else { exit(1) }
let w = rep0.pixelsWide, h = rep0.pixelsHigh
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(2) }
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
var proposed = CGRect(x: 0, y: 0, width: w, height: h)
guard let cg = img.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { exit(3) }
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
guard let out = ctx.makeImage() else { exit(4) }
guard let data = NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:]) else { exit(5) }
try! data.write(to: URL(fileURLWithPath: a[1]))
