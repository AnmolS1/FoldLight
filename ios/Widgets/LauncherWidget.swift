import WidgetKit
import SwiftUI
import FoldKit

/// A simple "panel" widget: blueprint tiles that open the user's launcher URLs
/// (managed in Settings → Launchers). Tapping a tile deep-links to the browser
/// via `Link` — no device actuation, just a shortcut. When the store is empty,
/// falls back to a Home Assistant tile from the configured base URL.
struct LauncherWidget: Widget {
	let kind = "dev.ponderance.foldlight.LauncherWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: LauncherProvider()) { entry in
			LauncherWidgetView(targets: entry.targets)
				.containerBackground(for: .widget) {
					SchemeResolvedGraphPaper()
				}
		}
		.configurationDisplayName("Panel")
		.description("Open your services' web UIs.")
		.supportedFamilies([.systemSmall, .systemMedium])
	}
}

/// Graph paper that resolves the blueprint palette from the ambient color
/// scheme — for `containerBackground`, whose hierarchy doesn't inherit the
/// entry view's `\.blueprint` override.
struct SchemeResolvedGraphPaper: View {
	@Environment(\.colorScheme) private var scheme

	var body: some View {
		GraphPaperBackground()
			.environment(\.blueprint, BlueprintColors.resolve(scheme))
	}
}

struct LauncherEntry: TimelineEntry {
	let date: Date
	let targets: [LauncherTarget]
}

struct LauncherProvider: TimelineProvider {
	private func currentTargets() -> [LauncherTarget] {
		let stored = LauncherStore.shared.load()
		if !stored.isEmpty { return stored }
		if let ha = LauncherStore.homeAssistantTarget(
			baseURLString: StoredConnection.load().baseURLString
		) {
			return [ha]
		}
		return []
	}

	func placeholder(in context: Context) -> LauncherEntry {
		LauncherEntry(date: Date(), targets: currentTargets())
	}
	func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
		completion(LauncherEntry(date: Date(), targets: currentTargets()))
	}
	func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
		completion(Timeline(entries: [LauncherEntry(date: Date(), targets: currentTargets())], policy: .never))
	}
}

struct LauncherWidgetView: View {
	@Environment(\.colorScheme) private var scheme
	let targets: [LauncherTarget]

	private var bp: BlueprintColors { BlueprintColors.resolve(scheme) }

	var body: some View {
		Group {
			if targets.isEmpty {
				VStack(spacing: 6) {
					Image(systemName: "square.grid.2x2")
						.font(.system(size: 20, weight: .semibold))
						.foregroundStyle(bp.ink60)
					Text("Add launchers in Settings")
						.font(Typography.text(12, weight: .semibold))
						.foregroundStyle(bp.ink60)
						.multilineTextAlignment(.center)
				}
			} else {
				VStack(spacing: 8) {
					ForEach(targets.prefix(3)) { target in
						if let url = target.url {
							Link(destination: url) {
								HStack(spacing: 10) {
									Image(systemName: target.symbol)
										.font(.system(size: 16, weight: .semibold))
										.foregroundStyle(bp.crease)
										.frame(width: 26)
									Text(target.name)
										.font(Typography.text(13, weight: .semibold))
										.foregroundStyle(bp.ink)
										.lineLimit(1)
									Spacer(minLength: 0)
									Image(systemName: "arrow.up.right")
										.font(.system(size: 10, weight: .bold))
										.foregroundStyle(bp.ink60)
								}
								.padding(.horizontal, 10)
								.frame(maxWidth: .infinity, minHeight: 40)
								.background(bp.card, in: RoundedRectangle(cornerRadius: 8))
								.overlay(RoundedRectangle(cornerRadius: 8).stroke(bp.creaseLine, lineWidth: 0.5))
							}
						}
					}
				}
			}
		}
		.environment(\.blueprint, bp)
	}
}
