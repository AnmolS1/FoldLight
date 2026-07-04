import SwiftUI
import FoldKit

@main
struct FoldLightApp: App {
	@State private var settings = AppSettings.shared

	init() {
		BlueprintFonts.registerAll()
	}

	var body: some Scene {
		WindowGroup {
			RootView(settings: settings)
		}
		#if os(macOS)
		.defaultSize(width: 460, height: 720)
		#endif
	}
}
