import WidgetKit
import SwiftUI
import FoldKit

/// One timeline entry: the targeted light's current state + the chosen presets.
struct LightEntry: TimelineEntry {
	let date: Date
	let light: LightState?
	let presets: [LightPreset]
	let unreachable: Bool
}

/// Renders the App-Group cache instantly, then refreshes with its own live
/// fetch (mock when unconfigured). Honors the per-instance intent: the chosen
/// light (else the configured main light) and chosen preset swatches (else the
/// first favorites). Reloads ~every 15 min — ambient; intents reload on demand.
struct LightTimelineProvider: AppIntentTimelineProvider {
	typealias Entry = LightEntry
	typealias Intent = LightWidgetConfigurationIntent

	private func resolveLight(for intent: LightWidgetConfigurationIntent, in lights: [LightState]) -> LightState? {
		let prefs = LightPrefsStore.shared.load()
		var resolved: LightState?
		if let chosen = intent.light, let match = lights.first(where: { $0.entityID == chosen.id }) {
			resolved = match
		} else {
			resolved = LightCache.shared.mainLight()
		}
		// Show the user's display-name override, not the raw HA name.
		if var light = resolved {
			light.name = prefs.displayName(for: light)
			return light
		}
		return nil
	}

	private func resolvePresets(for intent: LightWidgetConfigurationIntent) -> [LightPreset] {
		if let chosen = intent.presets, !chosen.isEmpty {
			let all = PresetStore.shared.load()
			return chosen.compactMap { entity in all.first { $0.id.uuidString == entity.id } }
		}
		return PresetStore.shared.favorites()
	}

	func placeholder(in context: Context) -> LightEntry {
		LightEntry(date: Date(), light: .sampleColor, presets: LightPreset.seedDefaults, unreachable: false)
	}

	func snapshot(for configuration: LightWidgetConfigurationIntent, in context: Context) async -> LightEntry {
		let light = resolveLight(for: configuration, in: LightCache.shared.read()) ?? .sampleColor
		return LightEntry(date: Date(), light: light, presets: resolvePresets(for: configuration), unreachable: false)
	}

	func timeline(for configuration: LightWidgetConfigurationIntent, in context: Context) async -> Timeline<LightEntry> {
		var lights = LightCache.shared.read()
		var unreachable = false
		do {
			let fetched = try await StoredConnection.load().makeProvider().lights()
			if !fetched.isEmpty {
				LightCache.shared.write(fetched)
				lights = fetched
			}
		} catch {
			if lights.isEmpty { unreachable = true }
		}
		let entry = LightEntry(
			date: Date(),
			light: resolveLight(for: configuration, in: lights),
			presets: resolvePresets(for: configuration),
			unreachable: unreachable
		)
		let next = Date().addingTimeInterval(15 * 60)
		return Timeline(entries: [entry], policy: .after(next))
	}
}
