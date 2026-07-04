import SwiftUI

/// A simple sRGB triple (0–255 per channel) — the wire format Home Assistant uses
/// for `rgb_color`.
public struct LightRGB: Codable, Sendable, Equatable, Hashable {
	public var r: Int
	public var g: Int
	public var b: Int

	public init(r: Int, g: Int, b: Int) {
		self.r = max(0, min(255, r))
		self.g = max(0, min(255, g))
		self.b = max(0, min(255, b))
	}

	/// Array form for the HA service payload (`rgb_color: [r, g, b]`).
	public var array: [Int] { [r, g, b] }

	public var color: Color { Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }

	public init?(_ array: [Int]?) {
		guard let a = array, a.count == 3 else { return nil }
		self.init(r: a[0], g: a[1], b: a[2])
	}
}

/// Home Assistant color-mode strings (subset we care about).
public enum HAColorMode {
	public static let onoff = "onoff"
	public static let brightnessOnly = "brightness"
	public static let colorTemp = "color_temp"
	/// Modes that carry an actual color the user can pick.
	public static let colorful: Set<String> = ["hs", "xy", "rgb", "rgbw", "rgbww"]
}

/// A normalized snapshot of one `light.*` entity. Decoded from HA `/api/states`,
/// cached in the App Group, and rendered by the app + widgets.
public struct LightState: Codable, Sendable, Identifiable, Equatable {
	public var entityID: String
	public var name: String
	public var isOn: Bool
	/// 0–100, nil when off/unknown. (HA reports `brightness` 0–255 — converted on decode.)
	public var brightnessPct: Int?
	public var rgb: LightRGB?
	public var colorTempKelvin: Int?
	public var supportedColorModes: [String]
	public var minKelvin: Int?
	public var maxKelvin: Int?

	public var id: String { entityID }

	public init(
		entityID: String,
		name: String,
		isOn: Bool,
		brightnessPct: Int? = nil,
		rgb: LightRGB? = nil,
		colorTempKelvin: Int? = nil,
		supportedColorModes: [String] = [],
		minKelvin: Int? = nil,
		maxKelvin: Int? = nil
	) {
		self.entityID = entityID
		self.name = name
		self.isOn = isOn
		self.brightnessPct = brightnessPct
		self.rgb = rgb
		self.colorTempKelvin = colorTempKelvin
		self.supportedColorModes = supportedColorModes
		self.minKelvin = minKelvin
		self.maxKelvin = maxKelvin
	}

	// MARK: Capabilities (gate the UI on what the bulb actually supports)

	/// Any mode other than bare on/off implies brightness control works.
	public var supportsBrightness: Bool {
		!supportedColorModes.allSatisfy { $0 == HAColorMode.onoff }
			&& !supportedColorModes.isEmpty
	}

	public var supportsColor: Bool {
		!Set(supportedColorModes).isDisjoint(with: HAColorMode.colorful)
	}

	public var supportsColorTemp: Bool {
		supportedColorModes.contains(HAColorMode.colorTemp)
	}

	public var isOnOffOnly: Bool {
		supportedColorModes == [HAColorMode.onoff] || (!supportsBrightness && !supportsColor && !supportsColorTemp)
	}

	/// The color to render the bulb in: explicit RGB if present, else a warm tint
	/// derived from the color temperature, else nil (use theme accent).
	public var displayColor: Color? {
		if let rgb { return rgb.color }
		if let k = colorTempKelvin { return Color.fromKelvin(k) }
		return nil
	}
}

public extension LightState {
	/// A bundled sample light (the IKEA color bulb) for previews/placeholders.
	static let sampleColor = LightState(
		entityID: "light.yetstrhom", name: "Yetstrhöm", isOn: true,
		brightnessPct: 70, rgb: LightRGB(r: 255, g: 170, b: 90),
		colorTempKelvin: 2700, supportedColorModes: ["color_temp", "xy"],
		minKelvin: 2202, maxKelvin: 4000
	)

	/// A bundled sample on/off-only light (the printer chamber light).
	static let sampleOnOff = LightState(
		entityID: "light.x1c_chamber_light", name: "X1C Chamber Light", isOn: false,
		supportedColorModes: ["onoff"]
	)

	/// A bundled sample temperature-only light (no color) so the editor's
	/// capability gating — brightness + white slider, no color picker — is
	/// explorable in mock/demo mode.
	static let sampleTempOnly = LightState(
		entityID: "light.desk_lamp", name: "Desk Lamp", isOn: true,
		brightnessPct: 45, colorTempKelvin: 3400,
		supportedColorModes: ["color_temp"],
		minKelvin: 2700, maxKelvin: 6500
	)

	static let samples = [sampleColor, sampleTempOnly, sampleOnOff]
}

public extension Color {
	/// Rough blackbody approximation so a color-temp value renders as a tint.
	static func fromKelvin(_ kelvin: Int) -> Color {
		let t = Double(max(1000, min(40000, kelvin))) / 100
		func clamp(_ v: Double) -> Double { max(0, min(255, v)) }
		var r, g, b: Double
		if t <= 66 { r = 255 } else { r = clamp(329.698727446 * pow(t - 60, -0.1332047592)) }
		if t <= 66 { g = clamp(99.4708025861 * log(t) - 161.1195681661) }
		else { g = clamp(288.1221695283 * pow(t - 60, -0.0755148492)) }
		if t >= 66 { b = 255 }
		else if t <= 19 { b = 0 }
		else { b = clamp(138.5177312231 * log(t - 10) - 305.0447927307) }
		return Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255)
	}
}
