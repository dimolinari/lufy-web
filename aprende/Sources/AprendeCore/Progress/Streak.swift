import Foundation

public struct StreakState: Codable, Equatable, Sendable {
    public var current: Int
    public var best: Int
    public var lastActiveDay: String?

    public init(current: Int, best: Int, lastActiveDay: String?) {
        self.current = current
        self.best = best
        self.lastActiveDay = lastActiveDay
    }

    public static let empty = StreakState(current: 0, best: 0, lastActiveDay: nil)
}

public enum Streak {
    /// El día cuenta una sola vez. Si el último día fue ayer en Ecuador, la racha sigue.
    /// Si hubo un hueco, empieza de nuevo en 1.
    public static func register(_ streak: StreakState, on day: CivilDay, clock: DayClock) -> StreakState {
        guard let lastISO = streak.lastActiveDay, let last = CivilDay(iso: lastISO) else {
            return StreakState(current: 1, best: max(streak.best, 1), lastActiveDay: day.iso)
        }
        if last == day {
            return streak
        }
        let gap = clock.days(from: last, to: day)
        let current = gap == 1 ? streak.current + 1 : 1
        return StreakState(current: current, best: max(streak.best, current), lastActiveDay: day.iso)
    }
}
