import WidgetKit
import SwiftUI

/// Widget bundle entry point: the interactive light widget, the launcher panel,
/// and (iOS 18+) the Control Center controls.
@main
struct FoldLightWidgetBundle: WidgetBundle {
	var body: some Widget {
		LightWidget()
		LauncherWidget()
		#if os(iOS)
		if #available(iOS 18.0, *) {
			MainLightToggleControl()
			ApplyPresetControl()
			OpenLauncherControl()
		}
		#endif
	}
}
