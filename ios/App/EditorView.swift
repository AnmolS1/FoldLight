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
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Bindable var vm: LightsViewModel
	@Bindable var settings: AppSettings

	@State private var selectedID: String?
	@State private var brightness: Double = 100
	@State private var kelvin: Double = 3000
	@State private var color: Color = .orange
	// HSB decomposition of `color`, driving the net-new adjustable color rows so
	// hue/saturation/brightness are reachable (and spoken) without the graphical
	// ColorPicker. Kept in sync with `color` both ways.
	@State private var hue: Double = 0.08
	@State private var sat: Double = 0.7
	@State private var bri: Double = 1.0
	@State private var mode: ColorMode = .white
	@State private var presetName = ""
	@State private var presets: [LightPreset] = []
	@State private var colorDebounce: Task<Void, Never>?

	enum ColorMode: String, CaseIterable { case white = "White", color = "Color" }

	private var light: LightState? {
		if let selectedID, let l = vm.light(withID: selectedID) { return l }
		// Default to the configured main light (Settings → Lights), matching the
		// widget/controls; fall back to the first color-capable light.
		if let chosen = LightPrefsStore.shared.load().mainLightID,
		   let l = vm.light(withID: chosen) {
			return l
		}
		return vm.lights.first(where: { $0.supportsColor || $0.supportsColorTemp }) ?? vm.lights.first
	}

	var body: some View {
		ScrollViewReader { proxy in
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
								presetLibrary(light).id("presetsAnchor")
							}
						}
					}
				}
				.padding(16)
				.iPadColumn()
			}
			.task(id: light?.entityID) { syncFromLight() }
			.onAppear { presets = PresetStore.shared.load() }
			// Screenshot capture: `--screen presets` opens the editor scrolled to the
			// preset library. Wait a beat for mock lights to load and lay out first.
			.task {
				guard ScreenshotSupport.isActive, ScreenshotSupport.screen == .presets else { return }
				try? await Task.sleep(for: .milliseconds(900))
				// Honor Reduce Motion: jump without the scroll animation.
				withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo("presetsAnchor", anchor: .top) }
			}
		}
	}

	// MARK: Status banner

	@ViewBuilder private var statusBanner: some View {
		if settings.useMockData && !ScreenshotSupport.isActive {
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
		.background(bp.card.opacity(reduceTransparency ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 12))
		// One element that speaks the whole current state, ignoring the bulb's own
		// "Light on" label and the mono status text.
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(light.name)
		.accessibilityValue(previewA11yValue(light))
	}

	/// Spoken state for the preview: "On, 60 percent, warm white" / "On, 60 percent,
	/// crane orange" / "Off".
	private func previewA11yValue(_ light: LightState) -> String {
		guard light.isOn else { return "Off" }
		var parts = ["On", A11yValue.brightness(Int(brightness))]
		if light.isOnOffOnly { return parts.joined(separator: ", ") }
		if mode == .color, light.supportsColor {
			parts.append(A11yColorName.name(hue: hue, saturation: sat, brightness: bri))
		} else if light.supportsColorTemp {
			parts.append(A11yValue.warmthWord(Int(kelvin)))
		}
		return parts.joined(separator: ", ")
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
		.accessibilityValue(light.isOn ? "On" : "Off")
		.accessibilityHint("Double-tap to turn \(light.isOn ? "off" : "on")")
		#if os(macOS)
		.help(light.isOn ? "Turn \(light.name) off" : "Turn \(light.name) on")
		#endif
	}

	private func controls(_ light: LightState) -> some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack {
				Text("Power").font(Typography.text(14, weight: .semibold)).foregroundStyle(bp.ink)
				Spacer()
				Toggle("", isOn: Binding(get: { light.isOn }, set: { _ in Task { await vm.toggle(light) } }))
					.labelsHidden().tint(bp.sax)
					.accessibilityLabel("Power")
					.accessibilityValue(light.isOn ? "On" : "Off")
					#if os(macOS)
					.help(light.isOn ? "Turn \(light.name) off" : "Turn \(light.name) on")
					#endif
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
					.onChange(of: color) { _, _ in loadHSB(from: color); debouncedColorApply(to: light) }
					#if os(macOS)
					.help("Pick a color for \(light.name)")
					#endif
				// Net-new: the same color reachable (and spoken) as three adjustable
				// rows, each announcing the nearest named color as you swipe.
				colorComponentRows(light)
			}
		}
		.padding(14)
		.background(bp.card.opacity(reduceTransparency ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 12))
	}

	// MARK: Adjustable color (HSB) rows — net-new, non-graphical color control

	@ViewBuilder private func colorComponentRows(_ light: LightState) -> some View {
		let colorName = A11yColorName.name(hue: hue, saturation: sat, brightness: bri)
		VStack(alignment: .leading, spacing: 10) {
			hsbRow("Hue", value: $hue, spoken: colorName, light: light)
			hsbRow("Saturation", value: $sat, spoken: "\(Int(sat * 100)) percent, \(colorName)", light: light)
			hsbRow("Color brightness", value: $bri, spoken: "\(Int(bri * 100)) percent, \(colorName)", light: light)
		}
	}

	/// One adjustable HSB row (value 0…1). VoiceOver swipes step it and speak the
	/// nearest named color; releasing a drag applies to the bulb.
	private func hsbRow(_ title: String, value: Binding<Double>, spoken: String, light: LightState) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(title).font(Typography.text(13, weight: .semibold)).foregroundStyle(bp.ink)
				Spacer()
				Text(title == "Hue" ? A11yColorName.name(hue: hue, saturation: sat, brightness: bri)
				                    : "\(Int(value.wrappedValue * 100))%")
					.font(Typography.mono(11)).foregroundStyle(bp.ink60)
			}
			Slider(value: value, in: 0...1, onEditingChanged: { editing in
				if !editing { syncColorFromHSB(); debouncedColorApply(to: light) }
			}).tint(bp.crease)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(title)
		.accessibilityValue(spoken)
		.accessibilityAdjustableAction { direction in
			let v = value.wrappedValue
			switch direction {
			case .increment: value.wrappedValue = min(1, v + 0.05)
			case .decrement: value.wrappedValue = max(0, v - 0.05)
			@unknown default: break
			}
			syncColorFromHSB()
			debouncedColorApply(to: light)
		}
	}

	/// Rebuild `color` from the HSB rows (source of truth while adjusting them).
	private func syncColorFromHSB() {
		color = Color(hue: hue, saturation: sat, brightness: bri)
	}

	/// Decompose a Color into the HSB rows. Preserves the current hue when the
	/// color is (near-)gray, where hue is otherwise undefined.
	private func loadHSB(from c: Color) {
		let triple = rgb(from: c)
		let (h, s, v) = A11yColorName.hsb(r: triple.r, g: triple.g, b: triple.b)
		if s > 0.02 { hue = h }
		sat = s
		bri = v
	}

	private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String,
	                           onCommit: @escaping () -> Void) -> some View {
		// Step a VoiceOver adjust by ~5% of the range (whole Kelvin / percent).
		let step = max(1, (range.upperBound - range.lowerBound) / 20).rounded()
		return VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(title).font(Typography.text(14, weight: .semibold)).foregroundStyle(bp.ink)
				Spacer()
				Text("\(Int(value.wrappedValue))\(unit)").font(Typography.mono(12)).foregroundStyle(bp.ink60)
			}
			Slider(value: value, in: range, onEditingChanged: { editing in
				if !editing { onCommit() }   // fire once, on release
			}).tint(bp.crease)
		}
		// Combine label + slider into one node with a spoken value, and make the
		// whole node adjustable so a VoiceOver swipe steps it and speaks the result.
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(title)
		.accessibilityValue(unit == "K" ? A11yValue.temperature(Int(value.wrappedValue))
		                                 : A11yValue.brightness(Int(value.wrappedValue)))
		.accessibilityAdjustableAction { direction in
			let v = value.wrappedValue
			switch direction {
			case .increment: value.wrappedValue = min(range.upperBound, v + step)
			case .decrement: value.wrappedValue = max(range.lowerBound, v - step)
			@unknown default: break
			}
			onCommit()
		}
	}

	// MARK: Preset library

	private func presetLibrary(_ light: LightState) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Presets").font(Typography.text(14, weight: .semibold)).foregroundStyle(bp.ink)

			ForEach(presets) { preset in
				let active = isActivePreset(preset)
				HStack(spacing: 10) {
					// Selected state is shown with a ring + checkmark, never tint alone.
					ZStack {
						Circle().fill(preset.swatch).frame(width: 22, height: 22)
							.overlay(Circle().stroke(active ? bp.ink : bp.ink.opacity(0.25),
							                         lineWidth: active ? 2 : 0.5))
						if active {
							Image(systemName: "checkmark")
								.font(.system(size: 10, weight: .bold))
								.foregroundStyle(bp.ink)
						}
					}
					.accessibilityHidden(true)
					Text(preset.name).font(Typography.text(14)).foregroundStyle(bp.ink)
						.accessibilityHidden(true)
					Spacer()
					Button("Apply") {
						// Mirror the preset into the editor's local controls so the bulb
						// preview + sliders update immediately. Without this the preview
						// (driven by @State) only re-syncs when the *selected light*
						// changes, so applying a preset moved the real bulb but not the UI.
						syncEditor(from: preset)
						Task { await vm.apply(preset, to: light) }
					}
						.font(Typography.text(13, weight: .semibold)).tint(bp.crease)
						.accessibilityLabel("Apply \(preset.name)")
						.accessibilityValue(presetSpoken(preset) + (active ? ", selected" : ""))
						.accessibilityHint("Double-tap to apply this preset")
						.accessibilityAddTraits(active ? .isSelected : [])
						#if os(macOS)
						.help("Apply \(preset.name): \(presetSpoken(preset))")
						#endif
					Button(role: .destructive) {
						presets = PresetStore.shared.remove(id: preset.id)
						WidgetReload.requestAll()
					} label: { Image(systemName: "trash") }
						.tint(bp.crane)
						.accessibilityLabel("Delete \(preset.name)")
						#if os(macOS)
						.help("Delete \(preset.name)")
						#endif
				}
			}

			HStack(spacing: 8) {
				TextField("New preset name", text: $presetName)
					.textFieldStyle(.roundedBorder)
				Button("Save") { saveCurrentAsPreset() }
					.font(Typography.text(13, weight: .semibold))
					.tint(bp.sax)
					.disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
					.accessibilityHint("Saves the current color and brightness as a preset")
			}
		}
		.padding(14)
		.background(bp.card.opacity(reduceTransparency ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 12))
	}

	private var emptyState: some View {
		VStack(spacing: 10) {
			BulbMark(color: nil, isOn: false, size: 44)
			Text(vm.state == .loading ? "Loading lights…" : "No lights found")
				.font(Typography.text(14)).foregroundStyle(bp.ink60)
			if case .failed(let msg) = vm.state {
				// Message in `ink` (not `crane`) so 12pt text clears WCAG AA; the off
				// bulb above already signals the error state without relying on color.
				Text(msg).font(Typography.text(12)).foregroundStyle(bp.ink).multilineTextAlignment(.center)
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
		if let rgb = light.rgb { color = rgb.color; loadHSB(from: color); mode = .color }
		else if light.supportsColorTemp { mode = .white }
		else if light.supportsColor { mode = .color }
		// Screenshot capture: the "presets" shot opens the same bulb in White mode so
		// it reads distinctly from the Color-mode editor shot (which all fits on one
		// Pro Max screen), while still showing the preset library.
		if ScreenshotSupport.isActive, ScreenshotSupport.screen == .presets, light.supportsColorTemp {
			mode = .white
		}
	}

	/// Mirror a preset into the editor's local controls (bulb preview + sliders read
	/// this @State). Matches the shape of `syncFromLight()` / `saveCurrentAsPreset()`.
	private func syncEditor(from preset: LightPreset) {
		brightness = Double(preset.brightnessPct)
		if let rgb = preset.rgb {
			color = rgb.color
			loadHSB(from: color)
			mode = .color
		} else if let k = preset.kelvin {
			kelvin = Double(k)
			mode = .white
		}
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

	/// Whether a preset matches the editor's current dialed-in state (drives the
	/// selected ring + checkmark and the VoiceOver "selected" trait).
	private func isActivePreset(_ p: LightPreset) -> Bool {
		guard Int(brightness) == p.brightnessPct else { return false }
		if let k = p.kelvin { return mode == .white && Int(kelvin) == k }
		if let rgb = p.rgb { return mode == .color && rgb == self.rgb(from: color) }
		return false
	}

	/// Spoken description of a preset's color + brightness, e.g. "crane orange, 60
	/// percent" or "warm white, 100 percent".
	private func presetSpoken(_ p: LightPreset) -> String {
		var parts: [String] = []
		if let rgb = p.rgb { parts.append(A11yColorName.name(r: rgb.r, g: rgb.g, b: rgb.b)) }
		else if let k = p.kelvin { parts.append(A11yValue.warmthWord(k)) }
		parts.append(A11yValue.brightness(p.brightnessPct))
		return parts.joined(separator: ", ")
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
