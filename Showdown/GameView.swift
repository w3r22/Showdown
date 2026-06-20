import SwiftUI

struct GameView: View {
    @StateObject private var game = GameState()

    // Transient player-attack animation (lunge offset + weapon swing).
    @State private var attackLunge: CGFloat = 0
    @State private var attackSwing: Double = 0

    var body: some View {
        ZStack {
            background

            VStack(spacing: 24) {
                header
                Spacer(minLength: 0)
                arena
                Spacer(minLength: 0)
                controls
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 12)

            if game.phase != .playerTurn {
                overlay
            }
        }
        .onChange(of: game.playerAttackPulse) { _, _ in
            playAttackAnimation()
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.22),
                                    Color(red: 0.05, green: 0.06, blue: 0.11),
                                    Color(red: 0.02, green: 0.03, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
            // Subtle vignette for depth.
            RadialGradient(colors: [Color.clear, Color.black.opacity(0.55)],
                           center: .center, startRadius: 120, endRadius: 520)
        }
        .ignoresSafeArea()
    }

    private func playAttackAnimation() {
        let dir: CGFloat = game.player.facing == .right ? 1 : -1
        withAnimation(.easeOut(duration: 0.09)) {
            attackLunge = 10 * dir
            attackSwing = 55 * dir
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeInOut(duration: 0.18)) {
                attackLunge = 0
                attackSwing = 0
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("SHOWDOWN")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .tracking(4)
            if let appVersion {
                Text("v\(appVersion)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text("Wave \(game.wave) of \(GameState.totalWaves)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    // MARK: Arena

    private var arena: some View {
        GeometryReader { geo in
            let count = GameState.arenaSize
            let spacing: CGFloat = 3
            let cellW = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            ZStack(alignment: .bottom) {
                DojoFloor(count: count, cellWidth: cellW, spacing: spacing,
                          targetIndex: game.facingTarget)
                HStack(spacing: spacing) {
                    ForEach(0..<count, id: \.self) { i in
                        CellView(index: i,
                                 width: cellW,
                                 occupant: game.occupant(at: i),
                                 isTarget: game.facingTarget == i,
                                 isFlashing: game.flashPositions.contains(i),
                                 attackLunge: attackLunge,
                                 attackSwing: attackSwing)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .onChange(of: game.flashPositions) { _, new in
                guard !new.isEmpty else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.easeOut(duration: 0.2)) { game.clearFlashes() }
                }
            }
        }
        .frame(height: 170)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ActionButton(title: "Move", systemImage: "arrow.left", subtitle: "+1 stam",
                             tint: .blue, enabled: game.canMove(.left)) {
                    withAnimation(.easeInOut(duration: 0.18)) { game.move(.left) }
                }
                ActionButton(title: "Move", systemImage: "arrow.right", subtitle: "+1 stam",
                             tint: .blue, enabled: game.canMove(.right)) {
                    withAnimation(.easeInOut(duration: 0.18)) { game.move(.right) }
                }
            }
            HStack(spacing: 10) {
                ActionButton(title: "Attack", systemImage: "bolt.fill", subtitle: "3 dmg · −2 stam",
                             tint: .red, enabled: game.canAttack) {
                    withAnimation(.easeInOut(duration: 0.18)) { game.playerAttack() }
                }
                ActionButton(title: "Skip", systemImage: "hourglass", subtitle: "+3 stam",
                             tint: .green, enabled: game.phase == .playerTurn) {
                    withAnimation(.easeInOut(duration: 0.18)) { game.skipTurn() }
                }
            }
            ActionButton(title: "Turn around", systemImage: "arrow.left.arrow.right",
                         subtitle: "free · 0 turns",
                         tint: .orange, enabled: game.phase == .playerTurn, wide: true) {
                withAnimation(.easeInOut(duration: 0.18)) { game.turnPlayer() }
            }
        }
    }

    // MARK: Overlay

    private var overlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(game.phase == .won ? "🏆" : "💀")
                    .font(.system(size: 64))
                Text(game.phase == .won ? "You Win!" : "Game Over")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Button {
                    withAnimation { game.reset() }
                } label: {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
            }
            .padding(40)
        }
        .transition(.opacity)
    }
}

// MARK: - Cell

struct CellView: View {
    let index: Int
    let width: CGFloat
    let occupant: Combatant?
    let isTarget: Bool
    let isFlashing: Bool
    var attackLunge: CGFloat = 0
    var attackSwing: Double = 0

