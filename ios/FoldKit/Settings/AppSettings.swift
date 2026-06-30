import Foundation
import Observation

/// Persisted settings keys, shared by `AppSettings` (read/write, main actor) and
/// `StoredConnection` (read-only, any actor — used by widgets/intents).
public enum SettingsKeys {
	public static let baseURL = "baseURLString"
	public static let useMock = "useMockData"
	public static let token = "haToken"
}

/// Observable app configuration, shared between the app and the widgets.
///
/// Non-secret prefs (base URL, mock toggle) live in the App Group `UserDefaults`
/// so widgets can read them; the Home Assistant long-lived token lives in the
/// shared Keychain group. Defaults to **mock mode** so the app renders with no
/// server configured.
@MainActor
@Observable
public final class AppSettings {
	public nonisolated static let appGroup = "group.dev.ponderance.foldlight"
	// Use the App Group as the Keychain access group: app-group identifiers work
	// as keychain groups WITHOUT the team prefix, so the app and widget (both in
	// this group) share the token.
	public nonisolated static let keychainGroup = appGroup

	/// The default base URL FoldLight ships with. The raw Tailscale address is used
	/// (proven reachable) rather than the Caddy HTTPS hostname, whose internal cert
	/// isn't always trusted on-device. Override in Settings for a different host.
	public nonisolated static let defaultBaseURL = "http://100.65.218.62:8123"

	public static let shared = AppSettings()

	private typealias Keys = SettingsKeys

	private let defaults: UserDefaults
	private let keychain: KeychainStore

	public var baseURLString: String {
		didSet { defaults.set(baseURLString, forKey: Keys.baseURL) }
	}

	/// When true, the app renders bundled mock lights instead of hitting HA.
	public var useMockData: Bool {
		didSet { defaults.set(useMockData, forKey: Keys.useMock) }
	}

	/// Home Assistant long-lived access token; persisted to the Keychain.
	public var token: String {
		didSet { keychain.set(token, for: Keys.token) }
	}

	public init(
		defaults: UserDefaults = AppSettings.defaultStore(),
		keychain: KeychainStore = KeychainStore(accessGroup: AppSettings.keychainGroup)
	) {
		self.defaults = defaults
		self.keychain = keychain
		// `useMockData` defaults to true the first time (no key present yet).
		self.useMockData = (defaults.object(forKey: Keys.useMock) as? Bool) ?? true
		self.baseURLString = defaults.string(forKey: Keys.baseURL) ?? AppSettings.defaultBaseURL
		self.token = keychain.string(for: Keys.token) ?? ""
	}

	/// App Group store when available, else the standard store (unsigned builds).
	public nonisolated static func defaultStore() -> UserDefaults {
		UserDefaults(suiteName: appGroup) ?? .standard
	}

	/// The light provider implied by the current settings.
	public func makeProvider() -> any LightProviding {
		if useMockData { return MockLightClient() }
		if let live = LiveLightClient(baseURLString: baseURLString, token: token) {
			return live
		}
		return MockLightClient()
	}
}
