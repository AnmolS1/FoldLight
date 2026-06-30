import Foundation

/// The saved-preset library, persisted as JSON in the App Group so the app,
/// widgets, and intents share one source of truth. Seeds `LightPreset.seedDefaults`
/// the first time it's read on a configured (App-Group) build.
public struct PresetStore: Sendable {
	public static let shared = PresetStore()

	private let filename = "presets.json"
	private let seededFlag = "presetsSeeded"

	private var fileURL: URL? {
		FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
			.appendingPathComponent(filename)
	}

	public init() {}

	/// Load the library. On first access, seeds defaults (and persists them when an
	/// App Group container is available); always returns at least the defaults.
	public func load() -> [LightPreset] {
		if let url = fileURL, let data = try? Data(contentsOf: url),
		   let presets = try? JSONDecoder().decode([LightPreset].self, from: data) {
			return presets
		}
		// Not yet persisted — seed.
		save(LightPreset.seedDefaults)
		return LightPreset.seedDefaults
	}

	public func save(_ presets: [LightPreset]) {
		guard let url = fileURL, let data = try? JSONEncoder().encode(presets) else { return }
		try? data.write(to: url, options: .atomic)
	}

	@discardableResult
	public func add(_ preset: LightPreset) -> [LightPreset] {
		var presets = load()
		presets.append(preset)
		save(presets)
		return presets
	}

	@discardableResult
	public func remove(id: UUID) -> [LightPreset] {
		var presets = load()
		presets.removeAll { $0.id == id }
		save(presets)
		return presets
	}

	public func preset(id: UUID) -> LightPreset? {
		load().first { $0.id == id }
	}

	/// The first few presets, for the small widget's swatch row.
	public func favorites(limit: Int = 5) -> [LightPreset] {
		Array(load().prefix(limit))
	}
}
