import CoreGraphics
import Foundation

// Print the CGWindowID of the largest on-screen, normal-layer window owned by the
// named process. Used to drive `screencapture -l <id>`.
let owner = CommandLine.arguments.dropFirst().first ?? "FoldLight"
let opts = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
	FileHandle.standardError.write(Data("no window list\n".utf8)); exit(1)
}
var best: (id: Int, area: Double)?
for w in list {
	guard let name = w[kCGWindowOwnerName as String] as? String, name == owner,
	      let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
	      let num = w[kCGWindowNumber as String] as? Int,
	      let b = w[kCGWindowBounds as String] as? [String: Any],
	      let width = b["Width"] as? Double, let height = b["Height"] as? Double
	else { continue }
	let area = width * height
	if best == nil || area > best!.area { best = (num, area) }
}
if let best { print(best.id) } else { FileHandle.standardError.write(Data("no window for \(owner)\n".utf8)); exit(2) }
