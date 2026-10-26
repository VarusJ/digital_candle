import SwiftUI
import UIKit

/// Where everything sits on stage, derived from the available size.
struct SceneLayout {
    let size: CGSize

    static let matchAngle = Angle.degrees(-32)

    var midX: CGFloat { size.width / 2 }
    var candleWidth: CGFloat { min(size.width * 0.3, 130) }
    var candleHeight: CGFloat { min(size.height * 0.3, 250) }
    var candleBottom: CGFloat { size.height * 0.8 }
    var candleTop: CGFloat { candleBottom - candleHeight }
    var capHeight: CGFloat { candleWidth * CandleBody.capRatio }
    var wickHeight: CGFloat { 16 }
    /// Where the wick stands: the middle of the candle's top surface.
    var wickBase: CGPoint { CGPoint(x: midX, y: candleTop + capHeight * 0.55) }
    var wickTip: CGPoint { CGPoint(x: midX, y: wickBase.y - wickHeight) }
    var flameSize: CGSize { CGSize(width: candleWidth * 0.3, height: candleWidth * 0.86) }
    /// The flame's base wraps around the top half of the wick.
    var flameCenter: CGPoint { CGPoint(x: midX, y: wickTip.y + wickHeight * 0.45 - flameSize.height / 2) }
    var flameTop: CGFloat { flameCenter.y - flameSize.height / 2 }
    var titleCenter: CGPoint { CGPoint(x: midX, y: max(size.height * 0.13, 70)) }
    var hintCenter: CGPoint { CGPoint(x: midX, y: size.height * 0.905) }
    var matchCenter: CGPoint { CGPoint(x: size.width - max(56, size.width * 0.16), y: candleBottom - 34) }

    /// Where the match head is when the middle of the match is at `center`.
    func matchHead(center: CGPoint) -> CGPoint {
        let offset = MatchStick.headCenterY - MatchStick.size.height / 2 // negative: above the middle
        let angle = CGFloat(Self.matchAngle.radians)
        return CGPoint(x: center.x - offset * sin(angle), y: center.y + offset * cos(angle))
    }
}

