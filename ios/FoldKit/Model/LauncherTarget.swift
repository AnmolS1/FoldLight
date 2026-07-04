import Foundation

/// A "open a web UI" target — not a device, just a deep link to a service's page.
/// Rendered as a blueprint tile in-app and as a `Link`/Control in widgets.
public struct LauncherTarget: Identifiable, Sendable, Hashable, Codable {
	public var id: String
	public var name: String
	public var urlString: String
	public var symbol: String   // SF Symbol name

	public init(id: String, name: String, urlString: String, symbol: String) {
		self.id = id
		self.name = name
		self.urlString = urlString
		self.symbol = symbol
	}

	public var url: URL? { URL(string: urlString) }
}

