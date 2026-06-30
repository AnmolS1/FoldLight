import XCTest
@testable import FoldKit

/// Round-trips for the App-Group-persisted models. These are pure Codable tests
/// (no container needed) plus the seed-default invariants.
final class PresetAndCacheTests: XCTestCase {

	func testPresetCodableRoundTrip() throws {
		let presets = [
			LightPreset(name: "Movie red", rgb: LightRGB(r: 255, g: 30, b: 20), brightnessPct: 25),
			LightPreset(name: "Warm", kelvin: 2700, brightnessPct: 60),
		]
		let data = try JSONEncoder().encode(presets)
		let decoded = try JSONDecoder().decode([LightPreset].self, from: data)
		XCTAssertEqual(decoded, presets)
		XCTAssertTrue(decoded[0].isColor)
		XCTAssertFalse(decoded[1].isColor)
	}

	func testSeedDefaultsWithinBulbRange() {
		// White presets must be applyable to the 2202–4000 K bulb.
		for preset in LightPreset.seedDefaults where preset.kelvin != nil {
			XCTAssertGreaterThanOrEqual(preset.kelvin!, 2000)
			XCTAssertLessThanOrEqual(preset.kelvin!, 6500)
			XCTAssertTrue((0...100).contains(preset.brightnessPct))
		}
		XCTAssertEqual(LightPreset.seedDefaults.count, 3)
	}

	func testLightStateCodableRoundTrip() throws {
		let light = LightState.sampleColor
		let data = try JSONEncoder().encode(light)
		let decoded = try JSONDecoder().decode(LightState.self, from: data)
		XCTAssertEqual(decoded, light)
	}

	func testLightRGBClampsAndArray() {
		let c = LightRGB(r: 300, g: -5, b: 128)
		XCTAssertEqual(c.r, 255)
		XCTAssertEqual(c.g, 0)
		XCTAssertEqual(c.array, [255, 0, 128])
	}

	func testLightRGBFromArray() {
		XCTAssertEqual(LightRGB([10, 20, 30]), LightRGB(r: 10, g: 20, b: 30))
		XCTAssertNil(LightRGB([1, 2]))     // wrong arity → nil
		XCTAssertNil(LightRGB(nil))
	}
}
