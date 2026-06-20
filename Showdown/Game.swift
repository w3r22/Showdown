import Foundation

// MARK: - Core types

enum Facing {
    case left, right

    var step: Int { self == .left ? -1 : 1 }
    var flipped: Facing { self == .left ? .right : .left }
}

enum Phase {
    case playerTurn
    case choosingUpgrade
    case won
    case lost
}

enum GameMode {
    case regular, endless
}

// MARK: - Upgrades

/// A between-wave upgrade the player can pick. Closure-based so the model stays Foundation-only.
struct Upgrade: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let apply: (GameState) -> Void
}

enum EnemyKind {
    case grunt, brute, runner, archer
}

struct Combatant: Identifiable {
    let id = UUID()
    var isPlayer: Bool
    var hp: Int
    var maxHP: Int
    var attack: Int
    var position: Int
    var facing: Facing

    // Enemy archetype (ignored for the player).
    var kind: EnemyKind = .grunt

    // Stamina only meaningful for the player.
    var stamina: Int = 0
    var maxStamina: Int = 0

    // Enemy telegraph: true after the enemy winds up, before the strike resolves.
    var windingUp = false

    var isAlive: Bool { hp > 0 }

    // Per-kind tactical ranges. Player values are unused.
    var moveRange: Int {
        switch kind {
        case .grunt, .brute, .archer: return 1
        case .runner: return 2
        }
    }

    var attackRange: Int {
        switch kind {
        case .grunt, .brute, .runner: return 1
        case .archer: return 3
        }
    }
}

// MARK: - Game state

final class GameState: ObservableObject {

    static let arenaSize = 10

    // Stamina economy
    static let throwCost = 3
    static let throwDamage = 2
    static let moveGain = 1
    static let skipGain = 3
    static let totalWaves = 3

    // Persisted Endless high score (best number of waves cleared).
    private static let endlessHighScoreKey = "endlessHighScore"
    static var endlessHighScore: Int {
        UserDefaults.standard.integer(forKey: endlessHighScoreKey)
    }

    let mode: GameMode

    // Instance so it can be lowered by an upgrade.
    @Published private(set) var attackCost = 2

    @Published private(set) var player: Combatant
    @Published private(set) var enemies: [Combatant] = []
    @Published private(set) var wave: Int = 1
    @Published private(set) var phase: Phase = .playerTurn

    // Number of waves fully cleared (the Endless score).
    @Published private(set) var score: Int = 0

    // The 3 upgrades offered between waves (populated when phase == .choosingUpgrade).
    @Published private(set) var offeredUpgrades: [Upgrade] = []

    // Transient feedback for the UI (cells that just got hit, last log line).
    @Published var flashPositions: Set<Int> = []
    @Published var message: String = ""

    // Increments whenever the player attacks, so the UI can play a lunge/swing.
    @Published private(set) var playerAttackPulse: Int = 0

    // Increments whenever the player throws, so the UI can fly a projectile.
    @Published private(set) var throwPulse: Int = 0
    // The cells the last thrown shuriken traveled between (from player, to target/wall).
    @Published private(set) var lastThrow: (from: Int, to: Int)? = nil

