import XCTest
@testable import FoldKit

/// The phone reaches Home Assistant over Tailscale. The first request after the
/// tunnel has been idle can stall for several seconds while it reconnects, so a
/// single short-timeout attempt surfaced as a sporadic "The request timed out."
/// These pin the recovery: one retry on a transient transport error, never on a
/// non-idempotent call, and the configured timeout actually on the request.
final class TransientRetryTests: XCTestCase {

	override func tearDown() {
		StubProtocol.reset()
		super.tearDown()
	}

	private func client(timeout: TimeInterval = 5, retries: Int = 1) throws -> LiveLightClient {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [StubProtocol.self]
		return try XCTUnwrap(LiveLightClient(baseURLString: "http://ha.example.ts.net:8123", token: "t",
		                                     session: URLSession(configuration: config),
		                                     timeout: timeout, retries: retries))
	}

	/// `/api/states` body built from the captured real fixture.
	private func statesBody() throws -> Data {
		let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "state-yetstrhom", withExtension: "json"))
		let one = try Data(contentsOf: url)
		return Data("[".utf8) + one + Data("]".utf8)
	}

	func testReadRecoversAfterOneTimeout() async throws {
		StubProtocol.script = [.fail(.timedOut), .ok(try statesBody())]
		let lights = try await client().lights()
		XCTAssertEqual(lights.map(\.entityID), ["light.yetstrhom"])
		XCTAssertEqual(StubProtocol.requestCount, 2)
	}

	func testGivesUpAfterRetryBudget() async throws {
		StubProtocol.script = [.fail(.timedOut), .fail(.timedOut), .ok(try statesBody())]
		do {
			_ = try await client().lights()
			XCTFail("expected a transport error")
		} catch let e as LightError {
			guard case .transport = e else { return XCTFail("wrong error \(e)") }
		}
		XCTAssertEqual(StubProtocol.requestCount, 2, "one try + one retry, no more")
	}

	func testToggleIsNeverRetried() async throws {
		// A timed-out toggle may still have reached HA; repeating it would flip the
		// light back. Unlike turn_on/turn_off it is not idempotent.
		StubProtocol.script = [.fail(.timedOut), .ok(Data("[]".utf8))]
		do {
			try await client().toggle("light.yetstrhom")
			XCTFail("expected a transport error")
		} catch is LightError {}
		XCTAssertEqual(StubProtocol.requestCount, 1)
	}

	func testIdempotentWriteIsRetried() async throws {
		StubProtocol.script = [.fail(.networkConnectionLost), .ok(Data("[]".utf8))]
		try await client().turnOn("light.yetstrhom", brightnessPct: 50, rgb: nil, kelvin: nil)
		XCTAssertEqual(StubProtocol.requestCount, 2)
	}

	func testNonTransientErrorIsNotRetried() async throws {
		StubProtocol.script = [.fail(.badURL), .ok(try statesBody())]
		do { _ = try await client().lights(); XCTFail("expected an error") } catch is LightError {}
		XCTAssertEqual(StubProtocol.requestCount, 1)
	}

	func testConfiguredTimeoutIsOnTheRequest() async throws {
		StubProtocol.script = [.ok(try statesBody())]
		_ = try await client(timeout: 15).lights()
		XCTAssertEqual(StubProtocol.lastTimeout, 15)
	}

	func testWidgetDefaultKeepsShortTimeout() throws {
		// Widgets/intents run on a tight system budget; only the app opts into the
		// longer foreground timeout.
		let c = try XCTUnwrap(LiveLightClient(baseURLString: "http://ha.example.ts.net:8123", token: "t"))
		XCTAssertEqual(c.timeout, 5)
	}

	func testAppProviderUsesForegroundTimeout() throws {
		// Goes through the same factory the app's view model uses.
		let provider = AppSettings.makeProvider(useMock: false, baseURLString: "http://ha.example.ts.net:8123", token: "t")
		let c = try XCTUnwrap(provider as? LiveLightClient)
		XCTAssertEqual(c.timeout, 15)
	}
}

/// Plays back a scripted sequence of responses, one per request.
final class StubProtocol: URLProtocol {
	enum Step { case ok(Data), fail(URLError.Code) }

	nonisolated(unsafe) static var script: [Step] = []
	nonisolated(unsafe) static var requestCount = 0
	nonisolated(unsafe) static var lastTimeout: TimeInterval?
	private static let lock = NSLock()

	static func reset() {
		lock.lock(); defer { lock.unlock() }
		script = []; requestCount = 0; lastTimeout = nil
	}

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		Self.lock.lock()
		Self.requestCount += 1
		Self.lastTimeout = request.timeoutInterval
		let step = Self.script.isEmpty ? .fail(.unknown) : Self.script.removeFirst()
		Self.lock.unlock()

		switch step {
		case .fail(let code):
			client?.urlProtocol(self, didFailWithError: URLError(code))
		case .ok(let data):
			let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
			client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		}
	}

	override func stopLoading() {}
}
