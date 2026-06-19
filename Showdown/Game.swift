import Foundation

// MARK: - Core types

enum Facing {
    case left, right

    var step: Int { self == .left ? -1 : 1 }
    var flipped: Facing { self == .left ? .right : .left }
}

enum Phase {
    case playerTurn
    case won
    case lost
}

struct Combatant: Identifiable {
    let id = UUID()
    var isPlayer: Bool
    var hp: Int
    var maxHP: Int
    var attack: Int
    var position: Int
    var facing: Facing

    // Stamina only meaningful for the player.
    var stamina: Int = 0
    var maxStamina: Int = 0

    var isAlive: Bool { hp > 0 }
}

// MARK: - Game state

final class GameState: ObservableObject {

    static let arenaSize = 10

    // Stamina economy
    static let attackCost = 2
    static let moveGain = 1
    static let skipGain = 3
    static let totalWaves = 3

    @Published private(set) var player: Combatant
    @Published private(set) var enemies: [Combatant] = []
    @Published private(set) var wave: Int = 1
    @Published private(set) var phase: Phase = .playerTurn

    // Transient feedback for the UI (cells that just got hit, last log line).
    @Published var flashPositions: Set<Int> = []
    @Published var message: String = ""

    init() {
        player = GameState.makePlayer()
        spawnWave()
    }

    // MARK: Setup

    private static func makePlayer() -> Combatant {
        Combatant(isPlayer: true,
                  hp: 10, maxHP: 10,
                  attack: 3,
                  position: 0,
                  facing: .right,
                  stamina: 10, maxStamina: 10)
    }

    func spawnWave() {
        // Spawn `wave + 1` enemies packed against the right wall, facing the player.
        let count = wave + 1
        var newEnemies: [Combatant] = []
        for i in 0..<count {
            let pos = GameState.arenaSize - 1 - i
            newEnemies.append(Combatant(isPlayer: false,
                                        hp: 3, maxHP: 3,
                                        attack: 2,
                                        position: pos,
                                        facing: .left))
        }
        enemies = newEnemies
        message = "Wave \(wave) of \(GameState.totalWaves)"
    }

    func reset() {
        player = GameState.makePlayer()
        wave = 1
        phase = .playerTurn
        flashPositions = []
        spawnWave()
    }

    // MARK: Queries

    func occupant(at position: Int) -> Combatant? {
        if player.isAlive && player.position == position { return player }
        return enemies.first { $0.isAlive && $0.position == position }
    }

    private func isEmpty(_ position: Int) -> Bool {
        guard position >= 0 && position < GameState.arenaSize else { return false }
        return occupant(at: position) == nil
    }

    var facingTarget: Int { player.position + player.facing.step }

    var canAttack: Bool { phase == .playerTurn && player.stamina >= GameState.attackCost }

    func canMove(_ facing: Facing) -> Bool {
        phase == .playerTurn && isEmpty(player.position + facing.step)
    }

    // MARK: Player actions

    /// Free action — does not cost a turn, does not change stamina.
    func turnPlayer() {
        guard phase == .playerTurn else { return }
        player.facing = player.facing.flipped
    }

    func move(_ facing: Facing) {
        guard phase == .playerTurn, canMove(facing) else { return }
        player.position += facing.step
        gainStamina(GameState.moveGain)
        endPlayerTurn()
    }

    func playerAttack() {
        guard canAttack else { return }
        player.stamina -= GameState.attackCost
        let target = facingTarget
        if let idx = enemies.firstIndex(where: { $0.isAlive && $0.position == target }) {
            enemies[idx].hp -= player.attack
            flash(target)
        }
        endPlayerTurn()
    }

    func skipTurn() {
        guard phase == .playerTurn else { return }
        gainStamina(GameState.skipGain)
        endPlayerTurn()
    }

    private func gainStamina(_ amount: Int) {
        player.stamina = min(player.maxStamina, player.stamina + amount)
    }

    // MARK: Turn resolution

    func endPlayerTurn() {
        enemies.removeAll { !$0.isAlive }

        if enemies.isEmpty {
            advanceWaveOrWin()
            return
        }

        runEnemyTurn()

        if !player.isAlive {
            phase = .lost
            message = "Game Over"
            return
        }

        enemies.removeAll { !$0.isAlive }
        if enemies.isEmpty {
            advanceWaveOrWin()
        }
    }

    private func advanceWaveOrWin() {
        if wave >= GameState.totalWaves {
            phase = .won
            message = "You Win!"
        } else {
            wave += 1
            spawnWave()
        }
    }

    /// Each enemy faces the player, attacks if adjacent, otherwise advances one cell toward them.
    private func runEnemyTurn() {
        // Process nearest-to-player first so a line of enemies shuffles forward cleanly.
        let order = enemies.indices.sorted {
            abs(enemies[$0].position - player.position) < abs(enemies[$1].position - player.position)
        }
        for i in order {
            guard enemies[i].isAlive else { continue }
            let dir: Facing = player.position < enemies[i].position ? .left : .right
            enemies[i].facing = dir
            let ahead = enemies[i].position + dir.step
            if ahead == player.position {
                player.hp -= enemies[i].attack
                flash(player.position)
            } else if isEmpty(ahead) {
                enemies[i].position = ahead
            }
        }
    }

    // MARK: Feedback

    private func flash(_ position: Int) {
        flashPositions.insert(position)
    }

    func clearFlashes() {
        flashPositions.removeAll()
    }
}
