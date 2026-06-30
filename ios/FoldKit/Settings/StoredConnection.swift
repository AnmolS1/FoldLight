import Foundation

/// A nonisolated snapshot of the connection settings, readable from a widget's or
/// App Intent's background context (where the `@MainActor` `AppSettings` can't be
/// used). Built fresh each call from the App Group + Keychain.
public struct StoredConnection: Sendable {
	public let baseURLString: String
	public let token: String
	public let useMock: Bool

	public static func load() -> StoredConnection {
		let store = AppSettings.defaultStore()
		let keychain = KeychainStore(accessGroup: AppSettings.keychainGroup)
		let useMock = (store.object(forKey: SettingsKeys.useMock) as? Bool) ?? true
		let base = store.string(forKey: SettingsKeys.baseURL) ?? AppSettings.defaultBaseURL
		let token = keychain.string(for: SettingsKeys.token) ?? ""
		return StoredConnection(baseURLString: base, token: token, useMock: useMock)
	}

	public func makeProvider() -> any LightProviding {
		if useMock { return MockLightClient() }
		return LiveLightClient(baseURLString: baseURLString, token: token) ?? MockLightClient()
	}
}
