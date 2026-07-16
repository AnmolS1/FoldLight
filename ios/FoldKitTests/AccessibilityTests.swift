import XCTest
@testable import FoldKit

/// Pure-logic assertions for the accessibility helpers that back VoiceOver value
/// strings and the "color without color" naming. The SwiftUI label wiring itself
/// needs a UI-test target (not present); these lock the spoken text the views feed
/// into `.accessibilityValue` / `.accessibilityLabel`.
final class AccessibilityTests: XCTestCase {

	// MARK: Value strings

	func testBrightnessValue() {
		XCTAssertEqual(A11yValue.brightness(60), "60 percent")
		XCTAssertEqual(A11yValue.brightness(0), "0 percent")
		XCTAssertEqual(A11yValue.brightness(100), "100 percent")
	}

	func testWarmthWordBuckets() {
		XCTAssertEqual(A11yValue.warmthWord(2000), "very warm")
		XCTAssertEqual(A11yValue.warmthWord(2700), "warm white")
		XCTAssertEqual(A11yValue.warmthWord(4000), "neutral white")
		XCTAssertEqual(A11yValue.warmthWord(5000), "cool white")
		XCTAssertEqual(A11yValue.warmthWord(6500), "daylight")
	}

	func testTemperatureValueCombinesKelvinAndWarmth() {
		XCTAssertEqual(A11yValue.temperature(3000), "3000 kelvin, warm white")
	}

	// MARK: Nearest named color (drives the "color without color" labels)

	func testSeedPresetColorsAreNamed() {
		// "Movie red" seed preset → red.
		XCTAssertEqual(A11yColorName.name(r: 255, g: 30, b: 20), "red")
		// The sample bulb's warm RGB → the branded orange.
		XCTAssertEqual(A11yColorName.name(r: 255, g: 170, b: 90), "crane orange")
	}

	func testHueBuckets() {
		XCTAssertEqual(A11yColorName.name(r: 0, g: 80, b: 230), "blue")
		XCTAssertEqual(A11yColorName.name(r: 0, g: 180, b: 180), "teal")
		XCTAssertEqual(A11yColorName.name(r: 30, g: 200, b: 60), "green")
		XCTAssertEqual(A11yColorName.name(r: 150, g: 40, b: 220), "purple")
	}

	func testGrayAndBlackAndWhite() {
		XCTAssertEqual(A11yColorName.name(r: 5, g: 5, b: 5), "off")
		XCTAssertEqual(A11yColorName.name(r: 240, g: 240, b: 245), "white")
		XCTAssertEqual(A11yColorName.name(r: 128, g: 128, b: 130), "gray")
	}

	func testDeepAndPastelQualifiers() {
		// Dark saturated blue → "deep blue".
		XCTAssertEqual(A11yColorName.name(hue: 0.6, saturation: 0.9, brightness: 0.3), "deep blue")
		// Pale but saturated-enough hue → "pastel …".
		XCTAssertEqual(A11yColorName.name(hue: 0.6, saturation: 0.3, brightness: 0.95), "pastel blue")
	}

	// MARK: HSB decomposition round-trips

	func testHSBPrimaries() {
		let red = A11yColorName.hsb(r: 255, g: 0, b: 0)
		XCTAssertEqual(red.h, 0, accuracy: 0.001)
		XCTAssertEqual(red.s, 1, accuracy: 0.001)
		XCTAssertEqual(red.v, 1, accuracy: 0.001)

		let green = A11yColorName.hsb(r: 0, g: 255, b: 0)
		XCTAssertEqual(green.h, 1.0 / 3.0, accuracy: 0.001)

		let blue = A11yColorName.hsb(r: 0, g: 0, b: 255)
		XCTAssertEqual(blue.h, 2.0 / 3.0, accuracy: 0.001)
	}

	func testHSBGrayHasZeroSaturation() {
		let gray = A11yColorName.hsb(r: 100, g: 100, b: 100)
		XCTAssertEqual(gray.s, 0, accuracy: 0.001)
		XCTAssertEqual(gray.v, 100.0 / 255.0, accuracy: 0.001)
	}
}
