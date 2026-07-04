import Foundation

/// The user-managed launcher tiles, persisted as JSON in the App Group so the
/// app, widgets, and controls share one source of truth. Ships empty — users
/// add their own tiles in Settings → Launchers.
public struct LauncherStore: Sendable {
	public static let shared = LauncherStore()

	private let filename = "launchers.json"

	private var fileURL: URL? {
		FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
			.appendingPathComponent(filename)
	}

	public init() {}

	public func load() -> [LauncherTarget] {
		guard let url = fileURL, let data = try? Data(contentsOf: url),
		      let targets = try? JSONDecoder().decode([LauncherTarget].self, from: data) else {
			return []
		}
		return targets
	}

	public func save(_ targets: [LauncherTarget]) {
		guard let url = fileURL, let data = try? JSONEncoder().encode(targets) else { return }
		try? data.write(to: url, options: .atomic)
	}

	@discardableResult
	public func add(_ target: LauncherTarget) -> [LauncherTarget] {
		var targets = load()
		targets.append(target)
		save(targets)
		return targets
	}

	@discardableResult
	public func update(_ target: LauncherTarget) -> [LauncherTarget] {
		var targets = load()
		if let i = targets.firstIndex(where: { $0.id == target.id }) {
			targets[i] = target
		}
		save(targets)
		return targets
	}

	@discardableResult
	public func remove(id: String) -> [LauncherTarget] {
		var targets = load()
		targets.removeAll { $0.id == id }
		save(targets)
		return targets
	}

	public func target(id: String) -> LauncherTarget? {
		load().first { $0.id == id }
	}

	/// A "Home Assistant" tile derived from the configured base URL — used as a
	/// fallback when the store is empty and as the Settings quick-add.
	public static func homeAssistantTarget(baseURLString: String) -> LauncherTarget? {
		guard !baseURLString.isEmpty, URL(string: baseURLString) != nil else { return nil }
		return LauncherTarget(
			id: "ha",
			name: "Home Assistant",
			urlString: baseURLString,
			symbol: "house.fill"
		)
	}
}
