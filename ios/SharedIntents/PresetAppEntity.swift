import AppIntents
import FoldKit

/// A saved preset, pickable in widgets/Shortcuts/controls. Backed by `PresetStore`
/// (App Group), so the swatches the user saved in the app become applyable here.
public struct PresetAppEntity: AppEntity {
	public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Preset" }
	public static let defaultQuery = PresetEntityQuery()

	public let id: String      // LightPreset.id.uuidString
	public var name: String

	public init(id: String, name: String) {
		self.id = id
		self.name = name
	}

	public init(_ preset: LightPreset) {
		self.id = preset.id.uuidString
		self.name = preset.name
	}

	public var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(name)")
	}
}

public struct PresetEntityQuery: EntityQuery {
	public init() {}

	public func entities(for identifiers: [String]) async throws -> [PresetAppEntity] {
		PresetStore.shared.load()
			.filter { identifiers.contains($0.id.uuidString) }
			.map(PresetAppEntity.init)
	}

	public func suggestedEntities() async throws -> [PresetAppEntity] {
		PresetStore.shared.load().map(PresetAppEntity.init)
	}

	public func defaultResult() async -> PresetAppEntity? {
		PresetStore.shared.load().first.map(PresetAppEntity.init)
	}
}