struct ContentView: View {
    @State private var model = CandleModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("blowSensitivity") private var sensitivity = 0.5
    @AppStorage("playsBirthdaySong") private var playsBirthdaySong = true
    @State private var showsSettings = false
    @State private var celebrationStart: Date?
    @State private var showsBlowNudge = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.5, dampingFraction: 0.75)))
    private var matchDrag = CGSize.zero
    @GestureState private var isHoldingMatch = false

    var body: some View {
        ZStack {
            SceneBackground(isLit: model.isLit)
                .ignoresSafeArea()
            GeometryReader { proxy in
                let layout = SceneLayout(size: proxy.size)
                ZStack {
                    candle(layout)
                    if let start = celebrationStart, model.phase == .blownOut {
                        SmokeView(start: start)
                            .frame(width: 220, height: 300)
                            .position(x: layout.wickTip.x, y: layout.wickTip.y + 4 - 150)
                    }
                    BirthdayTitle(phase: model.phase)
                        .position(layout.titleCenter)
                    hint
                        .frame(width: max(proxy.size.width - 48, 0))
                        .position(layout.hintCenter)
                    match(layout)
                }
            }
            if let start = celebrationStart, model.phase == .blownOut {
                ConfettiView(start: start)
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .topTrailing) {
            settingsButton
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, newPhase in
            model.scenePhaseChanged(to: newPhase)
        }
        .onChange(of: sensitivity, initial: true) { _, value in
            model.sensitivity = value
        }
        .onChange(of: playsBirthdaySong, initial: true) { _, value in
            model.playsBirthdaySong = value
        }
        .onChange(of: model.phase) {
            showsBlowNudge = false
        }
        .onChange(of: isHoldingMatch) { _, holding in
            if holding {
                Haptics.strike()
            }
        }
        .task(id: model.blownOutAt) {
            // Smoke and confetti play for a few seconds after each blow-out.
            guard let start = model.blownOutAt else { return }
            celebrationStart = start
            try? await Task.sleep(for: .seconds(6.5))
            if celebrationStart == start {
                celebrationStart = nil
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(sensitivity: $sensitivity, playsBirthdaySong: $playsBirthdaySong)
                .presentationDetents([.medium, .large])
        }
        #if DEBUG
        .task {
            await runDemoIfRequested()
        }
        #endif
    }

    // MARK: - Candle

    @ViewBuilder
    private func candle(_ layout: SceneLayout) -> some View {
        let glow = model.isLit ? 1.0 : 0.0
        CandleDish(width: layout.candleWidth * 1.8, glow: glow)
            .animation(.easeInOut(duration: 0.7), value: glow)
            .position(x: layout.midX, y: layout.candleBottom - layout.capHeight * 0.15)
        CandleBody(width: layout.candleWidth, height: layout.candleHeight, glow: glow)
            .animation(.easeInOut(duration: 0.7), value: glow)
            .position(x: layout.midX, y: layout.candleTop + layout.candleHeight / 2)
        Wick(isLit: model.isLit)
            .frame(width: 6, height: layout.wickHeight)
            .position(x: layout.midX, y: layout.wickBase.y - layout.wickHeight / 2)
        ZStack {
            if model.isLit {
                FlameView(gust: model.gust)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.05, anchor: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.3, anchor: .bottom).combined(with: .opacity)))
            }
        }
        .frame(width: layout.flameSize.width, height: layout.flameSize.height)
        .position(layout.flameCenter)
        // The whole candle is a big tap target for lighting it.
        Color.clear
            .contentShape(Rectangle())
            .frame(width: layout.candleWidth * 1.5, height: layout.candleBottom - layout.flameTop)
            .position(x: layout.midX, y: (layout.flameTop + layout.candleBottom) / 2)
            .onTapGesture(perform: candleTapped)
            .accessibilityElement()
            .accessibilityLabel(model.isLit ? "燃烧中的蜡烛" : "蜡烛")
            .accessibilityHint(model.isLit ? "对着手机吹气来熄灭" : "轻点两下点燃")
            .accessibilityAddTraits(.isButton)
    }

    private func candleTapped() {
        switch model.phase {
        case .unlit, .blownOut:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                model.light()
            }
        case .lit:
            if model.canBlowOutByTapping {
                model.blowOut()
            } else {
                withAnimation {
                    showsBlowNudge = true
                }
            }
        }
    }

    // MARK: - Match

    /// A match you can drag to the wick. It lights up as soon as you pick it up.
    @ViewBuilder
    private func match(_ layout: SceneLayout) -> some View {
        let center = CGPoint(x: layout.matchCenter.x + matchDrag.width, y: layout.matchCenter.y + matchDrag.height)
        let head = layout.matchHead(center: center)
        let isVisible = !model.isLit || isHoldingMatch
        ZStack {
            MatchStick()
                .rotationEffect(SceneLayout.matchAngle)
                .frame(width: 70, height: 110)
                .contentShape(Rectangle())
                .gesture(matchGesture(layout))
                .position(center)
            ZStack {
                if isHoldingMatch {
                    FlameView(haloScale: 3)
                        .transition(.scale(scale: 0.1, anchor: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: 11, height: 30)
            .position(x: head.x, y: head.y - 11)
            .animation(.easeOut(duration: 0.15), value: isHoldingMatch)
            .allowsHitTesting(false)
        }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .accessibilityHidden(true)
    }

    private func matchGesture(_ layout: SceneLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($matchDrag) { value, state, _ in
                state = value.translation
            }
            .updating($isHoldingMatch) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard !model.isLit else { return }
                // The match's flame burns just above its head; light the candle when it reaches the wick.
                let restingHead = layout.matchHead(center: layout.matchCenter)
                let dx = restingHead.x + value.translation.width - layout.wickTip.x
                let dy = restingHead.y + value.translation.height - 11 - layout.wickTip.y
                if (dx * dx + dy * dy).squareRoot() < 30 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                        model.light()
                    }
                }
            }
    }

    // MARK: - Hints

    private var hint: some View {
        VStack(spacing: 10) {
            switch model.phase {
            case .unlit:
                HintText(title: "拖动火柴靠近烛芯，点燃蜡烛", detail: "也可以直接轻点蜡烛")
            case .lit:
                litHint
            case .blownOut:
                HintText(title: "愿望一定会实现的 ✨", detail: "拖动火柴，可以再点一次")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.phase)
    }

    @ViewBuilder
    private var litHint: some View {
        switch model.microphone {
        case .denied:
            HintText(title: "需要麦克风权限才能感应吹气", detail: "也可以轻点火焰来熄灭")
            Button("去设置里开启", action: openSystemSettings)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.orange)
        case .unavailable:
            HintText(title: "麦克风暂时用不了", detail: "可以轻点火焰来熄灭")
        case .idle, .listening:
            HintText(
                title: showsBlowNudge ? "对着手机吹一口气试试 🌬️" : "闭上眼睛，许个愿吧 ✨",
                detail: "许好愿后，对着手机底部吹一口气")
            BlowMeter(loudness: model.loudness, threshold: model.threshold)
                .opacity(model.microphone == .listening ? 1 : 0)
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private var settingsButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .padding(.top, 4)
        .padding(.trailing, 8)
        .accessibilityLabel("设置")
    }

    #if DEBUG
    /// Screenshot support: launch with `-DemoPhase lit` or `-DemoPhase blownOut`,
    /// optionally with `-DemoGust 0.7` to fake someone blowing.
    private func runDemoIfRequested() async {
        let defaults = UserDefaults.standard
        guard let phase = defaults.string(forKey: "DemoPhase") else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
            model.light(listening: false)
        }
        if defaults.object(forKey: "DemoGust") != nil {
            model.simulateGust(defaults.double(forKey: "DemoGust"))
        }
        if phase == "blownOut" {
            try? await Task.sleep(for: .milliseconds(500))
            model.blowOut()
        }
    }
    #endif
}

#Preview {
    ContentView()
}
