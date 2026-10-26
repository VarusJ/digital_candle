import SwiftUI

/// The side of a cylinder seen slightly from above: straight sides and a rounded bottom edge.
/// The top edge runs across the middle of the cap, which is drawn on top of it.
struct CylinderSide: Shape {
    var capHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = capHeight / 2
        let k: CGFloat = 0.5523 // Bézier approximation of a quarter ellipse
        let halfWidth = rect.width / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.maxY - radius + radius * k),
            control2: CGPoint(x: rect.midX - halfWidth * k, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            control1: CGPoint(x: rect.midX + halfWidth * k, y: rect.maxY),
            control2: CGPoint(x: rect.maxX, y: rect.maxY - radius + radius * k))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radius))
        path.closeSubpath()
        return path
    }
}

/// Stripes winding around a cylinder, as seen from the front: each band rises by half a turn
/// from the left edge to the right edge, steeper at the sides where the surface turns away.
struct HelixStripes: Shape {
    /// Vertical distance covered by one full turn.
    var pitch: CGFloat
    /// Vertical thickness of each stripe.
    var thickness: CGFloat
    /// Shifts the stripes down, e.g. by half a pitch for a second colour.
    var offset: CGFloat

    func path(in rect: CGRect) -> Path {
        let steps = 16
        let halfWidth = rect.width / 2
        // Points along one edge of a stripe, left to right, for a stripe starting at `baseY`.
        func edge(_ baseY: CGFloat) -> [CGPoint] {
            (0...steps).map { step in
                let angle = -CGFloat.pi / 2 + CGFloat.pi * CGFloat(step) / CGFloat(steps)
                return CGPoint(x: rect.midX + halfWidth * sin(angle), y: baseY - angle / (2 * .pi) * pitch)
            }
        }
        var path = Path()
        var baseY = rect.minY - pitch + offset
        while baseY < rect.maxY + pitch {
            path.addLines(edge(baseY) + edge(baseY + thickness).reversed())
            path.closeSubpath()
            baseY += pitch
        }
        return path
    }
}

/// A thin birthday candle with pink and blue spiral stripes.
struct BirthdayCandle: View, Animatable {
    /// Height of the top surface relative to the candle's width.
    static let capRatio: CGFloat = 0.32

    var width: CGFloat
    var height: CGFloat
    /// 0 in the dark, 1 when lit by its own flame.
    var glow: Double

    var animatableData: Double {
        get { glow }
        set { glow = newValue }
    }

    var body: some View {
        let capHeight = width * Self.capRatio
        let pitch = width * 1.45
        ZStack(alignment: .top) {
            ZStack {
                Color(red: 0.99, green: 0.97, blue: 0.95)
                HelixStripes(pitch: pitch, thickness: pitch * 0.2, offset: 0)
                    .fill(Color(red: 1, green: 0.42, blue: 0.6))
                HelixStripes(pitch: pitch, thickness: pitch * 0.2, offset: pitch / 2)
                    .fill(Color(red: 0.36, green: 0.7, blue: 1))
                // Round shading, then warm light from the flame on the upper part.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.3), location: 0),
                        .init(color: .black.opacity(0), location: 0.3),
                        .init(color: .white.opacity(0.35), location: 0.4),
                        .init(color: .white.opacity(0), location: 0.55),
                        .init(color: .black.opacity(0.35), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing)
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1, green: 0.6, blue: 0.2).opacity(0.3 * glow), location: 0),
                        .init(color: .clear, location: 0.45),
                    ],
                    startPoint: .top, endPoint: .bottom)
            }
            .clipShape(CylinderSide(capHeight: capHeight))
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(red: 0.9, green: 0.86, blue: 0.84), .white],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: capHeight)
        }
        .frame(width: width, height: height, alignment: .top)
        // Where the candle goes into the frosting.
        .background(alignment: .bottom) {
            Ellipse()
                .fill(Color(red: 0.35, green: 0.08, blue: 0.16).opacity(0.35))
                .frame(width: width * 1.5, height: capHeight * 1.4)
                .offset(y: capHeight * 0.2)
        }
        .colorMultiply(Color(red: 0.55 + 0.45 * glow, green: 0.5 + 0.46 * glow, blue: 0.5 + 0.4 * glow))
    }
}

/// The wick: dark and slightly bent, with a glowing tip while the candle burns.
struct Wick: View {
    var isLit: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(white: 0.06), Color(red: 0.3, green: 0.24, blue: 0.18)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 2.4)
                .rotationEffect(.degrees(5), anchor: .bottom)
            Circle()
                .fill(Color(red: 1, green: 0.45, blue: 0.12))
                .frame(width: 4, height: 4)
                .blur(radius: 1)
                .offset(x: 0.6, y: -1)
                .opacity(isLit ? 1 : 0)
        }
    }
}
