#if os(iOS)
import AppIntents
import WidgetKit
import SwiftUI
import FoldKit

// MARK: - Control-only intents (resolve the "main light" from the cache at run time)

/// Set the main light on/off from a Control Center toggle. `SetValueIntent` so the
/// system supplies the desired new state in `value`.
@available(iOS 18.0, *)
public struct SetMainLightOnIntent: SetValueIntent {
	public static var title: LocalizedStringResource { "Set Main Light" }

	@Parameter(title: "On") public var value: Bool

	public init() {}

	public func perform() async throws -> some IntentResult {
		guard let main = LightCache.shared.mainLight() else { return .result() }
		let provider = StoredConnection.load().makeProvider()
		do {
			if value {
				try await provider.turnOn(main.entityID, brightnessPct: nil, rgb: nil, kelvin: nil)
			} else {
				try await provider.turnOff(main.entityID)
			}
		} catch {
			// HA unreachable — don't claim the new state.
			IntentDiagnostics.record("control-toggle", error)
			WidgetReload.requestAll()
			return .result()
		}
		IntentDiagnostics.clear()
		if let fresh = try? await provider.light(main.entityID) {
			LightCache.shared.upsert(fresh)
		} else {
			var updated = main
			updated.isOn = value
			updated.brightnessPct = value ? (main.brightnessPct ?? 100) : nil
			LightCache.shared.upsert(updated)
		}
		WidgetReload.requestAll()
		return .result()
	}
}

/// Apply the first favorite preset to the main light from a Control Center button.
@available(iOS 18.0, *)
public struct ApplyFavoritePresetIntent: AppIntent {
	public static var title: LocalizedStringResource { "Apply Favorite Preset" }

	public init() {}

	public func perform() async throws -> some IntentResult {
		guard let main = LightCache.shared.mainLight(),
		      let preset = PresetStore.shared.favorites().first else { return .result() }
		let provider = StoredConnection.load().makeProvider()
		do {
			try await provider.apply(preset, to: main.entityID)
		} catch {
			IntentDiagnostics.record("control-preset", error)
			WidgetReload.requestAll()
			return .result()
		}
		IntentDiagnostics.clear()
		if let fresh = try? await provider.light(main.entityID) {
			LightCache.shared.upsert(fresh)
		} else {
			var updated = main
			updated.isOn = true
			updated.brightnessPct = preset.brightnessPct
			updated.rgb = preset.rgb
			updated.colorTempKelvin = preset.kelvin
			LightCache.shared.upsert(updated)
		}
		WidgetReload.requestAll()
		return .result()
	}
}

// MARK: - Controls

@available(iOS 18.0, *)
struct MainLightValueProvider: ControlValueProvider {
	var previewValue: Bool { true }
	func currentValue() async throws -> Bool { LightCache.shared.mainLight()?.isOn ?? false }
}

/// On/off toggle for the main light.
@available(iOS 18.0, *)
struct MainLightToggleControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		StaticControlConfiguration(kind: "dev.ponderance.foldlight.control.toggle", provider: MainLightValueProvider()) { isOn in
			ControlWidgetToggle("Main Light", isOn: isOn, action: SetMainLightOnIntent()) { on in
				Label(on ? "On" : "Off", systemImage: on ? "lightbulb.fill" : "lightbulb")
			}
			.tint(.yellow)
		}
		.displayName("Main Light")
		.description("Turn your main light on or off.")
	}
}

/// One-tap apply the first favorite preset.
@available(iOS 18.0, *)
struct ApplyPresetControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		StaticControlConfiguration(kind: "dev.ponderance.foldlight.control.preset") {
			ControlWidgetButton(action: ApplyFavoritePresetIntent()) {
				Label("Favorite Preset", systemImage: "paintpalette")
			}
		}
		.displayName("Apply Preset")
		.description("Apply your favorite light preset.")
	}
}

/// Launch the Home Assistant web UI.
@available(iOS 18.0, *)
struct OpenHomeAssistantControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		StaticControlConfiguration(kind: "dev.ponderance.foldlight.control.openha") {
			ControlWidgetButton(action: OpenURLIntent(LauncherTarget.homeAssistant.url!)) {
				Label("Home Assistant", systemImage: "house.fill")
			}
		}
		.displayName("Open Home Assistant")
		.description("Open the Home Assistant dashboard.")
	}
}

/// Launch the 3D-printer (Bambuddy) web UI.
@available(iOS 18.0, *)
struct OpenPrinterControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		StaticControlConfiguration(kind: "dev.ponderance.foldlight.control.openprinter") {
			ControlWidgetButton(action: OpenURLIntent(LauncherTarget.printer.url!)) {
				Label("Printer", systemImage: "printer.fill")
			}
		}
		.displayName("Open Printer")
		.description("Open the Bambuddy printer page.")
	}
}
#endif
