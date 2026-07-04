import XCTest
@testable import FoldKit

final class LightPrefsTests: XCTestCase {
	private func light(_ id: String, name: String? = nil, color: Bool = false) -> LightState {
		LightState(
			entityID: id, name: name ?? id, isOn: false,
			supportedColorModes: color ? ["xy"] : ["onoff"]
		)
	}

	func testPrefsRoundTrip() throws {
		let prefs = LightPrefs(
			mainLightID: "light.a",
			favoriteIDs: ["light.b", "light.a"],
			renames: ["light.a": "Alpha"]
		)
		let data = try JSONEncoder().encode(prefs)
		let decoded = try JSONDecoder().decode(LightPrefs.self, from: data)
		XCTAssertEqual(decoded, prefs)
	}

	func testArrangeAppliesFavoritesOrderThenDetectionOrder() {
		let lights = [light("light.a"), light("light.b"), light("light.c")]
		let prefs = LightPrefs(favoriteIDs: ["light.c", "light.a"])
		XCTAssertEqual(prefs.arrange(lights).map(\.entityID), ["light.c", "light.a", "light.b"])
	}

	func testArrangeAppliesRenames() {
		let prefs = LightPrefs(renames: ["light.a": "Alpha"])
		let arranged = prefs.arrange([light("light.a"), light("light.b", name: "Bee")])
		XCTAssertEqual(arranged.map(\.name), ["Alpha", "Bee"])
	}

	func testEmptyFavoritesKeepsDetectionOrder() {
		let lights = [light("light.b"), light("light.a")]
		XCTAssertEqual(LightPrefs().arrange(lights).map(\.entityID), ["light.b", "light.a"])
	}

	func testDisplayNameFallsBackToLightName() {
		let prefs = LightPrefs(renames: ["light.a": "Alpha"])
		XCTAssertEqual(prefs.displayName(for: light("light.a", name: "Original")), "Alpha")
		XCTAssertEqual(prefs.displayName(for: light("light.b", name: "Bee")), "Bee")
	}
}
