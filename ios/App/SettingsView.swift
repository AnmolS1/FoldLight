import SwiftUI
import FoldKit

/// Connection settings: mock toggle, HA base URL + long-lived token (Keychain),
/// and a "Test connection" button that hits `GET /api/`.
struct SettingsView: View {
	@Environment(\.blueprint) private var bp
	@Bindable var settings: AppSettings

	@State private var testing = false
	@State private var testResult: String?

	var body: some View {
		Form {
			Section {
				Toggle("Use mock data", isOn: $settings.useMockData)
			} footer: {
				Text("Render bundled sample lights with no server. Turn off to connect to Home Assistant.")
			}

			Section("Home Assistant") {
				TextField("Base URL", text: $settings.baseURLString)
					.textContentType(.URL)
					.disableAutocorrection(true)
					#if os(iOS)
					.textInputAutocapitalization(.never)
					.keyboardType(.URL)
					#endif
				SecureField("Long-lived access token", text: $settings.token)

				Button {
					runTest()
				} label: {
					HStack {
						Text("Test connection")
						if testing { Spacer(); ProgressView() }
					}
				}
				.disabled(testing || settings.baseURLString.isEmpty)

				if let testResult {
					Text(testResult).foregroundStyle(bp.ink60)
				}
			}
			.disabled(settings.useMockData)
		}
		.scrollContentBackground(.hidden)
	}

	private func runTest() {
		testing = true
		testResult = nil
		let urlString = settings.baseURLString
		let token = settings.token
		Task {
			let ok: Bool
			if let client = LiveLightClient(baseURLString: urlString, token: token) {
				ok = await client.testConnection()
			} else {
				ok = false
			}
			testResult = ok ? "Reachable ✓" : "Not reachable — check URL and token."
			testing = false
		}
	}
}
