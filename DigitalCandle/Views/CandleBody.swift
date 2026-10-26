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

/// An ivory pillar candle with a melted top and a few wax drips.
struct CandleBody: View, Animatable {
    /// Height of the top surface relative to the candle's width.
    static let capRatio: CGFloat = 0.26

    var width: CGFloat
    var height: CGFloat
    /// 0 in the dark, 1 when lit by its own flame.
    var glow: Double

    var animatableData: Double {
        get { glow }
        set { glow = newValue }
    }

    private var capHeight: CGFloat { width * Self.capRatio }

    var body: some View {
        ZStack(alignment: .top) {
            CylinderSide(capHeight: capHeight)
                .fill(Self.waxGradient)
            // Warm light from the flame on the upper part, shade towards the bottom.
            CylinderSide(capHeight: capHeight)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 1, green: 0.6, blue: 0.2).opacity(0.3 * glow), location: 0),
                        .init(color: .clear, location: 0.5),
                        .init(color: .black.opacity(0.3), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom))
            drip(at: -0.27, length: 0.17, thickness: 0.085)
            drip(at: 0.06, length: 0.09, thickness: 0.07)
            drip(at: 0.33, length: 0.13, thickness: 0.075)
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(red: 0.84, green: 0.76, blue: 0.64), Color(red: 0.98, green: 0.94, blue: 0.86)],
                    startPoint: .top, endPoint: .bottom))
                .overlay {
                    Ellipse().stroke(Color.white.opacity(0.45), lineWidth: 1)
                }
                .frame(width: width, height: capHeight)
            // The melted pool around the wick glows while the candle burns.
            Ellipse()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 1, green: 0.8, blue: 0.5).opacity(0.2 + 0.8 * glow),
                        Color(red: 0.92, green: 0.82, blue: 0.68).opacity(0.7),
                    ],
                    center: .center, startRadius: 0, endRadius: width * 0.38))
                .frame(width: width * 0.74, height: capHeight * 0.6)
                .offset(y: capHeight * 0.24)
        }
        .frame(width: width, height: height, alignment: .top)
        .colorMultiply(Color(red: 0.42 + 0.58 * glow, green: 0.4 + 0.56 * glow, blue: 0.42 + 0.46 * glow))
    }

    /// A wax drip running down the front, starting under the rim of the top.
    private func drip(at position: CGFloat, length: CGFloat, thickness: CGFloat) -> some View {
        let x = position * width
        let halfWidth = width / 2
        let rimY = capHeight / 2 * (1 + sqrt(max(0, 1 - x * x / (halfWidth * halfWidth))))
        return Capsule()
            .fill(LinearGradient(
                colors: [Color(red: 1, green: 0.98, blue: 0.94), Color(red: 0.88, green: 0.8, blue: 0.68)],
                startPoint: .leading, endPoint: .trailing))
            .frame(width: width * thickness, height: height * length)
            .offset(x: x, y: rimY - capHeight * 0.35)
    }

    private static let waxGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.70, green: 0.60, blue: 0.48), location: 0),
            .init(color: Color(red: 0.93, green: 0.87, blue: 0.76), location: 0.2),
            .init(color: Color(red: 1.00, green: 0.97, blue: 0.91), location: 0.4),
            .init(color: Color(red: 0.94, green: 0.88, blue: 0.78), location: 0.68),
            .init(color: Color(red: 0.62, green: 0.52, blue: 0.41), location: 1),
        ],
        startPoint: .leading, endPoint: .trailing)
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
                .frame(width: 3)
                .rotationEffect(.degrees(5), anchor: .bottom)
            Circle()
                .fill(Color(red: 1, green: 0.45, blue: 0.12))
                .frame(width: 4.5, height: 4.5)
                .blur(radius: 1)
                .offset(x: 0.8, y: -1)
                .opacity(isLit ? 1 : 0)
        }
    }
}

/// A brass dish under the candle, with the candle's light pooling on the table around it.
struct CandleDish: View, Animatable {
    var width: CGFloat
    /// 0 in the dark, 1 when the candle burns.
    var glow: Double

    var animatableData: Double {
        get { glow }
        set { glow = newValue }
    }

    var body: some View {
        let height = width * 0.28
        ZStack {
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(red: 1, green: 0.6, blue: 0.25).opacity(0.28 * glow), .clear],
                    center: .center, startRadius: 0, endRadius: width * 0.95))
                .frame(width: width * 2.2, height: height * 2.4)
            Ellipse()
                .fill(Color.black.opacity(0.55))
                .frame(width: width * 1.04, height: height * 1.1)
                .offset(y: height * 0.2)
                .blur(radius: 8)
            Ellipse()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.45, green: 0.32, blue: 0.14), location: 0),
                        .init(color: Color(red: 0.93, green: 0.78, blue: 0.48), location: 0.35),
                        .init(color: Color(red: 0.72, green: 0.55, blue: 0.27), location: 0.65),
                        .init(color: Color(red: 0.36, green: 0.25, blue: 0.11), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: width, height: height)
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(red: 0.32, green: 0.22, blue: 0.1), Color(red: 0.62, green: 0.47, blue: 0.24)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: width * 0.86, height: height * 0.66)
                .offset(y: -height * 0.07)
        }
        .colorMultiply(Color(red: 0.45 + 0.55 * glow, green: 0.42 + 0.58 * glow, blue: 0.42 + 0.5 * glow))
    }
}
