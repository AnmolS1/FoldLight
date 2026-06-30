import Foundation

/// Brightness unit conversion. Home Assistant **reports** `brightness` as 0–255
/// but the `light.turn_on` service **accepts** `brightness_pct` as 0–100. Keeping
/// the conversion in one tested place avoids the subtle off-by-scale bugs that
/// come from mixing the two.
public enum Brightness {
	/// HA's 0–255 byte → 0–100 percent (rounded).
	public static func pct(fromHA255 value: Int) -> Int {
		let clamped = max(0, min(255, value))
		return Int((Double(clamped) / 255.0 * 100.0).rounded())
	}

	/// 0–100 percent → HA's 0–255 byte (rounded). Used for optimistic UI/state.
	public static func ha255(fromPct pct: Int) -> Int {
		let clamped = max(0, min(100, pct))
		return Int((Double(clamped) / 100.0 * 255.0).rounded())
	}
}

/// Abstracts the source of light state + control so the UI/widgets run against
/// either live Home Assistant or bundled mock data without changing.
public protocol LightProviding: Sendable {
	/// All `light.*` entities and their current state.
	func lights() async throws -> [LightState]
	/// One light's current state.
	func light(_ entityID: String) async throws -> LightState
	/// `light.turn_on` with any subset of brightness (pct 0–100) / rgb / kelvin.
	func turnOn(_ entityID: String, brightnessPct: Int?, rgb: LightRGB?, kelvin: Int?) async throws
	func turnOff(_ entityID: String) async throws
	func toggle(_ entityID: String) async throws
	/// Lightweight connectivity check (`GET /api/`). True when reachable + authorized.
	func testConnection() async -> Bool
}

public extension LightProviding {
	/// Apply a saved preset to a light (turn on + brightness + color/temp).
	func apply(_ preset: LightPreset, to entityID: String) async throws {
		try await turnOn(
			entityID,
			brightnessPct: preset.brightnessPct,
			rgb: preset.rgb,
			kelvin: preset.kelvin
		)
	}
}

/// Errors surfaced by the live client.
public enum LightError: LocalizedError, Equatable {
	case notConfigured
	case badURL
	case unauthorized
	case http(Int)
	case decoding(String)
	case transport(String)

	public var errorDescription: String? {
		switch self {
		case .notConfigured: return "No Home Assistant configured. Add a URL and token in Settings."
		case .badURL: return "The configured base URL is invalid."
		case .unauthorized: return "Unauthorized — check your long-lived access token."
		case .http(let code): return "Home Assistant returned HTTP \(code)."
		case .decoding(let msg): return "Could not read the light state: \(msg)"
		case .transport(let msg): return msg
		}
	}
}
