import WidgetKit
import SwiftUI
import AppIntents
import FoldKit

/// The small interactive widget, dedicated to the one main light: a power toggle,
/// a brightness step row, and a row of preset swatches — each a button that fires
/// an App Intent straight to Home Assistant, no app launch.
struct LightWidget: Widget {
	let kind = "dev.ponderance.foldlight.LightWidget"

	var body: some WidgetConfiguration {
		// Same kind string as the previous StaticConfiguration — WidgetKit
		// migrates already-placed widgets in place; nil intent parameters
		// reproduce the old behavior (main light + favorite presets).
		AppIntentConfiguration(kind: kind, intent: LightWidgetConfigurationIntent.self,
		                       provider: LightTimelineProvider()) { entry in
			LightWidgetEntryView(entry: entry)
		}
		.configurationDisplayName("Light")
		.description("Toggle, dim, and recolor a chosen light.")
		.supportedFamilies([.systemSmall, .systemMedium])
	}
}

/// Resolves the blueprint palette from the system scheme (light + dark) for
/// both the content and the container background, then renders the widget.
struct LightWidgetEntryView: View {
	@Environment(\.colorScheme) private var scheme
	var entry: LightEntry

	var body: some View {
		let bp = BlueprintColors.resolve(scheme)
		LightWidgetView(entry: entry)
			.environment(\.blueprint, bp)
			.containerBackground(for: .widget) {
				SchemeResolvedGraphPaper()
			}
	}
}

struct LightWidgetView: View {
	@Environment(\.blueprint) private var bp
	var entry: LightEntry

	private var light: LightState? { entry.light }
	private var entity: LightAppEntity? { light.map(LightAppEntity.init) }

	var body: some View {
		if let light, let entity {
			VStack(alignment: .leading, spacing: 8) {
				header(light)
				if light.supportsBrightness { brightnessRow(entity) }
				if !entry.presets.isEmpty { swatchRow(entity) }
				Spacer(minLength: 0)
			}
		} else {
			unconfigured
		}
	}

	private func header(_ light: LightState) -> some View {
		HStack(spacing: 10) {
			BulbMark(color: light.displayColor, isOn: light.isOn, size: 26)
			VStack(alignment: .leading, spacing: 1) {
				Text(light.name)
					.font(Typography.text(13, weight: .semibold))
					.foregroundStyle(bp.ink)
					.lineLimit(1)
				Text(light.isOn ? "\(light.brightnessPct ?? 100)%" : "Off")
					.font(Typography.mono(11))
					.foregroundStyle(bp.ink60)
			}
			Spacer(minLength: 0)
			if let entity {
				Button(intent: ToggleLightIntent(light: entity)) {
					Image(systemName: "power")
						.font(.system(size: 14, weight: .bold))
						.foregroundStyle(light.isOn ? bp.graph : bp.ink)
						.frame(width: 32, height: 32)
						.background(light.isOn ? bp.sax : bp.card, in: Circle())
				}
				.buttonStyle(.plain)
			}
		}
	}

	private func brightnessRow(_ entity: LightAppEntity) -> some View {
		HStack(spacing: 5) {
			ForEach([25, 50, 75, 100], id: \.self) { pct in
				Button(intent: SetBrightnessIntent(light: entity, percent: pct)) {
					Text("\(pct)")
						.font(Typography.mono(11))
						.foregroundStyle(bp.ink)
						.frame(maxWidth: .infinity, minHeight: 26)
						.background(bp.card, in: RoundedRectangle(cornerRadius: 6))
						.overlay(RoundedRectangle(cornerRadius: 6).stroke(bp.creaseLine, lineWidth: 0.5))
				}
				.buttonStyle(.plain)
			}
		}
	}

	private func swatchRow(_ entity: LightAppEntity) -> some View {
		HStack(spacing: 7) {
			ForEach(entry.presets) { preset in
				Button(intent: ApplyPresetIntent(light: entity, preset: PresetAppEntity(preset))) {
					Circle()
						.fill(preset.swatch)
						.frame(width: 26, height: 26)
						.overlay(Circle().stroke(bp.ink.opacity(0.25), lineWidth: 0.5))
				}
				.buttonStyle(.plain)
			}
			Spacer(minLength: 0)
		}
	}

	private var unconfigured: some View {
		VStack(spacing: 6) {
			BulbMark(color: nil, isOn: false, size: 26)
			Text(entry.unreachable ? "Unreachable" : "No light")
				.font(Typography.text(12))
				.foregroundStyle(bp.ink60)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
