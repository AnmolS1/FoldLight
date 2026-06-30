import Foundation

/// Anchor class used to resolve the FoldKit framework bundle at runtime, so the
/// app and the widget extension can both load bundled fonts and assets via the
/// framework bundle (not their own).
final class FoldKitBundleToken {}

/// Access to FoldKit's resource bundle (fonts, sample fixtures, brand mark).
public enum FoldKitResources {
	public static var bundle: Bundle { Bundle(for: FoldKitBundleToken.self) }
}
