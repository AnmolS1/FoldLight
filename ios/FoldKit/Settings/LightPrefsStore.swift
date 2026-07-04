import Foundation

/// User preferences over the auto-detected lights: which one is "main" (the
/// widget/controls default), which are favorites (and their order), and
/// display-name overrides. Keyed by HA entity id.
public struct LightPrefs: Codable, Sendable, Equatable {
	/// The user's chosen main light; nil falls back to the old heuristic
	/// (first color/temp-capable, else first).
	public var mainLightID: String?
	/// Ordered favorites. Empty ⇒ all detected lights, detection order.
	public var favoriteIDs: [String]
	/// Display-name override per entity id.
	public var renames: [String: String]

	public init(mainLightID: String? = nil, favoriteIDs: [String] = [], renames: [String: String] = [:]) {
		self.mainLightID = mainLightID
		self.favoriteIDs = favoriteIDs
		self.renames = renames
	}

	public func displayName(for light: LightState) -> String {
		renames[light.entityID] ?? light.name
	}

	/// Apply favorites ordering + renames to a detected-lights list: favorites
	/// first (in their saved order), the rest after in detection order.
	public func arrange(_ lights: [LightState]) -> [LightState] {
		let renamed = lights.map { light in
			var l = light
			l.name = displayName(for: light)
			return l
		}
		guard !favoriteIDs.isEmpty else { return renamed }
		let rank = Dictionary(uniqueKeysWithValues: favoriteIDs.enumerated().map { ($1, $0) })
		return renamed.enumerated().sorted { a, b in
			let ra = rank[a.element.entityID] ?? Int.max
			let rb = rank[b.element.entityID] ?? Int.max
			return ra == rb ? a.offset < b.offset : ra < rb
		}.map(\.element)
	}
}

/// App-Group JSON persistence for `LightPrefs` (PresetStore pattern) so the
/// app, widgets, intents, and Control Center read one config.
public struct LightPrefsStore: Sendable {
	public static let shared = LightPrefsStore()

	private let filename = "light-prefs.json"

	private var fileURL: URL? {
		FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
			.appendingPathComponent(filename)
	}

	public init() {}

	public func load() -> LightPrefs {
		guard let url = fileURL, let data = try? Data(contentsOf: url),
		      let prefs = try? JSONDecoder().decode(LightPrefs.self, from: data) else {
			return LightPrefs()
		}
		return prefs
	}

	public func save(_ prefs: LightPrefs) {
		guard let url = fileURL, let data = try? JSONEncoder().encode(prefs) else { return }
		try? data.write(to: url, options: .atomic)
	}
}
