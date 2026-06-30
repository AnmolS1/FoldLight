import SwiftUI
import Observation
import FoldKit

/// Drives the in-app editor: loads lights from the current provider (mock or live),
/// keeps the App-Group cache fresh for widgets, and sends control actions to HA.
///
/// Actions are **optimistic then reconciled**: the UI updates instantly, the call
/// goes to HA, and the real state is re-read shortly after (Zigbee bulbs take a
/// beat to report). On failure the error is surfaced (never silently swallowed)
/// and the optimistic change is rolled back by a refresh.
@MainActor
@Observable
final class LightsViewModel {
	enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

	private(set) var lights: [LightState] = []
	private(set) var state: LoadState = .idle
	/// Last control/refresh error, shown as a banner. Cleared on success.
	private(set) var lastError: String?

	private var provider: any LightProviding
	/// Settle delay before reconciling after an action (HA/Zigbee state lag).
	private let settle: Duration = .milliseconds(900)

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
			lastError = nil
		} catch {
			// Keep last-good lights on transient errors, but always surface the error.
			lastError = error.localizedDescription
			state = lights.isEmpty ? .failed(error.localizedDescription) : .loaded
		}
	}

	func light(withID id: String) -> LightState? { lights.first { $0.entityID == id } }

	// MARK: Actions

	/// Run an action with optimistic UI, error surfacing, and a reconcile read.
	private func act(on id: String, optimistic: (inout LightState) -> Void, _ call: () async throws -> Void) async {
		if let i = lights.firstIndex(where: { $0.entityID == id }) { optimistic(&lights[i]) }
		do {
			try await call()
			lastError = nil
		} catch {
			lastError = error.localizedDescription
			await refresh()      // roll the optimistic change back to truth
			return
		}
		try? await Task.sleep(for: settle)
		await refresh()          // reconcile with HA's reported state
	}

	func toggle(_ light: LightState) async {
		await act(on: light.entityID, optimistic: { l in
			l.isOn.toggle()
			if !l.isOn { l.brightnessPct = nil } else if l.brightnessPct == nil { l.brightnessPct = 100 }
		}) { try await provider.toggle(light.entityID) }
	}

	func setBrightness(_ pct: Int, on light: LightState) async {
		await act(on: light.entityID, optimistic: { l in l.isOn = pct > 0; l.brightnessPct = pct > 0 ? pct : nil }) {
			try await provider.turnOn(light.entityID, brightnessPct: pct, rgb: nil, kelvin: nil)
		}
	}

	/// Apply color + brightness together (the editor's "Apply" / live drag in Color mode).
	func turnOnColor(_ rgb: LightRGB, brightness pct: Int, on light: LightState) async {
		await act(on: light.entityID, optimistic: { l in
			l.isOn = true; l.brightnessPct = pct; l.rgb = rgb; l.colorTempKelvin = nil
		}) { try await provider.turnOn(light.entityID, brightnessPct: pct, rgb: rgb, kelvin: nil) }
	}

	/// Apply white temperature + brightness together (editor's White mode).
	func turnOnKelvin(_ kelvin: Int, brightness pct: Int, on light: LightState) async {
		await act(on: light.entityID, optimistic: { l in
			l.isOn = true; l.brightnessPct = pct; l.colorTempKelvin = kelvin; l.rgb = nil
		}) { try await provider.turnOn(light.entityID, brightnessPct: pct, rgb: nil, kelvin: kelvin) }
	}

	func apply(_ preset: LightPreset, to light: LightState) async {
		await act(on: light.entityID, optimistic: { l in
			l.isOn = true; l.brightnessPct = preset.brightnessPct; l.rgb = preset.rgb; l.colorTempKelvin = preset.kelvin
		}) { try await provider.apply(preset, to: light.entityID) }
	}
}
