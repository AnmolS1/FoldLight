import SwiftUI
import Observation
import FoldKit

/// Drives the in-app editor: loads lights from the current provider (mock or live),
/// keeps the App-Group cache fresh for widgets, and sends control actions to HA.
@MainActor
@Observable
final class LightsViewModel {
	enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

	private(set) var lights: [LightState] = []
	private(set) var state: LoadState = .idle

	private var provider: any LightProviding

	init(settings: AppSettings) {
		self.provider = settings.makeProvider()
	}

	/// Re-read the provider after settings change (mock↔live, URL/token edits).
	func applySettings(_ settings: AppSettings) {
		provider = settings.makeProvider()
		Task { await refresh() }
	}

	func refresh() async {
		if lights.isEmpty { state = .loading }
		do {
			let fetched = try await provider.lights()
			lights = fetched
			LightCache.shared.write(fetched)
			WidgetReload.requestAll()
			state = .loaded
		} catch {
			// Keep last-good lights on transient errors; only surface a hard failure
			// when we have nothing to show.
			if lights.isEmpty { state = .failed(error.localizedDescription) }
			else { state = .loaded }
		}
	}

	func light(withID id: String) -> LightState? { lights.first { $0.entityID == id } }

	// MARK: Actions (optimistic local update, then reconcile on next refresh)

	func toggle(_ light: LightState) async {
		try? await provider.toggle(light.entityID)
		await refresh()
	}

	func setBrightness(_ pct: Int, on light: LightState) async {
		try? await provider.turnOn(light.entityID, brightnessPct: pct, rgb: nil, kelvin: nil)
		await refresh()
	}

	func setColor(_ rgb: LightRGB, on light: LightState) async {
		try? await provider.turnOn(light.entityID, brightnessPct: nil, rgb: rgb, kelvin: nil)
		await refresh()
	}

	func setKelvin(_ kelvin: Int, on light: LightState) async {
		try? await provider.turnOn(light.entityID, brightnessPct: nil, rgb: nil, kelvin: kelvin)
		await refresh()
	}

	/// Apply color + brightness together (the editor's "Apply" in Color mode).
	func turnOnColor(_ rgb: LightRGB, brightness pct: Int, on light: LightState) async {
		try? await provider.turnOn(light.entityID, brightnessPct: pct, rgb: rgb, kelvin: nil)
		await refresh()
	}

	/// Apply white temperature + brightness together (editor's "Apply" in White mode).
	func turnOnKelvin(_ kelvin: Int, brightness pct: Int, on light: LightState) async {
		try? await provider.turnOn(light.entityID, brightnessPct: pct, rgb: nil, kelvin: kelvin)
		await refresh()
	}

	func apply(_ preset: LightPreset, to light: LightState) async {
		try? await provider.apply(preset, to: light.entityID)
		await refresh()
	}
}
