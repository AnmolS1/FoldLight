import XCTest
@testable import FoldKit

/// Decodes the captured real `/api/states` fixtures for both of Anmol's lights and
/// asserts the mapping + capability gating the UI relies on.
final class LightDecodingTests: XCTestCase {

	private func fixture(_ name: String) throws -> LightState {
		let bundle = Bundle(for: Self.self)
		let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"),
		                        "Missing fixture \(name).json in test bundle")
		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode(HAEntityDTO.self, from: data).lightState
	}

	// MARK: yetstrhom — the color bulb (color_temp + xy), currently off

	func testColorBulbOff() throws {
		let light = try fixture("state-yetstrhom")
		XCTAssertEqual(light.entityID, "light.yetstrhom")
		XCTAssertEqual(light.name, "Yetstrhöm")
		XCTAssertFalse(light.isOn)
		XCTAssertNil(light.brightnessPct)            // off → no brightness surfaced
		XCTAssertEqual(light.supportedColorModes, ["color_temp", "xy"])
		XCTAssertEqual(light.minKelvin, 2202)
		XCTAssertEqual(light.maxKelvin, 4000)
	}

	func testColorBulbCapabilities() throws {
		let light = try fixture("state-yetstrhom")
		XCTAssertTrue(light.supportsBrightness)
		XCTAssertTrue(light.supportsColor)           // xy ∈ colorful
		XCTAssertTrue(light.supportsColorTemp)
		XCTAssertFalse(light.isOnOffOnly)
	}

	func testColorBulbOnBrightnessAndColor() throws {
		let light = try fixture("state-yetstrhom-on")
		XCTAssertTrue(light.isOn)
		XCTAssertEqual(light.brightnessPct, 75)      // 191/255 ≈ 75
		XCTAssertEqual(light.rgb, LightRGB(r: 255, g: 170, b: 90))
		XCTAssertNotNil(light.displayColor)
	}

	// MARK: x1c_chamber_light — on/off only

	func testChamberLightOnOffOnly() throws {
		let light = try fixture("state-x1c_chamber_light")
		XCTAssertEqual(light.entityID, "light.x1c_chamber_light")
		XCTAssertEqual(light.supportedColorModes, ["onoff"])
		XCTAssertTrue(light.isOnOffOnly)
		XCTAssertFalse(light.supportsBrightness)
		XCTAssertFalse(light.supportsColor)
		XCTAssertFalse(light.supportsColorTemp)
	}
}
