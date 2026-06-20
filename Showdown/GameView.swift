import SwiftUI

struct GameView: View {
    @StateObject private var game = GameState()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.18),
                                    Color(red: 0.04, green: 0.05, blue: 0.09)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

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
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    CellView(index: i,
                             width: cellW,
                             occupant: game.occupant(at: i),
                             isTarget: game.facingTarget == i,
                             isFlashing: game.flashPositions.contains(i))
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
        .frame(height: 150)
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
                ActionButton(title: "Attack", systemImage: "burst.fill", subtitle: "3 dmg · −2 stam",
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

    var body: some View {
        VStack(spacing: 3) {
            // Floating bars area above the sprite.
            barsArea
                .frame(height: 16)

            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(cellFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isTarget ? Color.yellow.opacity(0.9) : Color.white.opacity(0.08),
                                    lineWidth: isTarget ? 2 : 1)
                    )
                sprite
            }
            .frame(width: width, height: width)
        }
    }

    private var cellFill: Color {
        if isFlashing { return Color.red.opacity(0.55) }
        return index.isMultiple(of: 2) ? Color.white.opacity(0.05) : Color.white.opacity(0.025)
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
            if c.isPlayer {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: [Color(red: 0.35, green: 0.7, blue: 1.0),
                                                Color(red: 0.1, green: 0.45, blue: 0.95)],
                                       startPoint: .top, endPoint: .bottom))
                    Image(systemName: c.facing == .right ? "chevron.right" : "chevron.left")
                        .font(.system(size: width * 0.42, weight: .black))
                        .foregroundStyle(.white)
                        .offset(x: c.facing == .right ? width * 0.06 : -width * 0.06)
                }
                .padding(width * 0.14)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(
                        LinearGradient(colors: [Color(red: 0.95, green: 0.4, blue: 0.4),
                                                Color(red: 0.8, green: 0.15, blue: 0.2)],
                                       startPoint: .top, endPoint: .bottom))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: width * 0.34, weight: .black))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(width * 0.18)
            }
        }
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
            Capsule().fill(Color.black.opacity(0.5))
            Capsule().fill(color)
                .frame(width: max(0, width * fraction))
        }
        .frame(width: width, height: 5)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(tint.opacity(enabled ? 0.85 : 0.25), in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
    }
}

#Preview {
    GameView()
}
