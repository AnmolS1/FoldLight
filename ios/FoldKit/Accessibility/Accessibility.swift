import SwiftUI

/// Accessibility helpers shared by the app and the widget extension (this folder
/// compiles into both). Everything here is pure and testable except the one
/// `announce` wrapper, so VoiceOver value strings and nearest-named-color logic
/// can be asserted in FoldKitTests without a UI-test target.

// MARK: - Spoken announcements

public enum A11yAnnounce {
	/// Post a VoiceOver / screen-reader announcement. `AccessibilityNotification`
	/// is SwiftUI-native on iOS 17 and macOS 14, so callers stay cross-platform
	/// with no UIKit/AppKit branching.
	@MainActor public static func post(_ message: String) {
		AccessibilityNotification.Announcement(message).post()
	}
}

// MARK: - Value strings (VoiceOver `.accessibilityValue`)

public enum A11yValue {
	/// "60 percent" — brightness spoken value.
	public static func brightness(_ pct: Int) -> String {
		"\(pct) percent"
	}

	/// "3000 kelvin, warm white" — white-temperature spoken value. The trailing
	/// warmth word ("warm"/"neutral"/"cool") lets VoiceOver users hear which way
	/// the slider moves without seeing the tint.
	public static func temperature(_ kelvin: Int) -> String {
		"\(kelvin) kelvin, \(warmthWord(kelvin))"
	}

	/// A coarse warmth descriptor for a color temperature.
	public static func warmthWord(_ kelvin: Int) -> String {
		switch kelvin {
		case ..<2700: return "very warm"
		case 2700..<3400: return "warm white"
		case 3400..<4600: return "neutral white"
		case 4600..<5500: return "cool white"
		default: return "daylight"
		}
	}
}

// MARK: - Nearest named color

public enum A11yColorName {
	/// The nearest human name for an HSB color (hue/saturation/brightness each
	/// 0…1). Used by the editor's adjustable HSB rows and preset/state labels so
	/// color is conveyed by name, not tint alone.
	public static func name(hue: Double, saturation: Double, brightness: Double) -> String {
		if brightness < 0.06 { return "off" }
		if saturation < 0.12 {
			// Near-gray: describe by lightness.
			switch brightness {
			case ..<0.25: return "near black"
			case ..<0.6: return "gray"
			case ..<0.92: return "soft white"
			default: return "white"
			}
		}
		let deg = (hue * 360).truncatingRemainder(dividingBy: 360)
		let base: String
		switch deg {
		case ..<15, 345...: base = "red"
		case 15..<45: base = "crane orange"
		case 45..<70: base = "gold"
		case 70..<95: base = "lime"
		case 95..<160: base = "green"
		case 160..<200: base = "teal"
		case 200..<255: base = "blue"
		case 255..<290: base = "purple"
		case 290..<330: base = "magenta"
		default: base = "pink"
		}
		// A dim, saturated hue reads as "deep"; a pale one as "pastel".
		if brightness < 0.4 { return "deep \(base)" }
		if saturation < 0.4 { return "pastel \(base)" }
		return base
	}

	/// Nearest named color for an sRGB triple (0…255 per channel).
	public static func name(r: Int, g: Int, b: Int) -> String {
		let (h, s, v) = hsb(r: r, g: g, b: b)
		return name(hue: h, saturation: s, brightness: v)
	}

	/// sRGB (0…255) → HSB (each 0…1). Pure, so it's unit-testable.
	public static func hsb(r: Int, g: Int, b: Int) -> (h: Double, s: Double, v: Double) {
		let rd = Double(max(0, min(255, r))) / 255
		let gd = Double(max(0, min(255, g))) / 255
		let bd = Double(max(0, min(255, b))) / 255
		let mx = max(rd, gd, bd)
		let mn = min(rd, gd, bd)
		let delta = mx - mn
		var h = 0.0
		if delta > 0 {
			if mx == rd { h = ((gd - bd) / delta).truncatingRemainder(dividingBy: 6) }
			else if mx == gd { h = (bd - rd) / delta + 2 }
			else { h = (rd - gd) / delta + 4 }
			h /= 6
			if h < 0 { h += 1 }
		}
		let s = mx == 0 ? 0 : delta / mx
		return (h, s, mx)
	}
}
