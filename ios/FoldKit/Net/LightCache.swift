import Foundation

/// Last-known light states shared between the app, widgets, and intents via the
/// App Group container. The app/intents write on each change so widgets render
/// instantly from cache, then refresh with their own live fetch on reload.
///
/// No-ops gracefully when the App Group container is unavailable (e.g. unsigned
/// local builds), so previews and tests don't depend on entitlements.
public struct LightCache: Sendable {
	public static let shared = LightCache()

	private let filename = "lights.json"

	private var fileURL: URL? {
		FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
			.appendingPathComponent(filename)
	}

	public init() {}

	public func write(_ lights: [LightState]) {
		guard let url = fileURL, let data = try? JSONEncoder().encode(lights) else { return }
		try? data.write(to: url, options: .atomic)
	}

	public func read() -> [LightState] {
		guard let url = fileURL, let data = try? Data(contentsOf: url),
		      let lights = try? JSONDecoder().decode([LightState].self, from: data) else { return [] }
		return lights
	}

	/// The "main" light to dedicate the small widget / controls to: the user's
	/// configured choice (Settings → Lights) when it's still present, else the
	/// old heuristic — first color/temp-capable light, else the first.
	public func mainLight() -> LightState? {
		let lights = read()
		if let chosen = LightPrefsStore.shared.load().mainLightID,
		   let light = lights.first(where: { $0.entityID == chosen }) {
			return light
		}
		return lights.first(where: { $0.supportsColor || $0.supportsColorTemp }) ?? lights.first
	}

	/// The cached lights with the user's favorites ordering + renames applied —
	/// what pickers and the entity query should show.
	public func displayLights() -> [LightState] {
		LightPrefsStore.shared.load().arrange(read())
	}

	/// Optimistically replace one light's cached state (used by intents before the
	/// next live reconcile), then ask widgets to reload.
	public func upsert(_ light: LightState) {
		var lights = read()
		if let i = lights.firstIndex(where: { $0.entityID == light.entityID }) {
			lights[i] = light
		} else {
			lights.append(light)
		}
		write(lights)
	}

	/// Optimistic on/off flip for an entity already in cache.
	public func optimisticToggle(_ entityID: String) {
		guard var light = read().first(where: { $0.entityID == entityID }) else { return }
		light.isOn.toggle()
		if !light.isOn { light.brightnessPct = nil }
		else if light.brightnessPct == nil { light.brightnessPct = 100 }
		upsert(light)
	}
}
