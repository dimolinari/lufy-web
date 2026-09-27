import Foundation

public struct CivilDay: Equatable, Hashable, Codable, Sendable, Comparable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public init?(iso: String) {
        let parts = iso.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: CivilDay, rhs: CivilDay) -> Bool {
        lhs.iso < rhs.iso
    }
}

public struct DayClock: Sendable {
    public var timeZone: TimeZone

    public init(timeZone: TimeZone) {
        self.timeZone = timeZone
    }

    public static let ecuador = DayClock(timeZone: TimeZone(identifier: "America/Guayaquil") ?? TimeZone(secondsFromGMT: -5 * 3600)!)

    public func day(for date: Date) -> CivilDay {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return CivilDay(year: parts.year ?? 1, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public func adding(days: Int, to day: CivilDay) -> CivilDay {
        let noon = date(for: day)
        let shifted = calendar.date(byAdding: .day, value: days, to: noon) ?? noon
        return self.day(for: shifted)
    }

    public func days(from earlier: CivilDay, to later: CivilDay) -> Int {
        let start = date(for: earlier)
        let end = date(for: later)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private func date(for day: CivilDay) -> Date {
        var parts = DateComponents()
        parts.year = day.year
        parts.month = day.month
        parts.day = day.day
        parts.hour = 12
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
