import XCTest
@testable import FoldKit

/// HA reports `brightness` 0–255 but `turn_on` takes `brightness_pct` 0–100.
/// These guard the one place that conversion lives.
final class BrightnessTests: XCTestCase {
	func testHA255ToPercentEndpoints() {
		XCTAssertEqual(Brightness.pct(fromHA255: 0), 0)
		XCTAssertEqual(Brightness.pct(fromHA255: 255), 100)
	}

	func testHA255ToPercentMidpoint() {
		// 191/255 ≈ 74.9 → 75
		XCTAssertEqual(Brightness.pct(fromHA255: 191), 75)
		// 128/255 ≈ 50.2 → 50
		XCTAssertEqual(Brightness.pct(fromHA255: 128), 50)
	}

	func testPercentToHA255Endpoints() {
		XCTAssertEqual(Brightness.ha255(fromPct: 0), 0)
		XCTAssertEqual(Brightness.ha255(fromPct: 100), 255)
		XCTAssertEqual(Brightness.ha255(fromPct: 50), 128) // 127.5 → 128
	}

	func testClamping() {
		XCTAssertEqual(Brightness.pct(fromHA255: 999), 100)
		XCTAssertEqual(Brightness.pct(fromHA255: -5), 0)
		XCTAssertEqual(Brightness.ha255(fromPct: 250), 255)
		XCTAssertEqual(Brightness.ha255(fromPct: -10), 0)
	}
}
