import SwiftUI

/// Faint graph-paper grid over the graph-colored ground.
public struct GraphPaperBackground: View {
	@Environment(\.blueprint) private var bp
	var spacing: CGFloat

	public init(spacing: CGFloat = 22) { self.spacing = spacing }

	public var body: some View {
		bp.graph.overlay {
			Canvas { ctx, size in
				var path = Path()
				var x: CGFloat = 0
				while x <= size.width {
					path.move(to: CGPoint(x: x, y: 0))
					path.addLine(to: CGPoint(x: x, y: size.height))
					x += spacing
				}
				var y: CGFloat = 0
				while y <= size.height {
					path.move(to: CGPoint(x: 0, y: y))
					path.addLine(to: CGPoint(x: size.width, y: y))
					y += spacing
				}
				ctx.stroke(path, with: .color(bp.creaseLine), lineWidth: 0.5)
			}
		}
		.ignoresSafeArea()
	}
}

/// A small folded-corner tick for the top-trailing corner of a card.
public struct FoldedCorner: View {
	@Environment(\.blueprint) private var bp
	var size: CGFloat

	public init(size: CGFloat = 9) { self.size = size }

	public var body: some View {
		Path { p in
			p.move(to: CGPoint(x: size, y: 0))
			p.addLine(to: CGPoint(x: size, y: size))
			p.addLine(to: CGPoint(x: 0, y: 0))
			p.closeSubpath()
		}
		.fill(bp.creaseLine)
		.frame(width: size, height: size)
	}
}

/// The FoldLight brand/state mark: a bulb that renders in the live chosen color
/// with a soft halo when lit; a crease-blue outline when off. Used in widgets and
/// the in-app preview. Pure SF Symbols + a radial glow so it scales everywhere.
public struct BulbMark: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.accessibilityDifferentiateWithoutColor) private var diffWithoutColor
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	/// The light's current color when on (nil → use the theme accent).
	var color: Color?
	var isOn: Bool
	var size: CGFloat

	public init(color: Color?, isOn: Bool, size: CGFloat = 44) {
		self.color = color
		self.isOn = isOn
		self.size = size
	}

	/// The glyph must differ in *shape*, not just glow/color, so
	/// Differentiate-Without-Color users can read on vs off: filled bulb vs a
	/// slashed bulb. (The default off glyph stays the plain outline to preserve
	/// the blueprint look when the setting is off.)
	private var symbol: String {
		if isOn { return "lightbulb.fill" }
		return diffWithoutColor ? "lightbulb.slash" : "lightbulb"
	}

	public var body: some View {
		let tint = color ?? bp.sax
		// Reduce-Transparency users get a solid glyph and no soft halo.
		let showHalo = isOn && !reduceTransparency
		ZStack {
			if showHalo {
				Circle()
					.fill(
						RadialGradient(
							colors: [tint.opacity(0.55), tint.opacity(0.0)],
							center: .center,
							startRadius: 0,
							endRadius: size * 0.95
						)
					)
					.frame(width: size * 1.9, height: size * 1.9)
			}
			Image(systemName: symbol)
				.font(.system(size: size, weight: .regular))
				.foregroundStyle(isOn ? tint : bp.crease)
				.shadow(color: showHalo ? tint.opacity(0.8) : .clear, radius: showHalo ? size * 0.22 : 0)
		}
		.frame(width: size * 1.9, height: size * 1.9)
		.accessibilityLabel(isOn ? "Light on" : "Light off")
	}
}
