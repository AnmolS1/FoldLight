import Foundation

/// The last-known **on** state of a light — brightness plus either a color or a white
/// temperature — captured while the light was on so it can be restored when the user
/// turns the light back on, instead of defaulting to full white. Persisted in the App
/// Group so the app, widgets, and intents all restore the same thing.
public struct LightOnState: Codable, Sendable, Equatable {
	public var brightnessPct: Int?
	public var rgb: LightRGB?
	public var kelvin: Int?

	public init(brightnessPct: Int? = nil, rgb: LightRGB? = nil, kelvin: Int? = nil) {
		self.brightnessPct = brightnessPct
		self.rgb = rgb
		self.kelvin = kelvin
	}

	/// The on-state worth remembering from a light that is currently on. Prefers an
	/// explicit RGB color; otherwise the white color temperature — a light is in one
	/// mode or the other, and sending both to `turn_on` is ambiguous. Returns nil for
	/// a light that is off (so the previous on-state survives being turned off).
	public init?(remembering light: LightState) {
		guard light.isOn else { return nil }
		self.brightnessPct = light.brightnessPct
		if let rgb = light.rgb {
			self.rgb = rgb
			self.kelvin = nil
		} else {
			self.rgb = nil
			self.kelvin = light.colorTempKelvin
		}
	}

	/// True when there is actually something to restore.
	public var hasValue: Bool { brightnessPct != nil || rgb != nil || kelvin != nil }
}

/// App-Group JSON persistence of per-light last-on state, keyed by entity id.
/// Mirrors the `LightPrefsStore` / `PresetStore` pattern so app, widgets, and intents
/// share one file.
public struct LastLightStateStore: Sendable {
	public static let shared = LastLightStateStore()

	private let filename = "last-light-state.json"

	private var fileURL: URL? {
		FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
			.appendingPathComponent(filename)
	}

	public init() {}

	public func load() -> [String: LightOnState] {
		guard let url = fileURL, let data = try? Data(contentsOf: url),
		      let map = try? JSONDecoder().decode([String: LightOnState].self, from: data) else {
			return [:]
		}
		return map
	}

	public func save(_ map: [String: LightOnState]) {
		guard let url = fileURL, let data = try? JSONEncoder().encode(map) else { return }
		try? data.write(to: url, options: .atomic)
	}

	/// The last-known on-state for a light, if one has been recorded.
	public func lastOn(_ entityID: String) -> LightOnState? {
		load()[entityID]
	}

	/// Record the on-state of any lights that are currently on. Off lights are left
	/// untouched (their last on-state must survive being off). Writes only when
	/// something actually changed, to avoid disk churn on every refresh.
	public func record(_ lights: [LightState]) {
		var map = load()
		var changed = false
		for light in lights {
			guard let state = LightOnState(remembering: light), state.hasValue else { continue }
			if map[light.entityID] != state {
				map[light.entityID] = state
				changed = true
			}
		}
		if changed { save(map) }
	}

	public func record(_ light: LightState) { record([light]) }
}
