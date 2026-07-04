import Foundation
import os

/// Records why a widget App Intent failed. The intents used to swallow every error
/// silently (`catch { … return .result() }`), so a blocked ATS request, a 401 from a
/// missing token, or an offline HA all looked identical: "the button does nothing."
///
/// Now each failure is (a) logged via `os.Logger` so it shows up in Console.app
/// filtered on the widget process, and (b) stashed in the App Group so the UI can
/// surface it. Success clears the record.
public enum IntentDiagnostics {
	public static let logger = Logger(subsystem: "dev.ponderance.foldlight", category: "widget-intent")

	private static let key = "lastIntentError"

	/// Log + persist a failure for `action` (e.g. "toggle", "brightness", "preset").
	public static func record(_ action: String, _ error: Error) {
		let message = "\(action): \((error as? LightError)?.errorDescription ?? error.localizedDescription)"
		logger.error("Widget intent failed — \(message, privacy: .public)")
		AppSettings.defaultStore().set(message, forKey: key)
	}

	/// Clear the record after a successful action.
	public static func clear() {
		AppSettings.defaultStore().removeObject(forKey: key)
	}

	/// The last recorded failure, if any (for the widget to display).
	public static func last() -> String? {
		AppSettings.defaultStore().string(forKey: key)
	}
}
