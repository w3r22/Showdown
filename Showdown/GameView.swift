import SwiftUI

struct GameView: View {
    @StateObject private var game = GameState()

    // Transient player-attack animation (lunge offset + weapon swing).
    @State private var attackLunge: CGFloat = 0
    @State private var attackSwing: Double = 0

    // Transient thrown-shuriken animation: cell indices to fly between + progress/spin/visibility.
    @State private var shurikenFrom: Int = 0
    @State private var shurikenTo: Int = 0
    @State private var shurikenProgress: CGFloat = 0
    @State private var shurikenSpin: Double = 0
    @State private var shurikenVisible: Bool = false

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
        .onChange(of: game.throwPulse) { _, _ in
            playThrowAnimation()
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

    private func playThrowAnimation() {
        guard let t = game.lastThrow else { return }
        // A brief throw lunge for feel, mirroring the melee swing.
        playAttackAnimation()

        shurikenFrom = t.from
        shurikenTo = t.to
        shurikenProgress = 0
        shurikenSpin = 0
        shurikenVisible = true
        // Fly across and spin; then vanish.
        withAnimation(.easeOut(duration: 0.25)) {
            shurikenProgress = 1
            shurikenSpin = 720
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            shurikenVisible = false
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
                                 isThreatened: game.threatenedCell == i,
                                 attackLunge: attackLunge,
                                 attackSwing: attackSwing)
                    }
                }

                // Thrown shuriken: flies along the fighters' row from the player's cell to the target cell.
                // Skip the zero-length case (throw into the wall: to == from) so it doesn't hover in place.
                if shurikenVisible && shurikenTo != shurikenFrom {
                    // True cell centers; the fighter square is bottom-aligned, so its vertical center
                    // sits at geo.size.height - cellW/2.
                    let fromX = CGFloat(shurikenFrom) * (cellW + spacing) + cellW / 2
                    let toX = CGFloat(shurikenTo) * (cellW + spacing) + cellW / 2
                    let x = fromX + (toX - fromX) * shurikenProgress
                    ShurikenShape()
                        .fill(LinearGradient(colors: [Color.white, Color(white: 0.6)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: cellW * 0.34, height: cellW * 0.34)
                        .rotationEffect(.degrees(shurikenSpin))
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .position(x: x, y: geo.size.height - cellW / 2)
                        .allowsHitTesting(false)
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
                ActionButton(title: "Throw", systemImage: "staroflife.fill", subtitle: "2 dmg · −3 stam",
                             tint: .purple, enabled: game.canThrow) {
                    withAnimation(.easeInOut(duration: 0.18)) { game.throwShuriken() }
                }
            }
            HStack(spacing: 10) {
                ActionButton(title: "Skip", systemImage: "hourglass", subtitle: "+3 stam",
                             tint: .green, enabled: game.phase == .playerTurn) {
                    withAnimation(.easeInOut(duration: 0.18)) { game.skipTurn() }
                }
                ActionButton(title: "Turn", systemImage: "arrow.left.arrow.right",
                             subtitle: "free · 0 turns",
                             tint: .orange, enabled: game.phase == .playerTurn) {
                    withAnimation(.easeInOut(duration: 0.18)) { game.turnPlayer() }
                }
            }
        }
    }

    // MARK: Overlay

    @ViewBuilder private var overlay: some View {
        if game.phase == .choosingUpgrade {
            upgradeOverlay
        } else {
            endOverlay
        }
    }

    private var endOverlay: some View {
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

    private var upgradeOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Choose an upgrade")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Wave \(game.wave) cleared")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                VStack(spacing: 12) {
                    ForEach(game.offeredUpgrades) { upgrade in
                        Button {
                            withAnimation { game.chooseUpgrade(upgrade) }
                        } label: {
                            UpgradeCard(upgrade: upgrade)
                        }
                    }
                }
            }
            .padding(32)
        }
        .transition(.opacity)
    }
}

// MARK: - Upgrade card

struct UpgradeCard: View {
    let upgrade: Upgrade

    var body: some View {
        VStack(spacing: 4) {
            Text(upgrade.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(upgrade.detail)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color.indigo.opacity(0.85), Color.indigo.opacity(0.55)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Cell

struct CellView: View {
    let index: Int
    let width: CGFloat
    let occupant: Combatant?
    let isTarget: Bool
    let isFlashing: Bool
    var isThreatened: Bool = false
    var attackLunge: CGFloat = 0
    var attackSwing: Double = 0

    // Drives the pulsing telegraph indicators.
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 3) {
            // Floating bars area above the sprite.
            barsArea
                .frame(height: 24)

            ZStack {
                // Hit flash sits behind the fighter so the floor reads continuously.
                if isFlashing {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.5))
                }
                // Threatened cell: pulsing red outline distinct from the yellow facing target.
                if isThreatened {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(pulse ? 0.95 : 0.4), lineWidth: 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.15))
                        )
                }
                sprite

