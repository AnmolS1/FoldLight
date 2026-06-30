import SwiftUI
import FoldKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Dial a light's brightness / color / white-temperature (only the controls the
/// bulb actually supports), preview it live, apply to HA, and save the result as a
/// preset that then appears as a widget swatch.
struct EditorView: View {
	@Environment(\.blueprint) private var bp
	@Bindable var vm: LightsViewModel
	@Bindable var settings: AppSettings

	@State private var selectedID: String?
	@State private var brightness: Double = 100
	@State private var kelvin: Double = 3000
	@State private var color: Color = .orange
	@State private var mode: ColorMode = .white
	@State private var presetName = ""
	@State private var presets: [LightPreset] = []
	@State private var colorDebounce: Task<Void, Never>?

	enum ColorMode: String, CaseIterable { case white = "White", color = "Color" }

	private var light: LightState? {
		if let selectedID, let l = vm.light(withID: selectedID) { return l }
		return vm.lights.first
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 16) {
				statusBanner
				if vm.lights.isEmpty {
					emptyState
				} else {
					picker
					if let light {
						preview(light)
						if light.isOnOffOnly {
							onOffControls(light)
						} else {
							controls(light)
							presetLibrary(light)
						}
					}
				}
			}
			.padding(16)
		}
		.task(id: light?.entityID) { syncFromLight() }
		.onAppear { presets = PresetStore.shared.load() }
	}

	// MARK: Status banner

	@ViewBuilder private var statusBanner: some View {
		if settings.useMockData {
			banner("Mock data — real lights aren't being controlled. Turn off \u{201C}Use mock data\u{201D} in Settings.", color: bp.sax)
		} else if let err = vm.lastError {
			banner("Can't reach Home Assistant: \(err)", color: bp.crane)
		}
	}

	private func banner(_ text: String, color: Color) -> some View {
		HStack(spacing: 8) {
			Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(color)
			Text(text).font(Typography.text(12)).foregroundStyle(bp.ink)
			Spacer(minLength: 0)
		}
		.padding(10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
		.overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.5), lineWidth: 0.5))
	}

	// MARK: Light picker

	private var picker: some View {
		Picker("Light", selection: Binding(
			get: { light?.entityID ?? "" },
			set: { selectedID = $0 }
		)) {
			ForEach(vm.lights) { l in Text(l.name).tag(l.entityID) }
		}
		.pickerStyle(.segmented)
	}

	// MARK: Preview

	private func preview(_ light: LightState) -> some View {
		VStack(spacing: 8) {
			BulbMark(color: previewColor(light), isOn: light.isOn, size: 56)
			Text(light.isOn ? statusLine(light) : "Off")
				.font(Typography.mono(12))
				.foregroundStyle(bp.ink60)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 8)
		.background(bp.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
	}

	private func previewColor(_ light: LightState) -> Color? {
		guard light.isOn else { return nil }
		if light.isOnOffOnly { return nil }
		return mode == .color ? color : Color.fromKelvin(Int(kelvin))
	}

	private func statusLine(_ light: LightState) -> String {
		var parts = ["\(Int(brightness))%"]
		if mode == .white, light.supportsColorTemp { parts.append("\(Int(kelvin))K") }
		return parts.joined(separator: " · ")
	}

	// MARK: Controls

	private func onOffControls(_ light: LightState) -> some View {
		Button {
			Task { await vm.toggle(light) }
		} label: {
			Label(light.isOn ? "Turn Off" : "Turn On", systemImage: "power")
				.font(Typography.text(15, weight: .semibold))
				.frame(maxWidth: .infinity, minHeight: 44)
		}
		.tint(bp.sax)
		.buttonStyle(.borderedProminent)
	}

	private func controls(_ light: LightState) -> some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack {
				Text("Power").font(Typography.text(14, weight: .semibold)).foregroundStyle(bp.ink)
				Spacer()
				Toggle("", isOn: Binding(get: { light.isOn }, set: { _ in Task { await vm.toggle(light) } }))
					.labelsHidden().tint(bp.sax)
			}

			if light.supportsBrightness {
				// Applies on release (a natural debounce — one HA call per drag).
				labeledSlider("Brightness", value: $brightness, range: 0...100, unit: "%") {
					Task { await applyEditor(to: light) }
				}
			}

			if light.supportsColor && light.supportsColorTemp {
				Picker("Mode", selection: $mode) {
					ForEach(ColorMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
				}
				.pickerStyle(.segmented)
			}

			if light.supportsColorTemp && (mode == .white || !light.supportsColor) {
				labeledSlider("Temperature", value: $kelvin,
				              range: Double(light.minKelvin ?? 2000)...Double(light.maxKelvin ?? 6500), unit: "K") {
					Task { await applyEditor(to: light) }
				}
			}

			if light.supportsColor && (mode == .color || !light.supportsColorTemp) {
				ColorPicker("Color", selection: $color, supportsOpacity: false)
					.font(Typography.text(14, weight: .semibold))
					.onChange(of: color) { _, _ in debouncedColorApply(to: light) }
			}

			Button {
				Task { await applyEditor(to: light) }
			} label: {
				Text("Apply to \(light.name)")
					.font(Typography.text(15, weight: .semibold))
					.frame(maxWidth: .infinity, minHeight: 44)
			}
			.tint(bp.sax)
			.buttonStyle(.borderedProminent)
		}
		.padding(14)
		.background(bp.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
	}

	private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String,
	                           onCommit: @escaping () -> Void) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(title).font(Typography.text(14, weight: .semibold)).foregroundStyle(bp.ink)
				Spacer()
				Text("\(Int(value.wrappedValue))\(unit)").font(Typography.mono(12)).foregroundStyle(bp.ink60)
			}
			Slider(value: value, in: range, onEditingChanged: { editing in
				if !editing { onCommit() }   // fire once, on release
			}).tint(bp.crease)
		}
	}

	// MARK: Preset library

	private func presetLibrary(_ light: LightState) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Presets").font(Typography.text(14, weight: .semibold)).foregroundStyle(bp.ink)

			ForEach(presets) { preset in
				HStack(spacing: 10) {
					Circle().fill(preset.swatch).frame(width: 22, height: 22)
						.overlay(Circle().stroke(bp.ink.opacity(0.25), lineWidth: 0.5))
					Text(preset.name).font(Typography.text(14)).foregroundStyle(bp.ink)
					Spacer()
					Button("Apply") { Task { await vm.apply(preset, to: light) } }
						.font(Typography.text(13, weight: .semibold)).tint(bp.crease)
					Button(role: .destructive) {
						presets = PresetStore.shared.remove(id: preset.id)
						WidgetReload.requestAll()
					} label: { Image(systemName: "trash") }
						.tint(bp.crane)
				}
			}

			HStack(spacing: 8) {
				TextField("New preset name", text: $presetName)
					.textFieldStyle(.roundedBorder)
				Button("Save") { saveCurrentAsPreset() }
					.font(Typography.text(13, weight: .semibold))
					.tint(bp.sax)
					.disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
			}
		}
		.padding(14)
		.background(bp.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
	}

	private var emptyState: some View {
		VStack(spacing: 10) {
			BulbMark(color: nil, isOn: false, size: 44)
			Text(vm.state == .loading ? "Loading lights…" : "No lights found")
				.font(Typography.text(14)).foregroundStyle(bp.ink60)
			if case .failed(let msg) = vm.state {
				Text(msg).font(Typography.text(12)).foregroundStyle(bp.crane).multilineTextAlignment(.center)
			}
		}
		.padding(.top, 40)
	}

	// MARK: Sync + apply

	private func syncFromLight() {
		guard let light else { return }
		brightness = Double(light.brightnessPct ?? 100)
		if let k = light.colorTempKelvin { kelvin = Double(k) }
		else { kelvin = Double(light.minKelvin ?? 2700) }
		if let rgb = light.rgb { color = rgb.color; mode = .color }
		else if light.supportsColorTemp { mode = .white }
		else if light.supportsColor { mode = .color }
	}

	/// Debounce rapid ColorPicker changes into one HA call (~350ms after the last).
	private func debouncedColorApply(to light: LightState) {
		colorDebounce?.cancel()
		colorDebounce = Task {
			try? await Task.sleep(for: .milliseconds(350))
			if Task.isCancelled { return }
			if mode != .color { mode = .color }
			await applyEditor(to: light)
		}
	}

	private func applyEditor(to light: LightState) async {
		if mode == .color && light.supportsColor {
			await vm.turnOnColor(rgb(from: color), brightness: Int(brightness), on: light)
		} else if light.supportsColorTemp {
			await vm.turnOnKelvin(Int(kelvin), brightness: Int(brightness), on: light)
		} else {
			await vm.setBrightness(Int(brightness), on: light)
		}
	}

	private func saveCurrentAsPreset() {
		let name = presetName.trimmingCharacters(in: .whitespaces)
		guard !name.isEmpty else { return }
		let preset: LightPreset
		if mode == .color {
			preset = LightPreset(name: name, rgb: rgb(from: color), brightnessPct: Int(brightness))
		} else {
			preset = LightPreset(name: name, kelvin: Int(kelvin), brightnessPct: Int(brightness))
		}
		presets = PresetStore.shared.add(preset)
		presetName = ""
		WidgetReload.requestAll()
	}

	/// Cross-platform Color → sRGB triple.
	private func rgb(from color: Color) -> LightRGB {
		#if canImport(UIKit)
		var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
		UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
		return LightRGB(r: Int(r * 255), g: Int(g * 255), b: Int(b * 255))
		#elseif canImport(AppKit)
		let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
		return LightRGB(r: Int(ns.redComponent * 255), g: Int(ns.greenComponent * 255), b: Int(ns.blueComponent * 255))
		#else
		return LightRGB(r: 255, g: 255, b: 255)
		#endif
	}
}
