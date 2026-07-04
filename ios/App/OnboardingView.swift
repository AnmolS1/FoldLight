import SwiftUI
import FoldKit

/// First-run onboarding: explains that FoldLight is a client for the user's own
/// Home Assistant, collects the base URL + long-lived token, and offers a
/// "explore with sample data" path that stays in mock mode. The first network
/// call happens on "Test & connect" — that's what triggers the iOS local-network
/// permission prompt, never at launch.
struct OnboardingView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.dismiss) private var dismiss
	@Bindable var settings: AppSettings

	@State private var testing = false
	@State private var testResult: String?
	@State private var testFailed = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				header

				BlueprintFormSection(
					"What you need",
					footer: "FoldLight is a client for your own Home Assistant server. Nothing leaves your device except calls to the server you configure."
				) {
					Label {
						Text("A Home Assistant instance reachable from this device")
							.font(Typography.text(14))
							.foregroundStyle(bp.ink)
							.fixedSize(horizontal: false, vertical: true)
					} icon: {
						Image(systemName: "house.fill").foregroundStyle(bp.crease)
					}
					Label {
						Text("A long-lived access token (Profile → Security in Home Assistant)")
							.font(Typography.text(14))
							.foregroundStyle(bp.ink)
							.fixedSize(horizontal: false, vertical: true)
					} icon: {
						Image(systemName: "key.fill").foregroundStyle(bp.crease)
					}
					Link(destination: URL(string: "https://www.home-assistant.io/docs/authentication/")!) {
						Text("How to create a token ↗")
							.font(Typography.text(13, weight: .semibold))
							.foregroundStyle(bp.crease)
					}
				}

				BlueprintFormSection(
					"Connect",
					footer: "Use HTTPS, or connect over your local network. Cleartext HTTP works only for Tailscale (*.ts.net) hosts."
				) {
					BlueprintField("Base URL", text: $settings.baseURLString, kind: .mono,
					               prompt: "https://homeassistant.local:8123", isURL: true)
					BlueprintField("Long-lived access token", text: $settings.token, kind: .monoSecure)
					BlueprintActionRow(
						title: "Test & connect",
						busy: testing,
						result: testResult,
						isError: testFailed,
						disabled: settings.baseURLString.isEmpty
					) {
						connect()
					}
				}

				Button {
					settings.hasCompletedOnboarding = true
					dismiss()
				} label: {
					Text("Explore with sample data")
						.font(Typography.text(15, weight: .semibold))
						.foregroundStyle(bp.crease)
						.frame(maxWidth: .infinity, minHeight: 44)
				}
				.buttonStyle(.plain)
				.background(bp.card, in: RoundedRectangle(cornerRadius: 12))
				.overlay(RoundedRectangle(cornerRadius: 12).stroke(bp.creaseLine, lineWidth: 0.5))
			}
			.padding(20)
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
		.background(GraphPaperBackground().ignoresSafeArea())
		.interactiveDismissDisabled()
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("Welcome to FoldLight")
				.font(Typography.display(26, weight: .bold))
				.foregroundStyle(bp.ink)
			Text("Widget-first light control for Home Assistant.")
				.font(Typography.text(15))
				.foregroundStyle(bp.ink60)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.top, 12)
	}

	private func connect() {
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
			if ok {
				settings.useMockData = false
				settings.hasCompletedOnboarding = true
				testing = false
				dismiss()
			} else {
				testResult = "Not reachable — check URL and token. You can also explore with sample data below."
				testFailed = true
				testing = false
			}
		}
	}
}
