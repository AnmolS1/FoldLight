import SwiftUI
import FoldKit

/// The "Panel": blueprint tiles that open a service's web UI. Launch-only — no
/// device control. Tiles are user-managed (Settings → Launchers) and ship empty.
struct PanelView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.openURL) private var openURL

	@State private var targets: [LauncherTarget] = []
	// A visible focus ring for keyboard users: `.buttonStyle(.plain)` strips the
	// system ring, so drive our own from focus state (mainly for macOS Tab nav).
	@FocusState private var focusedTile: String?

	var body: some View {
		ScrollView {
			VStack(spacing: 12) {
				if targets.isEmpty {
					emptyState
				} else {
					ForEach(targets) { target in
						Button {
							if let url = target.url { openURL(url) }
						} label: {
							LauncherTileLabel(target: target)
						}
						.buttonStyle(.plain)
						.focused($focusedTile, equals: target.id)
						.overlay(
							RoundedRectangle(cornerRadius: 12)
								.strokeBorder(bp.crease, lineWidth: focusedTile == target.id ? 2.5 : 0)
						)
						.accessibilityLabel(target.name)
						.accessibilityValue("Opens \(target.urlString)")
						.accessibilityHint("Double-tap to open in your browser")
						#if os(macOS)
						.help("Open \(target.name) — \(target.urlString)")
						#endif
					}
				}
			}
			.padding(16)
			.iPadColumn()
		}
		.onAppear { targets = LauncherStore.shared.load() }
	}

	private var emptyState: some View {
		VStack(spacing: 8) {
			Image(systemName: "square.grid.2x2")
				.font(.system(size: 28, weight: .semibold))
				.foregroundStyle(bp.ink60)
			Text("No launchers yet")
				.font(Typography.text(15, weight: .semibold))
				.foregroundStyle(bp.ink)
			Text("Add tiles that open your services' web UIs in Settings → Launchers.")
				.font(Typography.text(13))
				.foregroundStyle(bp.ink60)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(24)
		.frame(maxWidth: .infinity)
		.background(bp.card, in: RoundedRectangle(cornerRadius: 12))
		.overlay(RoundedRectangle(cornerRadius: 12).stroke(bp.creaseLine, lineWidth: 0.5))
	}
}

/// The tile row shared by the in-app panel (and mirrored by the widget).
struct LauncherTileLabel: View {
	@Environment(\.blueprint) private var bp
	// Icon scales with Dynamic Type / system text size rather than a fixed 20pt.
	@ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 20
	@ScaledMetric(relativeTo: .body) private var trailingIcon: CGFloat = 16
	let target: LauncherTarget

	var body: some View {
		HStack(spacing: 14) {
			Image(systemName: target.symbol)
				.font(.system(size: iconSize, weight: .semibold))
				.foregroundStyle(bp.crease)
				.frame(width: 32)
			VStack(alignment: .leading, spacing: 2) {
				Text(target.name)
					.font(Typography.text(15, weight: .semibold))
					.foregroundStyle(bp.ink)
				Text(target.urlString)
					.font(Typography.mono(10))
					.foregroundStyle(bp.ink60)
					.lineLimit(1)
					.truncationMode(.middle)
			}
			Spacer(minLength: 0)
			Image(systemName: "arrow.up.right.square")
				.font(.system(size: trailingIcon, weight: .semibold))
				.foregroundStyle(bp.ink60)
		}
		.padding(14)
		.frame(maxWidth: .infinity)
		.background(bp.card, in: RoundedRectangle(cornerRadius: 12))
		.overlay(RoundedRectangle(cornerRadius: 12).stroke(bp.creaseLine, lineWidth: 0.5))
	}
}
