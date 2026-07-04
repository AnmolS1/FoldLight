import SwiftUI
import FoldKit

/// Connection settings: mock toggle, HA base URL + long-lived token (Keychain),
/// and a "Test connection" button that hits `GET /api/`. Blueprint-styled —
/// labels above full-width fields on graph paper, never a stock `Form`.
struct SettingsView: View {
	@Environment(\.blueprint) private var bp
	@Bindable var settings: AppSettings

	@State private var testing = false
	@State private var testResult: String?
	@State private var testFailed = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				BlueprintFormSection(
					footer: "Render bundled sample lights with no server. Turn off to connect to Home Assistant."
				) {
					BlueprintToggleRow("Use mock data", isOn: $settings.useMockData)
				}

				BlueprintFormSection(
					"Home Assistant",
					footer: "Create a long-lived access token in Home Assistant under your profile → Security."
				) {
					BlueprintField("Base URL", text: $settings.baseURLString, kind: .mono,
					               prompt: "https://homeassistant.local:8123", isURL: true)
					BlueprintField("Long-lived access token", text: $settings.token, kind: .monoSecure)
					BlueprintActionRow(
						title: "Test connection",
						busy: testing,
						result: testResult,
						isError: testFailed,
						disabled: settings.baseURLString.isEmpty
					) {
						runTest()
					}
				}
				.disabled(settings.useMockData)
				.opacity(settings.useMockData ? 0.5 : 1)

				BlueprintFormSection("Lights & launchers") {
					NavigationLink {
						LightsManagerView(settings: settings)
					} label: {
						BlueprintNavRow(
							"Lights",
							subtitle: "Pick the main light, reorder favorites, rename",
							systemImage: "lightbulb"
						)
					}
					.buttonStyle(.plain)
					NavigationLink {
						LaunchersManagerView(settings: settings)
					} label: {
						BlueprintNavRow(
							"Launchers",
							subtitle: "Tiles that open your services' web UIs",
							systemImage: "square.grid.2x2"
						)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(16)
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
	}

	private func runTest() {
		testing = true
		testResult = nil
		testFailed = false
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
			testFailed = !ok
			testing = false
		}
	}
}
