import SwiftUI
import FoldKit

/// Settings → "Launchers": add/edit/remove the web-UI tiles shown in the Panel
/// tab and the Launcher widget. Ships empty; a quick-add offers a Home
/// Assistant tile derived from the configured base URL.
struct LaunchersManagerView: View {
	@Environment(\.blueprint) private var bp
	@Bindable var settings: AppSettings

	@State private var targets: [LauncherTarget] = LauncherStore.shared.load()
	@State private var editing: LauncherTarget?
	@State private var isAddingNew = false

	private static let symbolChoices = [
		"house.fill", "printer.fill", "server.rack", "network", "camera.fill",
		"tv.fill", "music.note", "photo.fill", "externaldrive.fill", "gauge",
		"shield.fill", "arrow.down.circle.fill", "globe", "terminal.fill",
	]

	var body: some View {
		List {
			Section {
				if targets.isEmpty {
					Text("No launchers yet. Add tiles that open your services' web UIs.")
						.font(Typography.text(13))
						.foregroundStyle(bp.ink60)
						.listRowBackground(bp.card)
				}
				ForEach(targets) { target in
					Button {
						editing = target
					} label: {
						HStack(spacing: 12) {
							Image(systemName: target.symbol)
								.font(.system(size: 16, weight: .semibold))
								.foregroundStyle(bp.crease)
								.frame(width: 26)
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
							Image(systemName: "pencil")
								.font(.system(size: 12, weight: .semibold))
								.foregroundStyle(bp.ink60)
						}
					}
					.buttonStyle(.plain)
					.listRowBackground(bp.card)
				}
				.onDelete { offsets in
					targets.remove(atOffsets: offsets)
					persist()
				}
				.onMove { from, to in
					targets.move(fromOffsets: from, toOffset: to)
					persist()
				}
			} footer: {
				Text("Tiles appear in the Panel tab and the Launcher widget. Swipe to delete, drag to reorder.")
					.font(Typography.text(12))
					.foregroundStyle(bp.ink60)
			}

			Section {
				Button {
					isAddingNew = true
					editing = LauncherTarget(id: UUID().uuidString, name: "", urlString: "https://", symbol: "globe")
				} label: {
					Label("Add launcher", systemImage: "plus.circle.fill")
						.font(Typography.text(15, weight: .semibold))
						.foregroundStyle(bp.crease)
				}
				.buttonStyle(.plain)
				.listRowBackground(bp.card)

				if targets.first(where: { $0.id == "ha" }) == nil,
				   let ha = LauncherStore.homeAssistantTarget(baseURLString: settings.baseURLString) {
					Button {
						targets.append(ha)
						persist()
					} label: {
						Label("Add Home Assistant (\(settings.baseURLString))", systemImage: "house.fill")
							.font(Typography.text(14))
							.foregroundStyle(bp.crease)
							.lineLimit(1)
							.truncationMode(.middle)
					}
					.buttonStyle(.plain)
					.listRowBackground(bp.card)
				}
			}
		}
		.scrollContentBackground(.hidden)
		.background(GraphPaperBackground())
		.navigationTitle("Launchers")
		.sheet(item: $editing) { target in
			LauncherEditSheet(
				target: target,
				symbolChoices: Self.symbolChoices,
				onSave: { updated in
					if let i = targets.firstIndex(where: { $0.id == updated.id }) {
						targets[i] = updated
					} else {
						targets.append(updated)
					}
					persist()
					isAddingNew = false
				},
				onCancel: { isAddingNew = false }
			)
			.environment(\.blueprint, bp)
		}
	}

	private func persist() {
		LauncherStore.shared.save(targets)
		WidgetReload.requestAll()
	}
}

/// Blueprint edit sheet for one launcher tile: name, URL, and SF Symbol.
private struct LauncherEditSheet: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.dismiss) private var dismiss

	@State var target: LauncherTarget
	let symbolChoices: [String]
	let onSave: (LauncherTarget) -> Void
	let onCancel: () -> Void

	private var isValid: Bool {
		!target.name.trimmingCharacters(in: .whitespaces).isEmpty && target.url != nil
			&& !target.urlString.trimmingCharacters(in: .whitespaces).isEmpty
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				BlueprintFormSection("Launcher") {
					BlueprintField("Name", text: $target.name, prompt: "Jellyfin")
					BlueprintField("URL", text: $target.urlString, kind: .mono,
					               prompt: "https://jellyfin.example.com", isURL: true)
				}

				BlueprintFormSection("Icon") {
					LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
						ForEach(symbolChoices, id: \.self) { symbol in
							Button {
								target.symbol = symbol
							} label: {
								Image(systemName: symbol)
									.font(.system(size: 16, weight: .semibold))
									.foregroundStyle(target.symbol == symbol ? bp.graph : bp.crease)
									.frame(width: 36, height: 36)
									.background(
										target.symbol == symbol ? bp.crease : bp.graph,
										in: RoundedRectangle(cornerRadius: 8)
									)
									.overlay(RoundedRectangle(cornerRadius: 8).stroke(bp.creaseLine, lineWidth: 0.5))
							}
							.buttonStyle(.plain)
						}
					}
				}

				HStack(spacing: 12) {
					Button("Cancel") {
						onCancel()
						dismiss()
					}
					.buttonStyle(.bordered)
					.tint(bp.ink60)
					Button("Save") {
						onSave(target)
						dismiss()
					}
					.buttonStyle(.borderedProminent)
					.tint(bp.crease)
					.disabled(!isValid)
				}
				.frame(maxWidth: .infinity, alignment: .trailing)
			}
			.padding(20)
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
		.background(GraphPaperBackground().ignoresSafeArea())
	}
}
