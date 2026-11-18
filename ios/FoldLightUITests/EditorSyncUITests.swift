import XCTest

/// The Light editor's card must follow the bulb's state when it changes outside
/// the editor's own controls. Before the fix, the card synced only when the
/// selected light changed. Turning the light back on, which restores its last
/// color, left the card showing stale values.
///
/// Mock data, so no Home Assistant is needed. The mock bulb starts on, orange
/// (color mode), 70%.
final class EditorSyncUITests: XCTestCase {
	override func setUp() {
		super.setUp()
		continueAfterFailure = false
	}

	private func shot(_ name: String) {
		let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
		att.name = name
		att.lifetime = .keepAlways
		add(att)
	}

	func testCardFollowsLightRestoredOnTurnOn() throws {
		let app = XCUIApplication()
		app.launchArguments = ["--uitest-screenshots", "--screen", "editor"]
		app.launch()

		let preview = app.descendants(matching: .any)["bulbPreview"]
		XCTAssertTrue(preview.waitForExistence(timeout: 10))
		let power = app.switches["Power"]
		XCTAssertTrue(power.waitForExistence(timeout: 5))
		let colorSegment = app.buttons["Color"]
		let whiteSegment = app.buttons["White"]
		XCTAssertTrue(colorSegment.isSelected, "mock bulb starts in color mode")
		shot("1-start")

		// Off, then switch the editor to White locally. Nothing is sent to HA.
		power.tap()
		wait(for: [expectation(for: NSPredicate(format: "value == 'Off'"), evaluatedWith: preview)], timeout: 5)
		whiteSegment.tap()
		XCTAssertTrue(whiteSegment.isSelected)
		shot("2-off-white")

		// Back on: the bulb restores its last color (orange, 70%). The card must follow.
		power.tap()
		let restored = NSPredicate(format: "value BEGINSWITH 'On, 70 percent'")
		wait(for: [expectation(for: restored, evaluatedWith: preview)], timeout: 5)
		let backToColor = NSPredicate(format: "isSelected == true")
		wait(for: [expectation(for: backToColor, evaluatedWith: colorSegment)], timeout: 5)
		XCTAssertFalse(String(describing: preview.value ?? "").contains("white"),
		               "card still shows the stale White mode: \(preview.value ?? "nil")")
		shot("3-on-restored")
	}
}
