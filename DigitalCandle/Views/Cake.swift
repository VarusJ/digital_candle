import SwiftUI

/// A drop of frosting running down the side: a narrow neck at the top and a rounded end.
struct DripShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let radius = width / 2
        let k: CGFloat = 0.5523
        let bulbY = rect.maxY - radius
        let neckY = rect.minY + (bulbY - rect.minY) * 0.55
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + width * 0.18, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - width * 0.18, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: bulbY),
            control1: CGPoint(x: rect.maxX - width * 0.2, y: neckY),
            control2: CGPoint(x: rect.maxX, y: bulbY - radius))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: bulbY + radius * k),
            control2: CGPoint(x: rect.midX + radius * k, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: bulbY),
            control1: CGPoint(x: rect.midX - radius * k, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: bulbY + radius * k))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.18, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: bulbY - radius),
            control2: CGPoint(x: rect.minX + width * 0.2, y: neckY))
        path.closeSubpath()
        return path
    }
}

/// A round birthday cake on a plate: cream sides, pink frosting dripping over the edge,
/// cream rosettes around the top and sprinkles.
///
/// The cake itself is `width` wide; the view is larger so the plate and the rosettes fit
/// (see `canvasSize(cakeWidth:)` and `cakeOrigin(cakeWidth:)`).
struct BirthdayCake: View, Animatable {
    /// Height of the top surface relative to the cake's width.
    static let topRatio: CGFloat = 0.3
    /// Height of the side relative to the cake's width.
    static let sideRatio: CGFloat = 0.36

    var width: CGFloat
    /// 0 in the dark, 1 when the candle burns.
    var glow: Double

    var animatableData: Double {
        get { glow }
        set { glow = newValue }
    }

    static func canvasSize(cakeWidth: CGFloat) -> CGSize {
        CGSize(width: cakeWidth * 1.3, height: cakeWidth * (topRatio + sideRatio + 0.32))
    }

    /// Top-left corner of the cake's outline inside the view.
    static func cakeOrigin(cakeWidth: CGFloat) -> CGPoint {
        CGPoint(x: cakeWidth * 0.15, y: cakeWidth * 0.1)
    }

    var body: some View {
        let size = Self.canvasSize(cakeWidth: width)
        Canvas { context, _ in
            draw(in: context)
        }
        .frame(width: size.width, height: size.height)
        .colorMultiply(Color(red: 0.55 + 0.45 * glow, green: 0.5 + 0.46 * glow, blue: 0.5 + 0.4 * glow))
        .allowsHitTesting(false)
    }

