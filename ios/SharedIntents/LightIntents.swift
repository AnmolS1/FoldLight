import AppIntents
import FoldKit

/// After a control action, reflect the **real** HA state in the App-Group cache
/// (so widgets tell the truth, never an optimistic guess). Re-reads the one light;
/// if that read fails, falls back to the caller-supplied expected mutation; if the
/// whole thing is offline, leaves the cache untouched rather than lying.
private func reconcile(_ entityID: String, provider: any LightProviding, expected: (inout LightState) -> Void) async {
	if let fresh = try? await provider.light(entityID) {
		LightCache.shared.upsert(fresh)
	} else if var current = LightCache.shared.read().first(where: { $0.entityID == entityID }) {
		expected(&current)
		LightCache.shared.upsert(current)
	}
	WidgetReload.requestAll()
}

/// Toggle a light on/off. Runs from a widget `Button` or a control, without opening
/// the app. Only updates the widget once the HA call has actually succeeded.
public struct ToggleLightIntent: AppIntent {
	public static var title: LocalizedStringResource { "Toggle Light" }
	public static var description: IntentDescription { IntentDescription("Turn a Home Assistant light on or off.") }

	@Parameter(title: "Light") public var light: LightAppEntity

	public init() {}
	public init(light: LightAppEntity) { self.light = light }

	public func perform() async throws -> some IntentResult {
		let provider = StoredConnection.load().makeProvider()
		do {
			try await provider.toggle(light.id)
		} catch {
			// HA unreachable — do NOT flip the cached state (that caused the
			// "widget says on but bulb is off" inversion). Record why so the failure
			// isn't invisible (ATS block, 401/missing token, offline).
			IntentDiagnostics.record("toggle", error)
			WidgetReload.requestAll()
			return .result()
		}
		IntentDiagnostics.clear()
		await reconcile(light.id, provider: provider) { $0.isOn.toggle() }
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
		let provider = StoredConnection.load().makeProvider()
		do {
			try await provider.turnOn(light.id, brightnessPct: pct, rgb: nil, kelvin: nil)
		} catch {
			IntentDiagnostics.record("brightness", error)
			WidgetReload.requestAll()
			return .result()
		}
		IntentDiagnostics.clear()
		await reconcile(light.id, provider: provider) { l in
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
		let provider = StoredConnection.load().makeProvider()
		do {
			try await provider.apply(stored, to: light.id)
		} catch {
			IntentDiagnostics.record("preset", error)
			WidgetReload.requestAll()
			return .result()
		}
		IntentDiagnostics.clear()
		await reconcile(light.id, provider: provider) { l in
			l.isOn = true
			l.brightnessPct = stored.brightnessPct
			l.rgb = stored.rgb
			l.colorTempKelvin = stored.kelvin
		}
		return .result()
	}
}
