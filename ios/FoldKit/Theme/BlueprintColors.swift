import SwiftUI

public extension Color {
	/// Hex initializer supporting `#RRGGBB` / `RRGGBB` and an optional alpha 0…1.
	init(hex: String, alpha: Double = 1) {
		var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		if s.hasPrefix("#") { s.removeFirst() }
		var v: UInt64 = 0
		Scanner(string: s).scanHexInt64(&v)
		let r = Double((v & 0xFF0000) >> 16) / 255
		let g = Double((v & 0x00FF00) >> 8) / 255
		let b = Double(v & 0x0000FF) / 255
		self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
	}
}

/// The ponderance blueprint palette — duplicated from homelab-glance (the prompt
/// sanctions duplicating the small theme rather than sharing a package). `up` is a
/// derived muted green; `crane`/`sax` are the accent colors.
public struct BlueprintColors: Sendable, Equatable {
	public var graph: Color        // page ground
	public var card: Color         // card fill
	public var ink: Color          // primary text
	public var ink60: Color        // secondary text
	public var crease: Color       // hairlines / blue accent
	public var creaseLine: Color   // faint grid + dividers
	public var crane: Color        // primary accent
	public var sax: Color          // gold accent
	public var up: Color           // derived healthy green

	public static let dark = BlueprintColors(
		graph: Color(hex: "#13202A"),
		card: Color(hex: "#182530"),
		ink: Color(hex: "#E9ECE7"),
		ink60: Color(hex: "#E9ECE7", alpha: 0.66),
		crease: Color(hex: "#82A9CE"),
		creaseLine: Color(hex: "#82A9CE", alpha: 0.22),
		crane: Color(hex: "#F5613C"),
		sax: Color(hex: "#D9A521"),
		up: Color(hex: "#6FB58A")
	)

	public static let light = BlueprintColors(
		graph: Color(hex: "#EEF0EC"),
		card: Color(hex: "#FFFFFF"),
		ink: Color(hex: "#1B2A33"),
		ink60: Color(hex: "#1B2A33", alpha: 0.62),
		crease: Color(hex: "#2E5E8C"),
		creaseLine: Color(hex: "#2E5E8C", alpha: 0.20),
		crane: Color(hex: "#E84A27"),
		sax: Color(hex: "#B8860B"),
		up: Color(hex: "#3E8E5E")
	)

	public static func resolve(_ scheme: ColorScheme) -> BlueprintColors {
		scheme == .light ? .light : .dark
	}
}

// MARK: - Environment

private struct BlueprintColorsKey: EnvironmentKey {
	static let defaultValue = BlueprintColors.dark
}

public extension EnvironmentValues {
	var blueprint: BlueprintColors {
		get { self[BlueprintColorsKey.self] }
		set { self[BlueprintColorsKey.self] = newValue }
	}
}
