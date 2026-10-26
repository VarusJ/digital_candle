import SwiftUI

/// Teardrop outline of a candle flame. `lean` moves the tip sideways, as a fraction of the width.
struct FlameShape: Shape {
    var lean: CGFloat

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let radius = width / 2
        let bulbY = rect.maxY - radius // center of the round base
        let tip = CGPoint(x: rect.midX + lean * width, y: rect.minY)
        let k: CGFloat = 0.5523 // Bézier approximation of a quarter circle
        // Near the tip the sides follow it only partly, so a leaning flame bends instead of tilting.
        let upperShift = -lean * width * 0.3

        var path = Path()
        path.move(to: tip)
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: bulbY),
            control1: CGPoint(x: tip.x + width * 0.08 + upperShift, y: rect.minY + height * 0.32),
            control2: CGPoint(x: rect.maxX, y: bulbY - height * 0.22))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: bulbY + radius * k),
            control2: CGPoint(x: rect.midX + radius * k, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: bulbY),
            control1: CGPoint(x: rect.midX - radius * k, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: bulbY + radius * k))
        path.addCurve(
            to: tip,
            control1: CGPoint(x: rect.minX, y: bulbY - height * 0.22),
            control2: CGPoint(x: tip.x - width * 0.08 + upperShift, y: rect.minY + height * 0.32))
        path.closeSubpath()
        return path
    }
}

/// How the flame looks at one instant.
struct FlameState {
    var lean: CGFloat = 0
    var stretch: CGFloat = 1
    var squeeze: CGFloat = 1
    var glow: CGFloat = 1
    var opacity: CGFloat = 1
}

/// Turns time and the breath level into a lively but continuous flicker.
final class FlameMotion {
    private var startTime: TimeInterval?
    private var lastTime: TimeInterval?
    private var smoothedGust: CGFloat = 0
    private let seed = CGFloat.random(in: 0...100)

    func state(at time: TimeInterval, gust: CGFloat) -> FlameState {
        let start = startTime ?? time
        startTime = start
        let dt = CGFloat(min(max(time - (lastTime ?? time), 0), 0.1))
        lastTime = time
        smoothedGust += (gust - smoothedGust) * (1 - exp(-dt / 0.12))

        let g = smoothedGust
        let t = CGFloat(time - start) + seed
        let sway: CGFloat = 0.6 * sin(t * 1.7) + 0.3 * sin(t * 3.1 + 1.3) + 0.1 * sin(t * 6.7 + 0.4)
        let flutter: CGFloat = 0.5 * sin(t * 21) + 0.5 * sin(t * 33 + 2)
        let flicker: CGFloat = 0.035 * sin(t * 10.3) + 0.025 * sin(t * 16.9 + 0.7) + 0.02 * sin(t * 4.9 + 2.1)

        var state = FlameState()
        state.lean = 0.08 * sway + g * (0.5 + 0.3 * flutter)
        state.stretch = 1 + flicker - 0.3 * g + 0.1 * g * flutter
        state.squeeze = 1 - 0.5 * flicker + 0.12 * g
        state.glow = 1 + 0.07 * sin(t * 9.1) + 0.05 * sin(t * 14.3 + 1) - 0.4 * g
        state.opacity = 1 - 0.3 * g
        return state
    }
}

/// A burning candle flame with a soft halo of light around it, animated every frame.
struct FlameView: View {
    /// 0 is still air, 1 is blowing hard enough to put the flame out.
    var gust: Double
    /// Diameter of the halo relative to the flame's height.
    var haloScale: CGFloat

    @State private var motion = FlameMotion()

    init(gust: Double = 0, haloScale: CGFloat = 4.2) {
        self.gust = gust
        self.haloScale = haloScale
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let state = motion.state(at: timeline.date.timeIntervalSinceReferenceDate, gust: CGFloat(gust))
                flame(size: proxy.size, state: state)
            }
        }
        .allowsHitTesting(false)
    }

    private func flame(size: CGSize, state: FlameState) -> some View {
        let width = size.width
        let height = size.height
        return ZStack(alignment: .bottom) {
            // Blue base, where the wax vapour starts to burn.
            Ellipse()
                .fill(Color(red: 0.32, green: 0.5, blue: 1).opacity(0.75))
                .frame(width: width * 0.62, height: height * 0.2)
                .blur(radius: width * 0.07)
            // The luminous body of the flame, fading out at the bottom.
            FlameShape(lean: state.lean)
                .fill(EllipticalGradient(
                    stops: [
                        .init(color: Color(red: 1, green: 0.99, blue: 0.9), location: 0),
                        .init(color: Color(red: 1, green: 0.87, blue: 0.45), location: 0.38),
                        .init(color: Color(red: 1, green: 0.62, blue: 0.2), location: 0.72),
                        .init(color: Color(red: 0.96, green: 0.4, blue: 0.1), location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.72),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.8))
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.24)],
                        startPoint: .bottom, endPoint: .top)
                }
                .blur(radius: width * 0.045)
            // White-hot core.
            FlameShape(lean: state.lean * 0.55)
                .fill(LinearGradient(
                    colors: [.white, Color(red: 1, green: 0.96, blue: 0.78)],
                    startPoint: .bottom, endPoint: .top))
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)],
                        startPoint: .bottom, endPoint: .top)
                }
                .frame(width: width * 0.46, height: height * 0.56)
                .offset(x: state.lean * width * 0.2, y: -height * 0.07)
                .blur(radius: width * 0.08)
                .opacity(0.9)
        }
        .frame(width: width, height: height)
        .scaleEffect(x: state.squeeze, y: state.stretch, anchor: .bottom)
        .opacity(Double(state.opacity))
        .background(alignment: .bottom) {
            halo(flameHeight: height, glow: state.glow)
        }
    }

    private func halo(flameHeight: CGFloat, glow: CGFloat) -> some View {
        let diameter = flameHeight * haloScale
        return Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: Color(red: 1, green: 0.66, blue: 0.3).opacity(0.5), location: 0),
                    .init(color: Color(red: 1, green: 0.5, blue: 0.16).opacity(0.17), location: 0.35),
                    .init(color: Color(red: 1, green: 0.4, blue: 0.1).opacity(0), location: 1),
                ],
                center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
            .opacity(Double(min(max(0.85 * glow, 0), 1)))
            .offset(y: diameter / 2 - flameHeight * 0.35)
            .blendMode(.plusLighter)
    }
}
