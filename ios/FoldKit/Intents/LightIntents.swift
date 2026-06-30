import AppIntents

/// Shared optimistic-update + reconcile helper for the light intents: hit HA,
/// then update the App-Group cache so widgets reflect the change immediately.
private func reconcile(_ entityID: String, mutate: (inout LightState) -> Void) {
	var lights = LightCache.shared.read()
	if let i = lights.firstIndex(where: { $0.entityID == entityID }) {
		mutate(&lights[i])
		LightCache.shared.write(lights)
	}
	WidgetReload.requestAll()
}

/// Toggle a light on/off. Runs from a widget `Toggle`/`Button` or a control,
/// without opening the app.
public struct ToggleLightIntent: AppIntent {
	public static var title: LocalizedStringResource { "Toggle Light" }
	public static var description: IntentDescription { IntentDescription("Turn a Home Assistant light on or off.") }

	@Parameter(title: "Light") public var light: LightAppEntity

	public init() {}
	public init(light: LightAppEntity) { self.light = light }

	public func perform() async throws -> some IntentResult {
		try? await StoredConnection.load().makeProvider().toggle(light.id)
		LightCache.shared.optimisticToggle(light.id)
		WidgetReload.requestAll()
		return .result()
	}
}

/// Set a light's brightness (0–100%). Used by the widget's brightness steps.
public struct SetBrightnessIntent: AppIntent {
	public static var title: LocalizedStringResource { "Set Brightness" }
	public static var description: IntentDescription { IntentDescription("Set a light's brightness.") }

	@Parameter(title: "Light") public var light: LightAppEntity
	@Parameter(title: "Brightness %", default: 100) public var percent: Int

	public init() {}
	public init(light: LightAppEntity, percent: Int) {
		self.light = light
		self.percent = percent
	}

	public func perform() async throws -> some IntentResult {
		let pct = max(0, min(100, percent))
		try? await StoredConnection.load().makeProvider().turnOn(light.id, brightnessPct: pct, rgb: nil, kelvin: nil)
		reconcile(light.id) { l in
			l.isOn = pct > 0
			l.brightnessPct = pct > 0 ? pct : nil
		}
		return .result()
	}
}

/// Apply a saved preset (color/temp + brightness) to a light. The widget swatches
/// and per-preset controls fire this.
public struct ApplyPresetIntent: AppIntent {
	public static var title: LocalizedStringResource { "Apply Preset" }
	public static var description: IntentDescription { IntentDescription("Apply a saved color/brightness preset to a light.") }

	@Parameter(title: "Light") public var light: LightAppEntity
	@Parameter(title: "Preset") public var preset: PresetAppEntity

	public init() {}
	public init(light: LightAppEntity, preset: PresetAppEntity) {
		self.light = light
		self.preset = preset
	}

	public func perform() async throws -> some IntentResult {
		guard let stored = PresetStore.shared.load().first(where: { $0.id.uuidString == preset.id }) else {
			return .result()
		}
		try? await StoredConnection.load().makeProvider().apply(stored, to: light.id)
		reconcile(light.id) { l in
			l.isOn = true
			l.brightnessPct = stored.brightnessPct
			l.rgb = stored.rgb
			l.colorTempKelvin = stored.kelvin
		}
		return .result()
	}
}
