import SwiftUI
import FoldKit

/// The "Panel": blueprint tiles that open a service's web UI (Home Assistant, the
/// Bambuddy printer page). Launch-only — no device control. Generic multi-device
/// control lands in Pass 2.
struct PanelView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.openURL) private var openURL

	var body: some View {
		ScrollView {
			VStack(spacing: 12) {
				ForEach(LauncherTarget.all) { target in
					Button {
						if let url = target.url { openURL(url) }
					} label: {
						HStack(spacing: 14) {
							Image(systemName: target.symbol)
								.font(.system(size: 20, weight: .semibold))
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
							}
							Spacer(minLength: 0)
							Image(systemName: "arrow.up.right.square")
								.font(.system(size: 16, weight: .semibold))
								.foregroundStyle(bp.ink60)
						}
						.padding(14)
						.frame(maxWidth: .infinity)
						.background(bp.card, in: RoundedRectangle(cornerRadius: 12))
						.overlay(RoundedRectangle(cornerRadius: 12).stroke(bp.creaseLine, lineWidth: 0.5))
					}
					.buttonStyle(.plain)
				}
			}
			.padding(16)
		}
	}
}
