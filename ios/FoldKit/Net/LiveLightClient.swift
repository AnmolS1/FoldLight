import Foundation

/// Talks to the real Home Assistant REST API with a long-lived access token:
/// `GET /api/states[/<id>]` to read, `POST /api/services/light/...` to control,
/// `GET /api/` for the connectivity check.
public struct LiveLightClient: LightProviding {
	public let baseURL: URL
	public let token: String
	private let session: URLSession

	/// - Parameters:
	///   - baseURLString: HA root, e.g. `https://homeassistant.example.com:8123`.
	///     Tolerant of a missing scheme (defaults to `https://`), a trailing slash,
	///     or a pasted endpoint ending in `/api` / `/api/states` — all normalize to root.
	///   - token: HA long-lived access token, sent as `Authorization: Bearer …`.
	public init?(baseURLString: String, token: String, session: URLSession = .shared) {
		guard let url = URL(string: Self.normalizedBase(baseURLString)) else { return nil }
		self.baseURL = url
		self.token = token
		self.session = session
	}

	/// Reduce user input to the HA root URL string. Returns "" for empty input.
	static func normalizedBase(_ raw: String) -> String {
		var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !s.isEmpty else { return "" }
		if !s.contains("://") { s = "https://" + s }
		func trimTrailingSlashes() { while s.hasSuffix("/") { s.removeLast() } }
		trimTrailingSlashes()
		// Strip a pasted endpoint path back to the root.
		for suffix in ["/api/states", "/api/services", "/api"] where s.hasSuffix(suffix) {
			s.removeLast(suffix.count)
		}
		trimTrailingSlashes()
		return s
	}

	private func endpoint(_ path: String) -> URL {
		baseURL.appendingPathComponent(path)
	}

	private func authed(_ url: URL, method: String = "GET", json: [String: Any]? = nil) throws -> URLRequest {
		var req = URLRequest(url: url)
		req.httpMethod = method
		req.timeoutInterval = 5
		if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
		if let json {
			req.setValue("application/json", forHTTPHeaderField: "Content-Type")
			req.httpBody = try JSONSerialization.data(withJSONObject: json)
		}
		return req
	}

	private func run(_ req: URLRequest) async throws -> Data {
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: req)
		} catch {
			throw LightError.transport(error.localizedDescription)
		}
		if let http = response as? HTTPURLResponse {
			switch http.statusCode {
			case 200...299: break
			case 401, 403: throw LightError.unauthorized
			default: throw LightError.http(http.statusCode)
			}
		}
		return data
	}

	// MARK: Reads

	public func lights() async throws -> [LightState] {
		let data = try await run(try authed(endpoint("api/states")))
		let dtos: [HAEntityDTO]
		do {
			dtos = try JSONDecoder().decode([HAEntityDTO].self, from: data)
		} catch {
			throw LightError.decoding(error.localizedDescription)
		}
		return dtos
			.filter { $0.entity_id.hasPrefix("light.") }
			.map { $0.lightState }
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}

	public func light(_ entityID: String) async throws -> LightState {
		let data = try await run(try authed(endpoint("api/states/\(entityID)")))
		do {
			return try JSONDecoder().decode(HAEntityDTO.self, from: data).lightState
		} catch {
			throw LightError.decoding(error.localizedDescription)
		}
	}

	// MARK: Writes

	public func turnOn(_ entityID: String, brightnessPct: Int?, rgb: LightRGB?, kelvin: Int?) async throws {
		var body: [String: Any] = ["entity_id": entityID]
		if let brightnessPct { body["brightness_pct"] = max(0, min(100, brightnessPct)) }
		if let rgb { body["rgb_color"] = rgb.array }
		if let kelvin { body["color_temp_kelvin"] = kelvin }
		_ = try await run(try authed(endpoint("api/services/light/turn_on"), method: "POST", json: body))
	}

	public func turnOff(_ entityID: String) async throws {
		_ = try await run(try authed(endpoint("api/services/light/turn_off"), method: "POST", json: ["entity_id": entityID]))
	}

	public func toggle(_ entityID: String) async throws {
		_ = try await run(try authed(endpoint("api/services/light/toggle"), method: "POST", json: ["entity_id": entityID]))
	}

	public func testConnection() async -> Bool {
		guard let req = try? authed(endpoint("api/")) else { return false }
		guard let (_, response) = try? await session.data(for: req),
		      let http = response as? HTTPURLResponse else { return false }
		return http.statusCode == 200
	}
}

// MARK: - HA wire format

/// Raw `/api/states` entity as returned by Home Assistant. Only the attributes we
/// use are decoded; the rest are ignored.
struct HAEntityDTO: Decodable {
	let entity_id: String
	let state: String
	let attributes: Attributes

	struct Attributes: Decodable {
		let friendly_name: String?
		let brightness: Int?
		let rgb_color: [Int]?
		let color_temp_kelvin: Int?
		let supported_color_modes: [String]?
		let min_color_temp_kelvin: Int?
		let max_color_temp_kelvin: Int?
	}

	var lightState: LightState {
		let isOn = state == "on"
		let pct = attributes.brightness.map { Brightness.pct(fromHA255: $0) }
		return LightState(
			entityID: entity_id,
			name: attributes.friendly_name ?? entity_id,
			isOn: isOn,
			brightnessPct: isOn ? pct : nil,
			rgb: LightRGB(attributes.rgb_color),
			colorTempKelvin: attributes.color_temp_kelvin,
			supportedColorModes: attributes.supported_color_modes ?? [],
			minKelvin: attributes.min_color_temp_kelvin,
			maxKelvin: attributes.max_color_temp_kelvin
		)
	}
}