    init(mode: GameMode = .regular) {
        self.mode = mode
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

    /// Builds an enemy of the given kind, with its per-kind stats, against the right side.
    static func makeEnemy(kind: EnemyKind, position: Int) -> Combatant {
        let hp: Int
        let atk: Int
        switch kind {
        case .grunt:  hp = 3; atk = 2
        case .brute:  hp = 6; atk = 3
        case .runner: hp = 2; atk = 1
        case .archer: hp = 2; atk = 2
        }
        return Combatant(isPlayer: false,
                         hp: hp, maxHP: hp,
                         attack: atk,
                         position: position,
                         facing: .left,
                         kind: kind)
    }

    func spawnWave() {
        // Escalating mix of kinds. Early waves stay gentle; later waves add specialists.
        let kinds: [EnemyKind]
        switch wave {
        case 1:  kinds = [.grunt, .grunt]
        case 2:  kinds = [.grunt, .grunt, .brute, .runner]
        case 3:  kinds = [.grunt, .brute, .runner, .archer]
        default:
            // Endless past wave 3: keep ramping. Regular never reaches here (it wins at wave 3).
            kinds = GameState.endlessKinds(for: wave)
        }

        // Pack against the right wall (rightmost first) without overlapping.
        var newEnemies: [Combatant] = []
        for (i, kind) in kinds.enumerated() {
            let pos = GameState.arenaSize - 1 - i
            guard pos > 0 else { break }
            newEnemies.append(GameState.makeEnemy(kind: kind, position: pos))
        }
        enemies = newEnemies
        message = mode == .endless
            ? "Wave \(wave)"
            : "Wave \(wave) of \(GameState.totalWaves)"
    }

    /// Endless difficulty curve for waves > 3: grow the count and weight toward
    /// tougher kinds (brute/archer) as the wave climbs, capped so they fit the arena.
    private static func endlessKinds(for wave: Int) -> [EnemyKind] {
        // Count grows by 1 every 2 waves past 3, starting at 5, capped to leave room for the player.
        let maxEnemies = arenaSize - 2 // Cap count to leave the left cells clear; the `pos > 0` guard in spawnWave is the hard collision stop.
        let count = min(maxEnemies, 5 + (wave - 4) / 2)

        // As the wave climbs, lean harder on brutes and archers.
        let tier = wave - 3
        var kinds: [EnemyKind] = []
        for i in 0..<count {
            // Cycle a mix that gets meaner with the tier.
            switch (i + tier) % 4 {
            case 0: kinds.append(.brute)
            case 1: kinds.append(.archer)
            case 2: kinds.append(tier >= 3 ? .brute : .grunt)
            default: kinds.append(.runner)
            }
        }
        return kinds
    }

    func reset() {
        // Restart the same mode.
        player = GameState.makePlayer()
        attackCost = 2
        wave = 1
        score = 0
        phase = .playerTurn
        offeredUpgrades = []
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

    /// The player's cell while any alive enemy is winding up to strike, else nil.
    var threatenedCell: Int? {
        enemies.contains { $0.isAlive && $0.windingUp } ? player.position : nil
    }

    var canAttack: Bool { phase == .playerTurn && player.stamina >= attackCost }

    var canThrow: Bool { phase == .playerTurn && player.stamina >= GameState.throwCost }

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
        playerAttackPulse &+= 1
        player.stamina -= attackCost
        let target = facingTarget
        if let idx = enemies.firstIndex(where: { $0.isAlive && $0.position == target }) {
            enemies[idx].hp -= player.attack
            flash(target)
        }
        endPlayerTurn()
    }

    /// Ranged attack: spend stamina, fly a shuriken along the facing line and hit the first
    /// alive enemy it reaches (cosmetically traveling to the wall if it hits nothing).
    func throwShuriken() {
        guard canThrow else { return }
        player.stamina -= GameState.throwCost

        let dir = player.facing.step
        var pos = player.position + dir
        var target = player.position
        // Default cosmetic target: the last in-bounds cell along the facing direction.
        while pos >= 0 && pos < GameState.arenaSize {
            target = pos
            if let idx = enemies.firstIndex(where: { $0.isAlive && $0.position == pos }) {
                enemies[idx].hp -= GameState.throwDamage
                flash(pos)
                break
            }
            pos += dir
        }

        lastThrow = (from: player.position, to: target)
        throwPulse &+= 1
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
            recordLoss()
            return
        }

        enemies.removeAll { !$0.isAlive }
        if enemies.isEmpty {
            advanceWaveOrWin()
        }
    }

    /// Transition to the lost phase, persisting the Endless high score if beaten.
    private func recordLoss() {
        phase = .lost
        message = "Game Over"
        if mode == .endless && score > GameState.endlessHighScore {
            UserDefaults.standard.set(score, forKey: GameState.endlessHighScoreKey)
        }
    }

