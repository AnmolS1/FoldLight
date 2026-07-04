import AppIntents
import FoldKit

/// Per-instance configuration for the light widget (long-press → Edit Widget):
/// which light it targets and which preset swatches it shows. Both parameters
/// are optional so widgets placed before the StaticConfiguration →
/// AppIntentConfiguration migration keep today's behavior (main light +
/// favorite presets).
public struct LightWidgetConfigurationIntent: WidgetConfigurationIntent {
	public static let title: LocalizedStringResource = "Light Options"
	public static let description = IntentDescription("Choose which light this widget controls and which preset swatches it shows.")

	@Parameter(title: "Light", description: "Empty targets your main light.")
	public var light: LightAppEntity?

	@Parameter(title: "Presets", description: "Empty shows your first few presets.")
	public var presets: [PresetAppEntity]?

	public init() {}
}
