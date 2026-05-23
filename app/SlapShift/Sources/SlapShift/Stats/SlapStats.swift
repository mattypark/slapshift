// SlapStats — lightweight usage tracking for the home dashboard.
//
// Persisted in UserDefaults (no DB, no telemetry off-device). Incremented
// by AppDelegate every time a real slap fires a mode. The home view reads
// these to render the stat cards (total slaps, time saved, day streak,
// avg slaps/day).
//
// Why UserDefaults vs a file:
//   - Tiny scalar payload (5 fields, < 100 bytes)
//   - Already-existing storage we use for onboarding state
//   - Survives app updates; cleared on Sign Out (handled by AppDelegate)
//
// Day-streak semantics: a "day" is the user's local calendar day. We bump
// the streak when today != lastSlapDay AND today is exactly one calendar
// day after lastSlapDay. Any gap larger than that resets to 1.

import Foundation
import SwiftUI

@MainActor
final class SlapStats: ObservableObject {

    // Keys
    private static let kTotal       = "stats.totalSlaps"
    private static let kActions     = "stats.actionsTriggered"
    private static let kFirstDay    = "stats.firstActiveDay"  // yyyy-MM-dd
    private static let kLastDay     = "stats.lastActiveDay"   // yyyy-MM-dd
    private static let kStreak      = "stats.dayStreak"
    private static let kDaysActive  = "stats.daysActive"

    @Published private(set) var totalSlaps: Int
    @Published private(set) var actionsTriggered: Int
    @Published private(set) var dayStreak: Int
    @Published private(set) var daysActive: Int

    private let defaults: UserDefaults
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.totalSlaps = defaults.integer(forKey: Self.kTotal)
        self.actionsTriggered = defaults.integer(forKey: Self.kActions)
        self.dayStreak = defaults.integer(forKey: Self.kStreak)
        self.daysActive = defaults.integer(forKey: Self.kDaysActive)
    }

    // MARK: - Derived stats

    /// Honest, low-ball estimate: 3 seconds saved per action (open app, quit
    /// app, or open URL). Don't claim minutes for things we didn't actually
    /// time.
    var timeSavedSeconds: Int { actionsTriggered * 3 }

    /// Formatted as "12 sec" / "4 min" / "1.2 hr" — picks the smallest unit
    /// that produces a number ≥ 1.
    var timeSavedDisplay: String {
        let s = timeSavedSeconds
        if s < 60 { return "\(s) sec" }
        let mins = Double(s) / 60.0
        if mins < 60 { return "\(Int(mins.rounded())) min" }
        let hrs = mins / 60.0
        return String(format: "%.1f hr", hrs)
    }

    var avgSlapsPerDay: Int {
        guard daysActive > 0 else { return 0 }
        return Int((Double(totalSlaps) / Double(daysActive)).rounded())
    }

    // MARK: - Mutations

    /// Called when a slap successfully fires a mode. `actionCount` is the
    /// number of apps/URLs/quits that mode performed — used to estimate
    /// time saved.
    func recordSlap(actionCount: Int) {
        totalSlaps += 1
        actionsTriggered += actionCount
        bumpDayBookkeeping()
        defaults.set(totalSlaps,       forKey: Self.kTotal)
        defaults.set(actionsTriggered, forKey: Self.kActions)
        defaults.set(dayStreak,        forKey: Self.kStreak)
        defaults.set(daysActive,       forKey: Self.kDaysActive)
    }

    /// Wipe all stats. Used on Sign Out so the next user starts fresh.
    func reset() {
        totalSlaps = 0
        actionsTriggered = 0
        dayStreak = 0
        daysActive = 0
        defaults.removeObject(forKey: Self.kTotal)
        defaults.removeObject(forKey: Self.kActions)
        defaults.removeObject(forKey: Self.kStreak)
        defaults.removeObject(forKey: Self.kDaysActive)
        defaults.removeObject(forKey: Self.kFirstDay)
        defaults.removeObject(forKey: Self.kLastDay)
    }

    // MARK: - Day streak logic

    private func bumpDayBookkeeping() {
        let today = dayFormatter.string(from: Date())
        let last = defaults.string(forKey: Self.kLastDay)

        if last == today {
            // Already counted today — streak and daysActive unchanged.
            return
        }

        // Brand new day. daysActive always bumps; streak depends on gap.
        daysActive += 1

        if let last = last, let gap = daysBetween(last, today) {
            dayStreak = (gap == 1) ? (dayStreak + 1) : 1
        } else {
            // First slap ever, or unparseable record → start at 1.
            dayStreak = 1
            defaults.set(today, forKey: Self.kFirstDay)
        }

        defaults.set(today, forKey: Self.kLastDay)
    }

    private func daysBetween(_ a: String, _ b: String) -> Int? {
        guard let da = dayFormatter.date(from: a),
              let db = dayFormatter.date(from: b) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        return cal.dateComponents([.day], from: da, to: db).day
    }
}
