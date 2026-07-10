import SwiftUI
import FoldKit

@main
struct FoldLightApp: App {
	@State private var settings = AppSettings.shared

	init() {
		BlueprintFonts.registerAll()
		// Deterministic, secret-free state for App Store screenshot capture (no-op
		// unless launched with `--uitest-screenshots`).
		ScreenshotSupport.seed(AppSettings.shared)
	}

	var body: some Scene {
		WindowGroup {
			RootView(settings: settings)
		}
		#if os(macOS)
		// A roomier window for App Store screenshot capture (still fits the ~1169pt
		// screen height); the normal launch stays compact.
		.defaultSize(width: ScreenshotSupport.isActive ? 680 : 460,
		             height: ScreenshotSupport.isActive ? 1040 : 720)
		#endif
	}
}
