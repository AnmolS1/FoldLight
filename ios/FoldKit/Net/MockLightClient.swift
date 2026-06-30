import Foundation

/// In-memory light state behind the mock client, so mock mode + previews feel
/// interactive (a toggle/preset actually changes what the UI shows). Shared across
/// the process; an actor keeps it Sendable-safe.
actor MockLightStore {
	static let shared = MockLightStore()
	private var lights: [String: LightState]

	init() {
		lights = Dictionary(uniqueKeysWithValues: LightState.samples.map { ($0.entityID, $0) })
	}

	func all() -> [LightState] {
		lights.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}

	func get(_ id: String) -> LightState? { lights[id] }

	func turnOn(_ id: String, brightnessPct: Int?, rgb: LightRGB?, kelvin: Int?) {
		guard var l = lights[id] else { return }
		l.isOn = true
		if let brightnessPct { l.brightnessPct = brightnessPct }
		else if l.brightnessPct == nil { l.brightnessPct = 100 }
		if let rgb { l.rgb = rgb; l.colorTempKelvin = nil }
		if let kelvin { l.colorTempKelvin = kelvin; l.rgb = nil }
		lights[id] = l
	}

	func turnOff(_ id: String) {
		guard var l = lights[id] else { return }
		l.isOn = false
		l.brightnessPct = nil
		lights[id] = l
	}

	func toggle(_ id: String) {
		guard let l = lights[id] else { return }
		if l.isOn { turnOff(id) } else { turnOn(id, brightnessPct: nil, rgb: nil, kelvin: nil) }
	}
}

/// A `LightProviding` backed by bundled sample lights with mutable in-memory
/// state. Used in mock mode, SwiftUI previews, and tests.
public struct MockLightClient: LightProviding {
	public init() {}

	public func lights() async throws -> [LightState] { await MockLightStore.shared.all() }

	public func light(_ entityID: String) async throws -> LightState {
		guard let l = await MockLightStore.shared.get(entityID) else { throw LightError.http(404) }
		return l
	}

	public func turnOn(_ entityID: String, brightnessPct: Int?, rgb: LightRGB?, kelvin: Int?) async throws {
		await MockLightStore.shared.turnOn(entityID, brightnessPct: brightnessPct, rgb: rgb, kelvin: kelvin)
	}

	public func turnOff(_ entityID: String) async throws {
		await MockLightStore.shared.turnOff(entityID)
	}

	public func toggle(_ entityID: String) async throws {
		await MockLightStore.shared.toggle(entityID)
	}

	public func testConnection() async -> Bool { true }
}
