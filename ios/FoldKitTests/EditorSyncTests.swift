import XCTest
@testable import FoldKit

/// The in-app editor mirrors the bulb's reported state. These pin what it shows
/// and when an HA echo of our own change counts as "the same".
final class EditorSyncTests: XCTestCase {
	private func light(on: Bool, brightness: Int? = nil, rgb: LightRGB? = nil, kelvin: Int? = nil) -> LightState {
		LightState(entityID: "light.yetstrhom", name: "Yetstrhöm", isOn: on,
		           brightnessPct: brightness, rgb: rgb, colorTempKelvin: kelvin,
		           supportedColorModes: ["color_temp", "xy"], minKelvin: 2202, maxKelvin: 4000)
	}

	// MARK: display(for:lastOn:)

	func testOnLightShowsItsLiveState() {
		let shown = EditorSync.display(for: light(on: true, brightness: 50, rgb: LightRGB(r: 255, g: 0, b: 255)),
		                               lastOn: LightOnState(brightnessPct: 10, kelvin: 2700))
		XCTAssertEqual(shown, LightOnState(brightnessPct: 50, rgb: LightRGB(r: 255, g: 0, b: 255)))
	}

	func testOffLightShowsWhatTurningOnWillRestore() {
		// The recording's bug: HA reports no color/brightness for an off bulb, so the
		// editor fell back to its hard-coded orange/100% and never corrected itself.
		let last = LightOnState(brightnessPct: 50, rgb: LightRGB(r: 128, g: 0, b: 128))
		XCTAssertEqual(EditorSync.display(for: light(on: false), lastOn: last), last)
	}

	func testOffLightWithNoHistoryShowsNothing() {
		XCTAssertNil(EditorSync.display(for: light(on: false), lastOn: nil))
	}

	// MARK: sameColor — HA's xy round-trip must not read as a new color

	func testXYRenormalizedEchoIsSameColor() {
		// HA reports an xy bulb's rgb_color at full value: a dim purple comes back bright.
		XCTAssertTrue(EditorSync.sameColor(LightRGB(r: 128, g: 0, b: 128), LightRGB(r: 255, g: 0, b: 255)))
	}

	func testSmallQuantizationDriftIsSameColor() {
		XCTAssertTrue(EditorSync.sameColor(LightRGB(r: 255, g: 170, b: 90), LightRGB(r: 255, g: 168, b: 94)))
	}

	func testHueWrapsAroundRed() {
		XCTAssertTrue(EditorSync.sameColor(LightRGB(r: 255, g: 0, b: 6), LightRGB(r: 255, g: 6, b: 0)))
	}

	func testDifferentHueIsDifferentColor() {
		XCTAssertFalse(EditorSync.sameColor(LightRGB(r: 128, g: 0, b: 128), LightRGB(r: 0, g: 60, b: 128)))
	}

	func testSaturationChangeIsDifferentColor() {
		XCTAssertFalse(EditorSync.sameColor(LightRGB(r: 255, g: 0, b: 0), LightRGB(r: 255, g: 160, b: 160)))
	}

	func testNearWhitesAreSameRegardlessOfHue() {
		XCTAssertTrue(EditorSync.sameColor(LightRGB(r: 255, g: 252, b: 250), LightRGB(r: 250, g: 255, b: 252)))
	}

	// MARK: sameKelvin — mired round-trip

	func testKelvinMiredDriftIsSame() {
		XCTAssertTrue(EditorSync.sameKelvin(2700, 2702))
		XCTAssertFalse(EditorSync.sameKelvin(2700, 3400))
	}
}

extension EditorSyncTests {
	func testWhiteModeLightShowsTemperature() {
		let shown = EditorSync.display(for: light(on: true, brightness: 60, rgb: LightRGB(r: 255, g: 180, b: 110), kelvin: 2700),
		                               lastOn: nil)
		XCTAssertEqual(shown, LightOnState(brightnessPct: 60, kelvin: 2700))
	}
}
