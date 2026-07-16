import SwiftUI
import FoldKit

/// The three host tabs. A stable identity (vs. positional selection) lets the
/// screenshot launch-arg jump straight to a tab.
enum RootTab: Hashable { case light, panel, settings }

/// iPad-only layout polish: the host UI is a compact phone-style column, which
/// looks stretched and top-anchored on iPad's wide, tall canvas. On iPad this caps
/// the content to a readable column width and centers it vertically in the scroll
/// viewport so the layout reads as intentional. No effect on iPhone (the screen is
/// narrower than the cap and content ~fills it) or macOS (`#else` passthrough), so
/// those layouts — and their screenshots — are unchanged.
private struct IPadColumn: ViewModifier {
	var maxWidth: CGFloat = 600
	func body(content: Content) -> some View {
		#if os(iOS)
		if UIDevice.current.userInterfaceIdiom == .pad {
			content
				.frame(maxWidth: maxWidth)
				.frame(maxWidth: .infinity)
				.containerRelativeFrame(.vertical, alignment: .center)
		} else {
			content
		}
		#else
		content
		#endif
	}
}

extension View {
	/// Cap width + vertically center scroll content on iPad only (see `IPadColumn`).
	func iPadColumn(maxWidth: CGFloat = 600) -> some View { modifier(IPadColumn(maxWidth: maxWidth)) }
}

/// Minimal host UI: three tabs — Editor (dial colors + save presets), Panel (web
/// launchers), and Settings. Deliberately not a dashboard; widgets are the star.
struct RootView: View {
	@Bindable var settings: AppSettings
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.colorSchemeContrast) private var contrast
	@State private var vm: LightsViewModel
	@State private var selectedTab: RootTab

	init(settings: AppSettings) {
		self.settings = settings
		_vm = State(initialValue: LightsViewModel(settings: settings))
		// Screenshot capture selects the tab via `--screen`; normal launches open Light.
		_selectedTab = State(initialValue: ScreenshotSupport.isActive ? ScreenshotSupport.screen.tab : .light)
	}

	private var bp: BlueprintColors { BlueprintColors.resolve(colorScheme, contrast: contrast) }

	@State private var showOnboarding = false

	var body: some View {
		TabView(selection: $selectedTab) {
			tab(EditorView(vm: vm, settings: settings), "Light", "lightbulb").tag(RootTab.light)
			tab(PanelView(), "Panel", "square.grid.2x2").tag(RootTab.panel)
			tab(SettingsView(settings: settings), "Settings", "gearshape").tag(RootTab.settings)
		}
		.tint(bp.sax)
		.environment(\.blueprint, bp)
		.onAppear { showOnboarding = !settings.hasCompletedOnboarding }
		.sheet(isPresented: $showOnboarding) {
			OnboardingView(settings: settings)
				.environment(\.blueprint, bp)
		}
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
