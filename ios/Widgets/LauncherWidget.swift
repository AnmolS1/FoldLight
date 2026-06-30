import WidgetKit
import SwiftUI
import FoldKit

/// A simple "panel" widget: blueprint tiles that open a service's web UI (Home
/// Assistant, the Bambuddy printer page). Tapping a tile deep-links to the browser
/// via `Link` — no device actuation, just a shortcut.
struct LauncherWidget: Widget {
	let kind = "dev.ponderance.foldlight.LauncherWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: LauncherProvider()) { _ in
			LauncherWidgetView()
				.environment(\.blueprint, .dark)
				.containerBackground(for: .widget) {
					GraphPaperBackground().environment(\.blueprint, .dark)
				}
		}
		.configurationDisplayName("Panel")
		.description("Open Home Assistant or the printer.")
		.supportedFamilies([.systemSmall, .systemMedium])
	}
}

struct LauncherEntry: TimelineEntry { let date: Date }

struct LauncherProvider: TimelineProvider {
	func placeholder(in context: Context) -> LauncherEntry { LauncherEntry(date: Date()) }
	func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
		completion(LauncherEntry(date: Date()))
	}
	func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
		completion(Timeline(entries: [LauncherEntry(date: Date())], policy: .never))
	}
}

struct LauncherWidgetView: View {
	@Environment(\.blueprint) private var bp

	var body: some View {
		VStack(spacing: 8) {
			ForEach(LauncherTarget.all) { target in
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
