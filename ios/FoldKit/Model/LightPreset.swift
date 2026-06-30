import SwiftUI

/// A saved color/temperature + brightness recipe the user dials in the app, then
/// applies from a widget swatch or a Control Center control. Persisted in the App
/// Group (see `PresetStore`) so app + widgets + intents share the same library.
public struct LightPreset: Codable, Sendable, Identifiable, Equatable, Hashable {
	public var id: UUID
	public var name: String
	/// Either an explicit RGB color…
	public var rgb: LightRGB?
	/// …or a white color temperature in Kelvin. Exactly one is expected.
	public var kelvin: Int?
	/// Target brightness 0–100.
	public var brightnessPct: Int

	public init(id: UUID = UUID(), name: String, rgb: LightRGB? = nil, kelvin: Int? = nil, brightnessPct: Int) {
		self.id = id
		self.name = name
		self.rgb = rgb
		self.kelvin = kelvin
		self.brightnessPct = max(0, min(100, brightnessPct))
	}

	/// The swatch color shown in the UI/widget.
	public var swatch: Color {
		if let rgb { return rgb.color }
		if let kelvin { return Color.fromKelvin(kelvin) }
		return .white
	}

	public var isColor: Bool { rgb != nil }
}

public extension LightPreset {
	/// Seed library — installed on first run. `kelvin` ones stay within common
	/// bulb ranges (the IKEA bulb tops out at 4000 K).
	static let seedDefaults: [LightPreset] = [
		LightPreset(name: "Warm", kelvin: 2700, brightnessPct: 60),
		LightPreset(name: "Focus", kelvin: 4000, brightnessPct: 100),
		LightPreset(name: "Movie red", rgb: LightRGB(r: 255, g: 30, b: 20), brightnessPct: 25),
	]
}