    private func draw(in context: GraphicsContext) {
        let topHeight = width * Self.topRatio
        let sideHeight = width * Self.sideRatio
        let origin = Self.cakeOrigin(cakeWidth: width)
        let outline = CGRect(x: origin.x, y: origin.y, width: width, height: topHeight + sideHeight)
        let topCenter = CGPoint(x: outline.midX, y: outline.minY + topHeight / 2)
        let bottomCenter = CGPoint(x: outline.midX, y: outline.maxY - topHeight / 2)
        let frostingDepth = width * 0.05
        let across = (start: CGPoint(x: outline.minX, y: 0), end: CGPoint(x: outline.maxX, y: 0))

        // Plate, and the cake's shadow on it.
        let plateSize = CGSize(width: width * 1.2, height: width * 0.36)
        let plateCenter = CGPoint(x: bottomCenter.x, y: bottomCenter.y + 6)
        context.fill(
            Path(ellipseIn: Self.rect(center: CGPoint(x: plateCenter.x, y: plateCenter.y + 5), size: plateSize)),
            with: .color(Color(red: 0.6, green: 0.6, blue: 0.64)))
        let plateRect = Self.rect(center: plateCenter, size: plateSize)
        context.fill(
            Path(ellipseIn: plateRect),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.82, green: 0.82, blue: 0.86), .white]),
                startPoint: CGPoint(x: 0, y: plateRect.minY), endPoint: CGPoint(x: 0, y: plateRect.maxY)))
        context.stroke(
            Path(ellipseIn: Self.rect(
                center: CGPoint(x: plateCenter.x, y: plateCenter.y - 1),
                size: CGSize(width: plateSize.width * 0.84, height: plateSize.height * 0.84))),
            with: .color(Color(red: 0.78, green: 0.78, blue: 0.82).opacity(0.8)),
            lineWidth: 1)
        var shadow = context
        shadow.addFilter(.blur(radius: 6))
        shadow.fill(
            Path(ellipseIn: Self.rect(
                center: CGPoint(x: bottomCenter.x, y: bottomCenter.y + 3),
                size: CGSize(width: width * 1.04, height: topHeight * 1.1))),
            with: .color(.black.opacity(0.35)))

        // Cream side with a row of piped beads along the bottom.
        context.fill(
            CylinderSide(capHeight: topHeight).path(in: outline),
            with: .linearGradient(Self.sideGradient, startPoint: across.start, endPoint: across.end))
        let beadRadius = width * 0.022
        for index in 0...18 {
            let x = width * (-0.46 + 0.92 * CGFloat(index) / 18)
            let center = CGPoint(
                x: bottomCenter.x + x,
                y: bottomCenter.y + topHeight / 2 * Self.rimDepth(x, width: width) - beadRadius * 0.9)
            Self.fillCream(context, center: center, size: CGSize(width: beadRadius * 2, height: beadRadius * 2))
        }

        // Frosting: its thickness at the edge, the drips, then the top.
        let frostingEdge = GraphicsContext.Shading.linearGradient(
            Self.frostingEdgeGradient, startPoint: across.start, endPoint: across.end)
        context.fill(
            Path(ellipseIn: Self.rect(
                center: CGPoint(x: topCenter.x, y: topCenter.y + frostingDepth),
                size: CGSize(width: width, height: topHeight))),
            with: frostingEdge)
        for drip in Self.drips {
            let x = drip.x * width
            let dripWidth = drip.width * width
            let rimY = topCenter.y + topHeight / 2 * Self.rimDepth(x, width: width) + frostingDepth
            let rect = CGRect(
                x: topCenter.x + x - dripWidth / 2, y: rimY - dripWidth * 0.8,
                width: dripWidth, height: sideHeight * drip.length)
            context.fill(DripShape().path(in: rect), with: frostingEdge)
        }
        let topRect = Self.rect(center: topCenter, size: CGSize(width: width, height: topHeight))
        context.fill(
            Path(ellipseIn: topRect),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.93, green: 0.56, blue: 0.67), Color(red: 1, green: 0.74, blue: 0.82)]),
                startPoint: CGPoint(x: 0, y: topRect.minY), endPoint: CGPoint(x: 0, y: topRect.maxY)))

        // Sprinkles on the top, leaving room for the candle in the middle.
        for index in 0..<46 {
            let angle = Self.noise(index, 1) * 2 * .pi
            let distance = Self.noise(index, 2).squareRoot()
            let point = CGPoint(
                x: topCenter.x + cos(angle) * distance * 0.4 * width,
                y: topCenter.y + sin(angle) * distance * 0.36 * topHeight)
            if abs(point.x - topCenter.x) < width * 0.11, abs(point.y - topCenter.y) < width * 0.065 {
                continue
            }
            let colorIndex = Int(Self.noise(index, 4) * CGFloat(Self.sprinkleColors.count)) % Self.sprinkleColors.count
            var sprinkle = context
            sprinkle.translateBy(x: point.x, y: point.y)
            sprinkle.scaleBy(x: 1, y: 0.55) // lying flat on the frosting
            sprinkle.rotate(by: .radians(Double(Self.noise(index, 3)) * .pi))
            sprinkle.fill(
                Path(roundedRect: CGRect(x: -1.2, y: -3.3, width: 2.4, height: 6.6), cornerRadius: 1.2),
                with: .color(Self.sprinkleColors[colorIndex]))
        }

        // Cream rosettes around the rim, drawn back to front.
        let rosetteRadius = width * 0.048
        let rosettes = (0..<12).map { index -> CGPoint in
            let angle = 2 * CGFloat.pi * CGFloat(index) / 12 + CGFloat.pi / 12
            return CGPoint(
                x: topCenter.x + (width / 2 - rosetteRadius * 0.9) * cos(angle),
                y: topCenter.y + (topHeight / 2 - rosetteRadius * 0.35) * sin(angle))
        }
        for center in rosettes.sorted(by: { $0.y < $1.y }) {
            Self.fillCream(context, center: center, size: CGSize(width: rosetteRadius * 2, height: rosetteRadius * 1.7))
            context.fill(
                Path(ellipseIn: Self.rect(
                    center: CGPoint(x: center.x - rosetteRadius * 0.15, y: center.y - rosetteRadius * 0.35),
                    size: CGSize(width: rosetteRadius * 0.9, height: rosetteRadius * 0.6))),
                with: .color(.white.opacity(0.7)))
        }
    }

    // MARK: - Helpers

    /// How far down from the middle of an ellipse its front edge is at `x` from the center (0...1).
    private static func rimDepth(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let t = 2 * x / width
        return max(0, 1 - t * t).squareRoot()
    }

    private static func rect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// A blob of whipped cream, lit from the top left.
    private static func fillCream(_ context: GraphicsContext, center: CGPoint, size: CGSize) {
        context.fill(
            Path(ellipseIn: rect(center: center, size: size)),
            with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.99, blue: 0.97), Color(red: 0.86, green: 0.8, blue: 0.74)]),
                center: CGPoint(x: center.x - size.width * 0.1, y: center.y - size.height * 0.15),
                startRadius: 0, endRadius: size.width * 0.65))
    }

    /// Repeatable pseudo-random numbers in 0..<1, so the sprinkles stay where they are.
    private static func noise(_ index: Int, _ channel: Int) -> CGFloat {
        let value = sin(Double(index) * 12.9898 + Double(channel) * 78.233) * 43758.5453
        return CGFloat(value - value.rounded(.down))
    }

    private static let sideGradient = Gradient(stops: [
        .init(color: Color(red: 0.80, green: 0.70, blue: 0.60), location: 0),
        .init(color: Color(red: 0.98, green: 0.92, blue: 0.83), location: 0.25),
        .init(color: Color(red: 1.00, green: 0.96, blue: 0.90), location: 0.42),
        .init(color: Color(red: 0.95, green: 0.87, blue: 0.77), location: 0.7),
        .init(color: Color(red: 0.74, green: 0.63, blue: 0.53), location: 1),
    ])

    private static let frostingEdgeGradient = Gradient(stops: [
        .init(color: Color(red: 0.80, green: 0.40, blue: 0.52), location: 0),
        .init(color: Color(red: 0.97, green: 0.60, blue: 0.70), location: 0.3),
        .init(color: Color(red: 1.00, green: 0.70, blue: 0.78), location: 0.45),
        .init(color: Color(red: 0.76, green: 0.36, blue: 0.48), location: 1),
    ])

    private static let sprinkleColors: [Color] = [
        Color(red: 1, green: 0.85, blue: 0.3),
        Color(red: 0.4, green: 0.75, blue: 1),
        Color(red: 0.55, green: 0.9, blue: 0.55),
        .white,
        Color(red: 1, green: 0.6, blue: 0.3),
        Color(red: 0.75, green: 0.55, blue: 1),
    ]

    /// Frosting drips along the front: position from the center and width (fractions of the
    /// cake's width), and length (fraction of the side's height).
    private static let drips: [(x: CGFloat, width: CGFloat, length: CGFloat)] = [
        (-0.42, 0.07, 0.22), (-0.3, 0.085, 0.4), (-0.16, 0.075, 0.28), (-0.03, 0.09, 0.48),
        (0.1, 0.08, 0.32), (0.23, 0.085, 0.44), (0.35, 0.075, 0.27), (0.45, 0.06, 0.18),
    ]
}
