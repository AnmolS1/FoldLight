import XCTest
@testable import FoldKit

final class LastLightStateTests: XCTestCase {
	private func light(on: Bool, brightness: Int? = nil, rgb: LightRGB? = nil, kelvin: Int? = nil) -> LightState {
		LightState(entityID: "light.a", name: "A", isOn: on,
		           brightnessPct: brightness, rgb: rgb, colorTempKelvin: kelvin,
		           supportedColorModes: ["xy", "color_temp"])
	}

	func testOffLightRemembersNothing() {
		XCTAssertNil(LightOnState(remembering: light(on: false, brightness: 80, rgb: LightRGB(r: 1, g: 2, b: 3))))
	}

	func testPrefersColorOverTemperature() {
		let s = LightOnState(remembering: light(on: true, brightness: 70,
		                                        rgb: LightRGB(r: 255, g: 170, b: 90), kelvin: 2700))
		XCTAssertEqual(s?.brightnessPct, 70)
		XCTAssertEqual(s?.rgb, LightRGB(r: 255, g: 170, b: 90))
		XCTAssertNil(s?.kelvin, "A color light shouldn't also carry a temperature (ambiguous for turn_on)")
	}

	func testUsesTemperatureWhenNoColor() {
		let s = LightOnState(remembering: light(on: true, brightness: 45, kelvin: 3400))
		XCTAssertEqual(s?.brightnessPct, 45)
		XCTAssertNil(s?.rgb)
		XCTAssertEqual(s?.kelvin, 3400)
	}

	func testHasValueAndRoundTrip() throws {
		let s = LightOnState(brightnessPct: 60, rgb: nil, kelvin: 2700)
		XCTAssertTrue(s.hasValue)
		XCTAssertFalse(LightOnState().hasValue)
		let decoded = try JSONDecoder().decode(LightOnState.self, from: JSONEncoder().encode(s))
		XCTAssertEqual(decoded, s)
	}
}
