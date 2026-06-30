import SwiftUI
import FoldKit

/// Minimal host UI: three tabs — Editor (dial colors + save presets), Panel (web
/// launchers), and Settings. Deliberately not a dashboard; widgets are the star.
struct RootView: View {
	@Bindable var settings: AppSettings
	@Environment(\.colorScheme) private var colorScheme
	@State private var vm: LightsViewModel

	init(settings: AppSettings) {
		self.settings = settings
		_vm = State(initialValue: LightsViewModel(settings: settings))
	}

	private var bp: BlueprintColors { BlueprintColors.resolve(colorScheme) }

	var body: some View {
		TabView {
			tab(EditorView(vm: vm, settings: settings), "Light", "lightbulb")
			tab(PanelView(), "Panel", "square.grid.2x2")
			tab(SettingsView(settings: settings), "Settings", "gearshape")
		}
		.tint(bp.sax)
		.environment(\.blueprint, bp)
		.task { await vm.refresh() }
		.onChange(of: settings.useMockData) { _, _ in vm.applySettings(settings) }
		.onChange(of: settings.baseURLString) { _, _ in vm.applySettings(settings) }
		.onChange(of: settings.token) { _, _ in vm.applySettings(settings) }
	}

	private func tab(_ content: some View, _ title: String, _ symbol: String) -> some View {
		NavigationStack {
			ZStack {
				GraphPaperBackground()
				content
			}
			.navigationTitle(title)
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
		}
		.tabItem { Label(title, systemImage: symbol) }
	}
}