    private func advanceWaveOrWin() {
        // A wave was just fully cleared.
        score += 1

        if mode == .regular && wave >= GameState.totalWaves {
            phase = .won
            message = "You Win!"
        } else {
            // Endless never wins; both modes offer upgrades before the next wave.
            offeredUpgrades = GameState.upgradePool().shuffled().prefix(3).map { $0 }
            phase = .choosingUpgrade
            message = "Choose an upgrade"
        }
    }

    // MARK: Upgrades

    /// The full pool of between-wave upgrades. Three are sampled at random each time.
    private static func upgradePool() -> [Upgrade] {
        [
            Upgrade(title: "+2 Max HP", detail: "Raise max HP by 2 and heal 2.") { game in
                game.player.maxHP += 2
                game.player.hp = min(game.player.maxHP, game.player.hp + 2)
            },
            Upgrade(title: "+1 Attack", detail: "Melee hits deal 1 more damage.") { game in
                game.player.attack += 1
            },
            Upgrade(title: "+2 Max Stamina", detail: "Raise max stamina by 2 and gain 2.") { game in
                game.player.maxStamina += 2
                game.player.stamina = min(game.player.maxStamina, game.player.stamina + 2)
            },
            Upgrade(title: "Cheaper Attacks", detail: "Attack stamina cost −1 (min 1).") { game in
                game.attackCost = max(1, game.attackCost - 1)
            },
            Upgrade(title: "Full Heal", detail: "Restore HP to full.") { game in
                game.player.hp = game.player.maxHP
            },
        ]
    }

    /// Apply the chosen upgrade, then spawn the next wave and resume play.
    func chooseUpgrade(_ upgrade: Upgrade) {
        guard phase == .choosingUpgrade else { return }
        upgrade.apply(self)
        offeredUpgrades = []
        wave += 1
        spawnWave()
        phase = .playerTurn
    }

    /// True if `attacker` can hit the player: the player is within `attackRange` along the
    /// attacker's facing line, with no other combatant blocking the path (line-of-fire).
    private func hasShot(_ attacker: Combatant) -> Bool {
        let dir = attacker.facing.step
        var pos = attacker.position + dir
        var distance = 1
        while distance <= attacker.attackRange {
            guard pos >= 0 && pos < GameState.arenaSize else { return false }
            if pos == player.position { return true }
            // Any other combatant in the way blocks the line.
            if occupant(at: pos) != nil { return false }
            pos += dir
            distance += 1
        }
        return false
    }

    /// Each enemy faces the player, then either resolves a telegraphed strike, winds up
    /// (when it has a shot), or advances toward the player within its movement range.
    /// Archers hold distance instead of closing once the player is in range.
    private func runEnemyTurn() {
        // Process nearest-to-player first so a line of enemies shuffles forward cleanly.
        let order = enemies.indices.sorted {
            abs(enemies[$0].position - player.position) < abs(enemies[$1].position - player.position)
        }
        for i in order {
            guard enemies[i].isAlive else { continue }
            let dir: Facing = player.position < enemies[i].position ? .left : .right
            enemies[i].facing = dir

            if enemies[i].windingUp {
                // Resolve the telegraphed strike: only lands if the player is still in range/line.
                if hasShot(enemies[i]) {
                    player.hp -= enemies[i].attack
                    flash(player.position)
                }
                enemies[i].windingUp = false
                continue
            }

            if hasShot(enemies[i]) {
                // In range with a clear line — telegraph; deal no damage yet.
                enemies[i].windingUp = true
                continue
            }

            // Out of range: advance toward the player, up to moveRange cells. An archer that
            // already has a shot wouldn't reach here; if it has none it closes like the rest.
            var steps = enemies[i].moveRange
            while steps > 0 {
                let ahead = enemies[i].position + dir.step
                guard isEmpty(ahead) else { break }
                enemies[i].position = ahead
                steps -= 1
                // Stop early once a shot opens up, so a runner doesn't overrun the player.
                if hasShot(enemies[i]) { break }
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