    var body: some View {
        VStack(spacing: 3) {
            // Floating bars area above the sprite.
            barsArea
                .frame(height: 16)

            ZStack {
                // Hit flash sits behind the fighter so the floor reads continuously.
                if isFlashing {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.5))
                }
                sprite
            }
            .frame(width: width, height: width)
        }
    }

    @ViewBuilder private var barsArea: some View {
        if let c = occupant {
            VStack(spacing: 2) {
                StatBar(value: c.hp, maxValue: c.maxHP, color: .red, width: width)
                if c.isPlayer {
                    StatBar(value: c.stamina, maxValue: c.maxStamina, color: .yellow, width: width)
                }
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var sprite: some View {
        if let c = occupant {
            FighterSprite(isPlayer: c.isPlayer,
                          facing: c.facing,
                          width: width,
                          lunge: c.isPlayer ? attackLunge : 0,
                          swing: c.isPlayer ? attackSwing : 0)
        }
    }
}

// MARK: - Fighter sprite (vector humanoid w/ katana)

struct FighterSprite: View {
    let isPlayer: Bool
    let facing: Facing
    let width: CGFloat
    var lunge: CGFloat = 0
    var swing: Double = 0

    var body: some View {
        let bodyGradient = LinearGradient(
            colors: isPlayer
                ? [Color(red: 0.45, green: 0.6, blue: 1.0), Color(red: 0.18, green: 0.28, blue: 0.85)]
                : [Color(red: 0.98, green: 0.45, blue: 0.45), Color(red: 0.78, green: 0.12, blue: 0.18)],
            startPoint: .top, endPoint: .bottom)
        let limbColor = isPlayer ? Color(red: 0.28, green: 0.38, blue: 0.9)
                                 : Color(red: 0.7, green: 0.16, blue: 0.2)
        let headColor = isPlayer ? Color(red: 0.6, green: 0.72, blue: 1.0)
                                 : Color(red: 1.0, green: 0.6, blue: 0.6)

        ZStack {
            // Grounding drop shadow.
            Ellipse()
                .fill(Color.black.opacity(0.35))
                .frame(width: width * 0.62, height: width * 0.14)
                .offset(y: width * 0.42)
                .blur(radius: 1.5)

            ZStack {
                // Back leg.
                Capsule()
                    .fill(limbColor)
                    .frame(width: width * 0.12, height: width * 0.30)
                    .offset(x: -width * 0.08, y: width * 0.28)
                // Front leg.
                Capsule()
                    .fill(limbColor)
                    .frame(width: width * 0.12, height: width * 0.30)
                    .offset(x: width * 0.10, y: width * 0.28)

                // Torso.
                RoundedRectangle(cornerRadius: width * 0.10)
                    .fill(bodyGradient)
                    .frame(width: width * 0.34, height: width * 0.42)
                    .offset(y: width * 0.02)

                // Head.
                Circle()
                    .fill(headColor)
                    .frame(width: width * 0.26, height: width * 0.26)
                    .offset(y: -width * 0.28)

                // Forward arm + katana, anchored at the shoulder and swung on attack.
                ZStack {
                    // Arm.
                    Capsule()
                        .fill(limbColor)
                        .frame(width: width * 0.11, height: width * 0.30)
                        .offset(x: width * 0.12, y: width * 0.02)
                    // Katana: thin angled blade pointing forward.
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white, Color(white: 0.7)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: width * 0.055, height: width * 0.62)
                        .rotationEffect(.degrees(55), anchor: .bottom)
                        .offset(x: width * 0.30, y: -width * 0.06)
                }
                .rotationEffect(.degrees(swing), anchor: .center)
            }
            .frame(width: width, height: width)
            .scaleEffect(x: facing == .left ? -1 : 1, y: 1)
            .offset(x: lunge)
        }
    }
}

// MARK: - Dojo floor

struct DojoFloor: View {
    let count: Int
    let cellWidth: CGFloat
    let spacing: CGFloat
    let targetIndex: Int

    var body: some View {
        let totalWidth = cellWidth * CGFloat(count) + spacing * CGFloat(count - 1)
        ZStack(alignment: .bottom) {
            // Continuous ground strip the fighters stand on.
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(
                    colors: [Color(red: 0.22, green: 0.18, blue: 0.14),
                             Color(red: 0.13, green: 0.10, blue: 0.08)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: totalWidth, height: cellWidth * 0.46)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            // Subtle tick marks delineating each of the 10 cells.
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    ZStack {
                        if i == targetIndex {
                            Rectangle()
                                .fill(Color.yellow.opacity(0.18))
                        }
                        if i > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(width: cellWidth + spacing)
                }
            }
            .frame(width: totalWidth, height: cellWidth * 0.46, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .offset(y: -cellWidth * 0.02)
    }
}

// MARK: - Stat bar

struct StatBar: View {
    let value: Int
    let maxValue: Int
    let color: Color
    let width: CGFloat

    var body: some View {
        let fraction = maxValue > 0 ? max(0, min(1, CGFloat(value) / CGFloat(maxValue))) : 0
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.55))
            Capsule()
                .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.7)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: max(0, width * fraction))
        }
        .frame(width: width, height: 5)
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
    }
}

// MARK: - Action button

struct ActionButton: View {
    let title: String
    let systemImage: String
    var subtitle: String = ""
    let tint: Color
    let enabled: Bool
    var wide: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                    Text(title)
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: enabled
                            ? [tint.opacity(0.95), tint.opacity(0.7)]
                            : [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(enabled ? 0.18 : 0.06), lineWidth: 1)
            )
            .shadow(color: enabled ? tint.opacity(0.35) : .clear, radius: 6, y: 3)
        }
        .disabled(!enabled)
    }
}

#Preview {
    GameView()
}
