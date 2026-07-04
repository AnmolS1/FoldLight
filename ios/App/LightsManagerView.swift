import SwiftUI
import FoldKit

/// Settings → "Lights": every auto-detected light with capability chips and
/// on/off state; pick the main light, reorder favorites, and rename. Persists
/// to the App Group (`LightPrefsStore`) so the editor, widgets, and Control
/// Center all follow.
struct LightsManagerView: View {
	@Environment(\.blueprint) private var bp
	@Bindable var settings: AppSettings

	enum LoadState {
		case loading
		case failed(String)
		case loaded([LightState])
	}

	@State private var state: LoadState = .loading
	@State private var prefs = LightPrefsStore.shared.load()
	@State private var renameTarget: LightState?
	@State private var renameText = ""

	var body: some View {
		Group {
			switch state {
			case .loading:
				VStack(spacing: 10) {
					ProgressView().tint(bp.crease)
					Text("Detecting lights…")
						.font(Typography.text(13))
						.foregroundStyle(bp.ink60)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .failed(let message):
				VStack(spacing: 12) {
					Image(systemName: "exclamationmark.triangle")
						.font(.title)
						.foregroundStyle(bp.crane)
					Text(message)
						.font(Typography.text(13))
						.foregroundStyle(bp.ink60)
						.multilineTextAlignment(.center)
					Button("Retry") { Task { await load() } }
						.buttonStyle(.borderedProminent)
						.tint(bp.crease)
				}
				.padding(32)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let lights) where lights.isEmpty:
				VStack(spacing: 8) {
					Image(systemName: "lightbulb.slash")
						.font(.system(size: 28, weight: .semibold))
						.foregroundStyle(bp.ink60)
					Text("No lights detected")
						.font(Typography.text(15, weight: .semibold))
						.foregroundStyle(bp.ink)
					Text("Connect to Home Assistant in Settings — every light.* entity appears here automatically.")
						.font(Typography.text(13))
						.foregroundStyle(bp.ink60)
						.multilineTextAlignment(.center)
				}
				.padding(24)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let lights):
				list(prefs.arrange(lights))
			}
		}
		.background(GraphPaperBackground())
		.navigationTitle("Lights")
		.task { await load() }
		.alert("Rename light", isPresented: Binding(
			get: { renameTarget != nil },
			set: { if !$0 { renameTarget = nil } }
		)) {
			TextField("Display name", text: $renameText)
			Button("Save") {
				if let target = renameTarget {
					var updated = prefs
					let trimmed = renameText.trimmingCharacters(in: .whitespaces)
					updated.renames[target.entityID] = trimmed.isEmpty ? nil : trimmed
					apply(updated)
				}
				renameTarget = nil
			}
			Button("Cancel", role: .cancel) { renameTarget = nil }
		}
	}

	private func list(_ lights: [LightState]) -> some View {
		List {
			Section {
				ForEach(lights, id: \.entityID) { light in
					row(light)
						.listRowBackground(bp.card)
				}
				.onMove { from, to in
					var ids = lights.map(\.entityID)
					ids.move(fromOffsets: from, toOffset: to)
					var updated = prefs
					updated.favoriteIDs = ids
					apply(updated)
				}
			} header: {
				Text("Detected lights".uppercased())
					.font(Typography.text(12, weight: .semibold))
					.foregroundStyle(bp.ink60)
			} footer: {
				Text("Drag to reorder. Long-press a light to make it the main light (the one widgets and Control Center target by default) or to rename it.")
					.font(Typography.text(12))
					.foregroundStyle(bp.ink60)
			}
		}
		.scrollContentBackground(.hidden)
		#if os(iOS)
		.environment(\.editMode, .constant(.active))
		#endif
	}

	private func row(_ light: LightState) -> some View {
		let isMain = effectiveMainID == light.entityID
		return VStack(alignment: .leading, spacing: 3) {
			HStack(spacing: 6) {
				Circle()
					.fill(light.isOn ? bp.sax : bp.ink60.opacity(0.4))
					.frame(width: 7, height: 7)
				Text(prefs.displayName(for: light))
					.font(Typography.text(15, weight: .semibold))
					.foregroundStyle(bp.ink)
					.lineLimit(1)
				if isMain {
					Text("MAIN")
						.font(Typography.mono(9, weight: .semibold))
						.foregroundStyle(bp.sax)
						.padding(.horizontal, 5)
						.padding(.vertical, 1)
						.background(bp.sax.opacity(0.14), in: Capsule())
				}
				Spacer(minLength: 0)
			}
			HStack(spacing: 5) {
				capabilityChip(light.isOnOffOnly ? "on/off" : "dim")
				if light.supportsColorTemp { capabilityChip("temp") }
				if light.supportsColor { capabilityChip("color") }
				Text(light.entityID)
					.font(Typography.mono(10))
					.foregroundStyle(bp.ink60)
					.lineLimit(1)
					.truncationMode(.middle)
			}
		}
		.contentShape(Rectangle())
		.contextMenu {
			Button {
				var updated = prefs
				updated.mainLightID = light.entityID
				apply(updated)
			} label: {
				Label(isMain ? "Main light ✓" : "Make main light", systemImage: "star")
			}
			.disabled(isMain)
			Button {
				renameText = prefs.displayName(for: light)
				renameTarget = light
			} label: {
				Label("Rename…", systemImage: "pencil")
			}
		}
	}

	private func capabilityChip(_ label: String) -> some View {
		Text(label.uppercased())
			.font(Typography.mono(9, weight: .semibold))
			.foregroundStyle(bp.crease)
			.padding(.horizontal, 5)
			.padding(.vertical, 1)
			.background(bp.crease.opacity(0.12), in: Capsule())
	}

	/// The main light the system would actually use right now.
	private var effectiveMainID: String? {
		if case .loaded(let lights) = state, !lights.isEmpty {
			if let chosen = prefs.mainLightID, lights.contains(where: { $0.entityID == chosen }) {
				return chosen
			}
			return (lights.first(where: { $0.supportsColor || $0.supportsColorTemp }) ?? lights.first)?.entityID
		}
		return prefs.mainLightID
	}

	private func apply(_ updated: LightPrefs) {
		prefs = updated
		LightPrefsStore.shared.save(updated)
		WidgetReload.requestAll()
	}

	private func load() async {
		state = .loading
		do {
			let lights = try await settings.makeProvider().lights()
			LightCache.shared.write(lights)
			state = .loaded(lights)
		} catch {
			state = .failed(error.localizedDescription)
		}
	}
}
