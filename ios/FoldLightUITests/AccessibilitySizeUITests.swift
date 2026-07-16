import XCTest

/// Captures full screenshots of every FoldLight screen reachable **without a live
/// Home Assistant server**, at the largest Dynamic Type size
/// (`.accessibilityExtraLarge`, a.k.a. "accessibility3"), so the manual
/// "no clipped / overlapping / truncated text" accessibility gate can be eyeballed.
///
/// - Mock data (lights, seeded presets, fake launcher tiles, onboarding dismissed)
///   comes from the app's existing `--uitest-screenshots` harness (`ScreenshotSupport`).
/// - The content-size category is forced per launch via the standard
///   `-UIPreferredContentSizeCategoryName` launch argument (the runner also sets the
///   simulator's global content size as a belt-and-suspenders).
/// - Tall screens are captured across their **full scroll length** (a single viewport
///   can't certify "no clipping"); `captureScroll` snapshots, swipes up, and repeats
///   until the screen stops moving.
/// - Each screenshot is a `.keepAlways` `XCTAttachment`; the runner exports them from
///   the `.xcresult`.
///
/// Waits are best-effort (no hard asserts) so a screenshot is always captured even if
/// an expected label differs — the artifacts are the point.
final class AccessibilitySizeUITests: XCTestCase {

	// The runtime rawValue of `.accessibilityExtraLarge` ("accessibility3") is the
	// SHORT form `…AccessibilityXL`. The long form `…AccessibilityExtraLarge` is not a
	// recognized category name — UIKit ignores it and falls back to the default
	// (Large), silently overriding the simulator's global content size. Verified
	// empirically: only `…AccessibilityXL` produces the enlarged render.
	private let a11ySize = ["-UIPreferredContentSizeCategoryName",
	                        "UICTContentSizeCategoryAccessibilityXL"]

	override func setUp() {
		super.setUp()
		continueAfterFailure = true
	}

	// MARK: Helpers

	/// Launch seeded (mock lights/presets/launchers, onboarding pre-dismissed) on a tab.
	@discardableResult
	private func launchSeeded(screen: String) -> XCUIApplication {
		let app = XCUIApplication()
		app.launchArguments = a11ySize + ["--uitest-screenshots", "--screen", screen]
		app.launch()
		return app
	}

	private func snapshot(_ name: String) {
		let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
		att.name = name
		att.lifetime = .keepAlways
		add(att)
	}

	/// Snapshot the screen, scroll up a viewport, and repeat until it stops moving
	/// (or `maxPages`). Produces `<base>-1`, `<base>-2`, … so the whole screen — not
	/// just the top — is covered for the clipping/overlap check.
	private func captureScroll(_ app: XCUIApplication, _ base: String, maxPages: Int = 5) {
		var previous: Data? = nil
		for page in 1...maxPages {
			let shot = XCUIScreen.main.screenshot()
			let data = shot.pngRepresentation
			if data == previous { break }   // nothing scrolled — reached the bottom
			let att = XCTAttachment(screenshot: shot)
			att.name = "\(base)-\(page)"
			att.lifetime = .keepAlways
			add(att)
			previous = data
			app.swipeUp()
			sleep(1)
		}
	}

	private func firstButton(containing text: String, in app: XCUIApplication) -> XCUIElement {
		app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
	}

	/// Scroll `el` into a hittable position, then tap. Nav rows sit below the fold at
	/// accessibility3, and `tap()` does not auto-scroll.
	@discardableResult
	private func scrollToAndTap(_ el: XCUIElement, in app: XCUIApplication) -> Bool {
		guard el.waitForExistence(timeout: 8) else { return false }
		var tries = 0
		while !el.isHittable && tries < 8 { app.swipeUp(); sleep(1); tries += 1 }
		guard el.isHittable else { return false }
		el.tap()
		return true
	}

	// MARK: Screens (alphabetical run order → onboarding first, on the fresh sim)

	func test00Onboarding() {
		let app = XCUIApplication()
		// Fresh sim → onboarding shows naturally; the arg-domain override is a fallback
		// in case a prior seeded run persisted the onboarded flag. Mock mode is default.
		app.launchArguments = a11ySize + ["-hasCompletedOnboarding", "NO", "-useMockData", "YES"]
		app.launch()
		_ = app.staticTexts["Welcome to FoldLight"].waitForExistence(timeout: 8)
		sleep(2)
		captureScroll(app, "00-onboarding")
	}

	func test01LightEditor() {
		let app = launchSeeded(screen: "editor")
		_ = app.staticTexts["Power"].waitForExistence(timeout: 8)
		sleep(2)
		captureScroll(app, "01-light-editor")
	}

	func test02Presets() {
		let app = launchSeeded(screen: "presets")
		_ = app.staticTexts["Presets"].waitForExistence(timeout: 8)
		sleep(3)   // let the harness scroll to the preset library first
		captureScroll(app, "02-presets")
	}

	func test03Panel() {
		let app = launchSeeded(screen: "panel")
		_ = app.staticTexts["Home Assistant"].waitForExistence(timeout: 8)
		sleep(2)
		captureScroll(app, "03-panel")
	}

	func test04Settings() {
		let app = launchSeeded(screen: "settings")
		_ = app.staticTexts["Use mock data"].waitForExistence(timeout: 8)
		sleep(2)
		captureScroll(app, "04-settings")
	}

	func test05LightsManager() {
		let app = launchSeeded(screen: "settings")
		_ = scrollToAndTap(firstButton(containing: "Lights", in: app), in: app)
		sleep(3)
		captureScroll(app, "05-lights-manager")
	}

	func test06LaunchersManager() {
		let app = launchSeeded(screen: "settings")
		_ = scrollToAndTap(firstButton(containing: "Launchers", in: app), in: app)
		sleep(3)
		captureScroll(app, "06-launchers-manager")
	}

	func test07LauncherEditSheet() {
		let app = launchSeeded(screen: "settings")
		_ = scrollToAndTap(firstButton(containing: "Launchers", in: app), in: app)
		sleep(2)
		// The launcher rows are List cells (buttonStyle(.plain) + combined a11y element),
		// so they aren't exposed as `.buttons`. Try a button, then a cell by label, then
		// the first cell — tapping any opens the (shared) edit sheet.
		let candidates: [XCUIElement] = [
			app.buttons["Edit Home Assistant"],
			app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", "Home Assistant")).firstMatch,
			app.cells.element(boundBy: 0),
		]
		for el in candidates where el.waitForExistence(timeout: 3) && el.isHittable {
			el.tap()
			break
		}
		sleep(2)
		captureScroll(app, "07-launcher-edit-sheet")
	}
}
