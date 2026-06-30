import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Nudges WidgetKit to refresh timelines — called by the app/intents after they
/// cache fresh light state, so widgets pick up changes promptly (still subject to
/// the system's widget refresh budget).
public enum WidgetReload {
	public static func requestAll() {
		#if canImport(WidgetKit)
		WidgetCenter.shared.reloadAllTimelines()
		#endif
	}
}
