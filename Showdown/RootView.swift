import SwiftUI

/// Top-level navigation: the main menu, or an active game in a chosen mode.
struct RootView: View {
    private enum Screen {
        case menu
        case playing(GameMode)
    }

    @State private var screen: Screen = .menu

    var body: some View {
        switch screen {
        case .menu:
            MainMenuView { mode in
                withAnimation { screen = .playing(mode) }
            }
        case .playing(let mode):
            GameView(mode: mode) {
                withAnimation { screen = .menu }
            }
        }
    }
}

// MARK: - Main menu

struct MainMenuView: View {
    /// Called with the chosen mode when the player starts a game.
    let onSelect: (GameMode) -> Void

    var body: some View {
        ZStack {
            background

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Text("SHOWDOWN")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(6)
                    if let appVersion {
                        Text("v\(appVersion)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                VStack(spacing: 14) {
                    MenuButton(title: "Regular",
                               subtitle: "Clear 3 waves to win",
                               tint: .blue) {
                        onSelect(.regular)
                    }
                    MenuButton(title: "Endless",
                               subtitle: "Survive as long as you can",
                               tint: .purple) {
                        onSelect(.endless)
                    }
                }
                .frame(maxWidth: 320)

                Text("Endless best: \(GameState.endlessHighScore) waves")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.22),
                                    Color(red: 0.05, green: 0.06, blue: 0.11),
                                    Color(red: 0.02, green: 0.03, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.clear, Color.black.opacity(0.55)],
                           center: .center, startRadius: 120, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Menu button

struct MenuButton: View {
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.7)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.35), radius: 8, y: 4)
        }
    }
}

#Preview {
    RootView()
}
