import WidgetKit
import SwiftUI
import FoldKit

/// One timeline entry: the main light's current state + the favorite presets.
struct LightEntry: TimelineEntry {
	let date: Date
	let light: LightState?
	let presets: [LightPreset]
	let unreachable: Bool
}

/// Carries WidgetKit's non-Sendable completion across the `Task` boundary.
/// Safe because the completion is invoked exactly once.
private struct SendableBox<T>: @unchecked Sendable { let value: T }

/// Renders the App-Group cache instantly, then refreshes with its own live fetch
/// (mock when unconfigured). Reloads ~every 15 min — ambient; intents reload on demand.
struct LightTimelineProvider: TimelineProvider {
	func placeholder(in context: Context) -> LightEntry {
		LightEntry(date: Date(), light: .sampleColor, presets: LightPreset.seedDefaults, unreachable: false)
	}

	func getSnapshot(in context: Context, completion: @escaping (LightEntry) -> Void) {
		let light = LightCache.shared.mainLight() ?? .sampleColor
		completion(LightEntry(date: Date(), light: light, presets: PresetStore.shared.favorites(), unreachable: false))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<LightEntry>) -> Void) {
		let box = SendableBox(value: completion)
		Task {
			var light = LightCache.shared.mainLight()
			var unreachable = false
			do {
				let fetched = try await StoredConnection.load().makeProvider().lights()
				if !fetched.isEmpty { LightCache.shared.write(fetched) }
				light = fetched.first(where: { $0.supportsColor || $0.supportsColorTemp }) ?? fetched.first ?? light
			} catch {
				if light == nil { unreachable = true }
			}
			let entry = LightEntry(
				date: Date(),
				light: light,
				presets: PresetStore.shared.favorites(),
				unreachable: unreachable
			)
			let next = Date().addingTimeInterval(15 * 60)
			box.value(Timeline(entries: [entry], policy: .after(next)))
		}
	}
}
