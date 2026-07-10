import Foundation
import FoldKit

/// Deterministic setup for App Store listing screenshots, gated entirely behind the
/// `--uitest-screenshots` launch argument so production builds are unaffected.
///
/// Capture is driven from the command line (`xcrun simctl launch … --uitest-screenshots
/// --screen editor`, then `simctl io screenshot`), relaunching once per screen — no
/// UI-test target, no fastlane. `--screen <name>` selects which tab/section to show.
enum ScreenshotSupport {
	/// Which screen the capturer asked for (`--screen <name>`).
	enum Screen: String {
		case editor      // Light editor — colored bulb + brightness/temp/color controls
		case presets     // same tab, scrolled to the Warm / Focus / Movie preset library
		case panel       // web-UI launcher tiles
		case settings    // connection settings (mock, no real host/token)

		/// The RootView tab this screen lives in.
		var tab: RootTab {
			switch self {
			case .editor, .presets: return .light
			case .panel: return .panel
			case .settings: return .settings
			}
		}
	}

	/// True when launched for screenshot capture.
	static let isActive = ProcessInfo.processInfo.arguments.contains("--uitest-screenshots")

	/// The requested screen, defaulting to the editor.
	static let screen: Screen = {
		let args = ProcessInfo.processInfo.arguments
		if let i = args.firstIndex(of: "--screen"), i + 1 < args.count,
		   let s = Screen(rawValue: args[i + 1]) {
			return s
		}
		return .editor
	}()

	/// Force a populated, secret-free, deterministic state: mock lights on, seeded
	/// presets + fake launcher tiles, no real Home Assistant host or token, onboarding
	/// already dismissed. Safe to run only under `isActive`.
	@MainActor
	static func seed(_ settings: AppSettings) {
		guard isActive else { return }

		// Never render a real server or token in the Settings shot.
		settings.useMockData = true
		settings.baseURLString = ""
		settings.token = ""
		// Keep the onboarding sheet from covering the first screen.
		settings.hasCompletedOnboarding = true

		// Open the editor on the on, RGB-colored bulb (Yetstrhöm) so shot 01 shows the
		// full color controls — otherwise the editor falls back to the first
		// color-capable light by name (Desk Lamp, temperature-only → no color picker).
		LightPrefsStore.shared.save(LightPrefs(mainLightID: "light.yetstrhom"))

		// Deterministic preset library (Warm / Focus / Movie red).
		PresetStore.shared.save(LightPreset.seedDefaults)

		// Obviously-fake, mDNS-style launcher tiles for the Panel shot — no secrets.
		LauncherStore.shared.save([
			LauncherTarget(id: "ha", name: "Home Assistant",
			               urlString: "http://homeassistant.local:8123", symbol: "house.fill"),
			LauncherTarget(id: "grafana", name: "Grafana",
			               urlString: "http://grafana.local:3000", symbol: "chart.xyaxis.line"),
			LauncherTarget(id: "proxmox", name: "Proxmox",
			               urlString: "https://proxmox.local:8006", symbol: "server.rack"),
			LauncherTarget(id: "pihole", name: "Pi-hole",
			               urlString: "http://pihole.local/admin", symbol: "shield.lefthalf.filled"),
		])
	}
}
