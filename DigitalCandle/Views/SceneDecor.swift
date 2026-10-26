import SwiftUI

/// The dark, warm room around the candle.
struct SceneBackground: View {
    var isLit: Bool

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.02, blue: 0.025)
            RadialGradient(
                colors: [Color(red: 0.17, green: 0.09, blue: 0.06), .clear],
                center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 480)
                .opacity(isLit ? 1 : 0.45)
            BokehLights()
                .opacity(isLit ? 1 : 0.55)
        }
        .animation(.easeInOut(duration: 0.8), value: isLit)
    }
}

/// Soft, out-of-focus party lights in the background.
struct BokehLights: View {
    private struct Light {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var color: Color
        var opacity: Double
    }

    private static let gold = Color(red: 1, green: 0.78, blue: 0.42)
    private static let rose = Color(red: 1, green: 0.55, blue: 0.5)
    private static let amber = Color(red: 1, green: 0.62, blue: 0.25)

    private static let lights: [Light] = [
        Light(x: 0.12, y: 0.17, size: 46, color: gold, opacity: 0.16),
        Light(x: 0.86, y: 0.11, size: 30, color: rose, opacity: 0.16),
        Light(x: 0.74, y: 0.3, size: 58, color: gold, opacity: 0.09),
        Light(x: 0.2, y: 0.41, size: 26, color: amber, opacity: 0.13),
        Light(x: 0.91, y: 0.47, size: 40, color: rose, opacity: 0.09),
        Light(x: 0.06, y: 0.62, size: 62, color: gold, opacity: 0.07),
        Light(x: 0.33, y: 0.07, size: 22, color: amber, opacity: 0.18),
        Light(x: 0.62, y: 0.05, size: 38, color: gold, opacity: 0.11),
        Light(x: 0.94, y: 0.7, size: 28, color: amber, opacity: 0.11),
        Light(x: 0.1, y: 0.86, size: 36, color: rose, opacity: 0.07),
        Light(x: 0.45, y: 0.21, size: 18, color: gold, opacity: 0.11),
        Light(x: 0.82, y: 0.87, size: 50, color: gold, opacity: 0.06),
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Self.lights.indices, id: \.self) { index in
                let light = Self.lights[index]
                Circle()
                    .fill(light.color)
                    .frame(width: light.size, height: light.size)
                    .blur(radius: light.size * 0.22)
                    .opacity(light.opacity)
                    .position(x: light.x * proxy.size.width, y: light.y * proxy.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}

/// "Happy Birthday", which lights up when the candle is blown out.
struct BirthdayTitle: View {
    var phase: CandleModel.Phase

    var body: some View {
        let celebrating = phase == .blownOut
        VStack(spacing: 2) {
            Text("Happy Birthday")
                .font(.custom("SnellRoundhand-Bold", size: 46))
            Text("生 日 快 乐")
                .font(.system(size: 19, weight: .medium, design: .serif))
                .tracking(2)
        }
        .foregroundStyle(LinearGradient(
            colors: [Color(red: 1, green: 0.9, blue: 0.66), Color(red: 0.95, green: 0.68, blue: 0.34)],
            startPoint: .top, endPoint: .bottom))
        .shadow(color: Color(red: 1, green: 0.55, blue: 0.2).opacity(celebrating ? 0.9 : 0.4), radius: celebrating ? 16 : 8)
        .scaleEffect(celebrating ? 1.1 : 1)
        .opacity(phase == .unlit ? 0.55 : 1)
        .animation(.spring(response: 0.55, dampingFraction: 0.55), value: phase)
        .accessibilityElement(children: .combine)
    }
}

/// A short instruction with a quieter second line.
struct HintText: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.93, blue: 0.82))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .multilineTextAlignment(.center)
    }
}

/// How hard you're blowing; the candle goes out once the bar is full.
struct BlowMeter: View {
    var loudness: Double
    var threshold: Double

    var body: some View {
        let progress = min(max(loudness / max(threshold, 0.01), 0), 1)
        HStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.5))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 1, green: 0.85, blue: 0.45), Color(red: 1, green: 0.45, blue: 0.2)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, proxy.size.width * CGFloat(progress)))
                }
            }
            .frame(width: 140, height: 6)
        }
        .animation(.easeOut(duration: 0.12), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("吹气力度")
        .accessibilityValue("\(Int(progress * 100))%")
    }
}
