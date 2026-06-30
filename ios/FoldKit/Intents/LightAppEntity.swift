import AppIntents

/// A Home Assistant light, pickable in widget configuration, Shortcuts, and
/// Control Center controls. Backed by the App-Group light cache (with a best-effort
/// live fallback) so suggestions appear without opening the app.
public struct LightAppEntity: AppEntity {
	public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Light" }
	public static let defaultQuery = LightEntityQuery()

	public let id: String      // HA entity_id, e.g. "light.yetstrhom"
	public var name: String

	public init(id: String, name: String) {
		self.id = id
		self.name = name
	}

	public init(_ state: LightState) {
		self.id = state.entityID
		self.name = state.name
	}

	public var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(name)", subtitle: "\(id)")
	}
}

public struct LightEntityQuery: EntityQuery {
	public init() {}

	private func allLights() async -> [LightState] {
		let cached = LightCache.shared.read()
		if !cached.isEmpty { return cached }
		// Cold cache (e.g. picking in widget config before first run): try live.
		return (try? await StoredConnection.load().makeProvider().lights()) ?? LightState.samples
	}

	public func entities(for identifiers: [String]) async throws -> [LightAppEntity] {
		let all = await allLights()
		return all.filter { identifiers.contains($0.entityID) }.map(LightAppEntity.init)
	}

	public func suggestedEntities() async throws -> [LightAppEntity] {
		await allLights().map(LightAppEntity.init)
	}

	public func defaultResult() async -> LightAppEntity? {
		let all = await allLights()
		let main = all.first(where: { $0.supportsColor || $0.supportsColorTemp }) ?? all.first
		return main.map(LightAppEntity.init)
	}
}
