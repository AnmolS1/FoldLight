import XCTest
@testable import FoldKit

/// `LiveLightClient.normalizedBase` reduces pasted user input to the HA root.
final class URLNormalizationTests: XCTestCase {
	func testRootUnchanged() {
		XCTAssertEqual(LiveLightClient.normalizedBase("https://homeassistant.internal.ponderance.dev"),
		               "https://homeassistant.internal.ponderance.dev")
	}

	func testTrailingSlashStripped() {
		XCTAssertEqual(LiveLightClient.normalizedBase("https://ha.example.com/"),
		               "https://ha.example.com")
	}

	func testAddsHTTPSWhenSchemeMissing() {
		XCTAssertEqual(LiveLightClient.normalizedBase("homeassistant.internal.ponderance.dev"),
		               "https://homeassistant.internal.ponderance.dev")
	}

	func testStripsPastedAPIEndpoints() {
		XCTAssertEqual(LiveLightClient.normalizedBase("http://100.65.218.62:8123/api/states"),
		               "http://100.65.218.62:8123")
		XCTAssertEqual(LiveLightClient.normalizedBase("http://100.65.218.62:8123/api/"),
		               "http://100.65.218.62:8123")
	}

	func testEmptyInput() {
		XCTAssertEqual(LiveLightClient.normalizedBase("   "), "")
	}

	func testRawIPPreservesScheme() {
		XCTAssertEqual(LiveLightClient.normalizedBase("http://100.65.218.62:8123"),
		               "http://100.65.218.62:8123")
	}
}
