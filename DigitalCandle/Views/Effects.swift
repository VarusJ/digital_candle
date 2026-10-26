import SwiftUI

/// Wisps of smoke curling up from a freshly blown-out wick, and the wick's fading ember.
/// The bottom center of the view is the tip of the wick.
struct SmokeView: View {
    let start: Date

    private static let puffCount = 40
    private static let puffLife: CGFloat = 2.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let elapsed = CGFloat(timeline.date.timeIntervalSince(start))
                let origin = CGPoint(x: size.width / 2, y: size.height - 4)
                drawEmber(context, at: origin, elapsed: elapsed)
                drawSmoke(context, from: origin, elapsed: elapsed)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawEmber(_ context: GraphicsContext, at origin: CGPoint, elapsed: CGFloat) {
        let heat = max(0, 1 - elapsed / 2.2)
        guard heat > 0 else { return }
        var context = context
        context.addFilter(.blur(radius: 1.5))
        let radius: CGFloat = 2.6
        let rect = CGRect(x: origin.x - radius, y: origin.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(Color(red: 1, green: 0.42, blue: 0.1).opacity(Double(heat))))
    }

    private func drawSmoke(_ context: GraphicsContext, from origin: CGPoint, elapsed: CGFloat) {
        var context = context
        context.addFilter(.blur(radius: 6))
        context.drawLayer { layer in
            for index in 0..<Self.puffCount {
                let i = CGFloat(index)
                let age = elapsed - i * 0.045
                guard age > 0, age < Self.puffLife else { continue }
                let progress = age / Self.puffLife
                let rise: CGFloat = age * 55 + age * age * 8
                let drift: CGFloat = sin(age * 2.2 + i * 0.55) * (4 + age * 16) + age * 6
                let radius: CGFloat = 2.5 + progress * 15
                let alpha: CGFloat = 0.32 * (1 - progress) * (1 - progress) * min(1, age * 8)
                let rect = CGRect(
                    x: origin.x + drift - radius, y: origin.y - rise - radius,
                    width: radius * 2, height: radius * 2)
                layer.fill(Path(ellipseIn: rect), with: .color(Color(white: 0.82).opacity(Double(alpha))))
            }
        }
    }
}

/// A one-off shower of confetti over the whole screen.
struct ConfettiView: View {
    let start: Date

    private struct Piece {
        var x: CGFloat
        var delay: CGFloat
        var fallSpeed: CGFloat
        var swayAmplitude: CGFloat
        var swaySpeed: CGFloat
        var spin: CGFloat
        var flipSpeed: CGFloat
        var size: CGSize
        var color: Color
        var isRound: Bool
    }

    private static let colors: [Color] = [
        Color(red: 1, green: 0.84, blue: 0.4),
        Color(red: 1, green: 0.55, blue: 0.62),
        Color(red: 0.55, green: 0.8, blue: 1),
        Color(red: 0.6, green: 0.92, blue: 0.7),
        Color(red: 0.8, green: 0.65, blue: 1),
        Color(red: 1, green: 0.66, blue: 0.4),
    ]

    private static let pieces: [Piece] = (0..<110).map { _ in
        Piece(
            x: .random(in: 0...1),
            delay: .random(in: 0...0.9),
            fallSpeed: .random(in: 0.22...0.38),
            swayAmplitude: .random(in: 8...28),
            swaySpeed: .random(in: 1.5...3.5),
            spin: .random(in: -4...4),
            flipSpeed: .random(in: 3...9),
            size: CGSize(width: .random(in: 6...10), height: .random(in: 9...15)),
            color: ConfettiView.colors.randomElement() ?? .yellow,
            isRound: Int.random(in: 0..<4) == 0)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let elapsed = CGFloat(timeline.date.timeIntervalSince(start))
                let fade: CGFloat = min(1, max(0, 5.5 - elapsed))
                guard fade > 0 else { return }
                for piece in Self.pieces {
                    let age = elapsed - piece.delay
                    guard age > 0 else { continue }
                    let y: CGFloat = -20 + age * piece.fallSpeed * size.height + age * age * 12
                    guard y < size.height + 20 else { continue }
                    let x: CGFloat = piece.x * size.width + sin(age * piece.swaySpeed + piece.x * 10) * piece.swayAmplitude
                    var pieceContext = context
                    pieceContext.opacity = Double(fade)
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(Double(age * piece.spin)))
                    // Squashing the width back and forth makes the piece look like it tumbles.
                    pieceContext.scaleBy(x: cos(age * piece.flipSpeed), y: 1)
                    let rect = CGRect(
                        x: -piece.size.width / 2, y: -piece.size.height / 2,
                        width: piece.size.width, height: piece.size.height)
                    let path = piece.isRound ? Path(ellipseIn: rect) : Path(rect)
                    pieceContext.fill(path, with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