                // Wind-up telegraph: warning badge floating above a winding-up enemy.
                if let c = occupant, c.windingUp {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: width * 0.30, weight: .bold))
                        .foregroundStyle(.yellow)
                        .shadow(color: .red.opacity(0.9), radius: 3)
                        .scaleEffect(pulse ? 1.15 : 0.9)
                        .offset(y: -width * 0.52)
                }
            }
            .frame(width: width, height: width)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder private var barsArea: some View {
        if let c = occupant {
            VStack(spacing: 2) {
                if c.isPlayer {
                    StatBar(value: c.hp, maxValue: c.maxHP, color: .red, width: width)
                    StatBar(value: c.stamina, maxValue: c.maxStamina, color: .yellow, width: width)
                } else {
                    // Enemies: HP shown as a legible number in a dark pill, with a slim red bar.
                    Text("\(c.hp)")
                        .font(.system(size: width * 0.34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.black.opacity(0.7))
                        )
                        .shadow(color: .black.opacity(0.6), radius: 1)
                    StatBar(value: c.hp, maxValue: c.maxHP, color: .red, width: width)
                }
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var sprite: some View {
        if let c = occupant {
            FighterSprite(isPlayer: c.isPlayer,
                          kind: c.kind,
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
    var kind: EnemyKind = .grunt
    let facing: Facing
    let width: CGFloat
    var lunge: CGFloat = 0
    var swing: Double = 0

    // Per-kind body scale: brutes are bulkier, runners leaner/smaller.
    private var bodyScale: CGFloat {
        guard !isPlayer else { return 1 }
        switch kind {
        case .grunt:  return 1.0
        case .brute:  return 1.22
        case .runner: return 0.84
        case .archer: return 0.92
        }
    }

    private var bodyGradient: LinearGradient {
        let colors: [Color]
        if isPlayer {
            colors = [Color(red: 0.45, green: 0.6, blue: 1.0), Color(red: 0.18, green: 0.28, blue: 0.85)]
        } else {
            switch kind {
            case .grunt:
                colors = [Color(red: 0.98, green: 0.45, blue: 0.45), Color(red: 0.78, green: 0.12, blue: 0.18)]
            case .brute: // darker, heavier red
                colors = [Color(red: 0.72, green: 0.20, blue: 0.22), Color(red: 0.45, green: 0.05, blue: 0.08)]
            case .runner: // orange, agile
                colors = [Color(red: 1.0, green: 0.62, blue: 0.30), Color(red: 0.85, green: 0.35, blue: 0.08)]
            case .archer: // magenta/violet, ranged
                colors = [Color(red: 0.85, green: 0.45, blue: 0.85), Color(red: 0.55, green: 0.12, blue: 0.5)]
            }
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var limbColor: Color {
        guard !isPlayer else { return Color(red: 0.28, green: 0.38, blue: 0.9) }
        switch kind {
        case .grunt:  return Color(red: 0.7, green: 0.16, blue: 0.2)
        case .brute:  return Color(red: 0.4, green: 0.06, blue: 0.08)
        case .runner: return Color(red: 0.8, green: 0.32, blue: 0.06)
        case .archer: return Color(red: 0.5, green: 0.1, blue: 0.45)
        }
    }

    private var headColor: Color {
        guard !isPlayer else { return Color(red: 0.6, green: 0.72, blue: 1.0) }
        switch kind {
        case .grunt:  return Color(red: 1.0, green: 0.6, blue: 0.6)
        case .brute:  return Color(red: 0.9, green: 0.5, blue: 0.5)
        case .runner: return Color(red: 1.0, green: 0.78, blue: 0.5)
        case .archer: return Color(red: 1.0, green: 0.7, blue: 1.0)
        }
    }

    var body: some View {
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

                weapon
            }
            .frame(width: width, height: width)
            .scaleEffect(bodyScale)
            .scaleEffect(x: facing == .left ? -1 : 1, y: 1)
            .offset(x: lunge)
        }
    }

    // Player + melee enemies wield a katana; archers hold a bow instead.
    @ViewBuilder private var weapon: some View {
        if !isPlayer && kind == .archer {
            // Forward arm + bow (an arc) drawn ahead of the body.
            ZStack {
                Capsule()
                    .fill(limbColor)
                    .frame(width: width * 0.11, height: width * 0.30)
                    .offset(x: width * 0.12, y: width * 0.02)
                BowArc()
                    .stroke(LinearGradient(colors: [Color(white: 0.95), Color(red: 0.7, green: 0.5, blue: 0.3)],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: width * 0.05, lineCap: .round))
                    .frame(width: width * 0.30, height: width * 0.66)
                    .offset(x: width * 0.30, y: -width * 0.02)
                // Bowstring.
                Rectangle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: width * 0.012, height: width * 0.60)
                    .offset(x: width * 0.30, y: -width * 0.02)
            }
            .rotationEffect(.degrees(swing), anchor: .center)
        } else {
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
    }
}

// A four-pointed throwing star (shuriken) inscribed in the bounding rect.
struct ShurikenShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.38
        let points = 4
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = (Double(i) / Double(points * 2)) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: c.x + radius * cos(CGFloat(angle)),
                             y: c.y + radius * sin(CGFloat(angle)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// A simple bow: a vertical arc bowing forward (to the right).
struct BowArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX * 1.6, y: rect.midY))
        return p
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
