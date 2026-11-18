import Foundation

/// What the in-app editor should display for a light, and when Home Assistant's
/// report of a change counts as "the same" as what the editor already shows.
///
/// The editor keeps its own control values (so sliders don't jump mid-drag) and
/// mirrors HA's state into them whenever that state changes — from the editor, a
/// widget swatch, Control Center, or HA itself.
public enum EditorSync {
	/// The live on-state for a light that's on. For an off light HA reports no
	/// color or brightness, so show what turning it on will restore — the same
	/// values `toggle` sends.
	public static func display(for light: LightState, lastOn: LightOnState?) -> LightOnState? {
		LightOnState(remembering: light) ?? lastOn
	}

	/// True when two colors share hue and saturation. HA re-derives an xy bulb's
	/// `rgb_color` from its xy point at full value, then quantizes it. An exact
	/// compare would therefore treat the echo of a color we just sent as a new one.
	/// Value (V) is ignored because brightness is a separate control.
	public static func sameColor(_ a: LightRGB, _ b: LightRGB) -> Bool {
		let x = A11yColorName.hsb(r: a.r, g: a.g, b: a.b)
		let y = A11yColorName.hsb(r: b.r, g: b.g, b: b.b)
		let nearWhite = 0.08
		if x.s < nearWhite || y.s < nearWhite { return x.s < nearWhite && y.s < nearWhite }
		let dh = abs(x.h - y.h)
		return min(dh, 1 - dh) <= 0.03 && abs(x.s - y.s) <= 0.12
	}

	/// HA stores color temperature in mireds, so a kelvin value comes back a few
	/// degrees off (2700 → 2702).
	public static func sameKelvin(_ a: Int, _ b: Int) -> Bool { abs(a - b) <= 50 }
}
