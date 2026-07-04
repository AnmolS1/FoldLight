import XCTest
@testable import FoldKit

final class LauncherStoreTests: XCTestCase {
	func testTargetsRoundTripThroughJSON() throws {
		let targets = [
			LauncherTarget(id: "1", name: "Jellyfin", urlString: "https://jf.example.com", symbol: "tv.fill"),
			LauncherTarget(id: "2", name: "Router", urlString: "http://192.168.1.1", symbol: "network"),
		]
		let data = try JSONEncoder().encode(targets)
		let decoded = try JSONDecoder().decode([LauncherTarget].self, from: data)
		XCTAssertEqual(decoded, targets)
	}

	func testHomeAssistantQuickAddDerivesFromBaseURL() {
		let ha = LauncherStore.homeAssistantTarget(baseURLString: "https://ha.example.com:8123")
		XCTAssertEqual(ha?.id, "ha")
		XCTAssertEqual(ha?.name, "Home Assistant")
		XCTAssertEqual(ha?.urlString, "https://ha.example.com:8123")
		XCTAssertEqual(ha?.symbol, "house.fill")
	}

	func testHomeAssistantQuickAddNilForEmptyOrInvalidURL() {
		XCTAssertNil(LauncherStore.homeAssistantTarget(baseURLString: ""))
		XCTAssertNil(LauncherStore.homeAssistantTarget(baseURLString: " not a url "))
	}

	func testLauncherTargetURLParsing() {
		let target = LauncherTarget(id: "x", name: "X", urlString: "https://x.example.com/path", symbol: "globe")
		XCTAssertEqual(target.url?.host, "x.example.com")
		let bad = LauncherTarget(id: "y", name: "Y", urlString: "", symbol: "globe")
		XCTAssertNil(bad.url)
	}
}
