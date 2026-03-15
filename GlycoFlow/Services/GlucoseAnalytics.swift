//
//  GlucoseAnalytics.swift
//  GlycoFlow
//

import Foundation

// MARK: - Time In Range Result
struct TimeInRangeResult {
    let inRange: Double
    let belowRange: Double
    let aboveRange: Double
    let veryHigh: Double

    var inRangePercent: Int { Int(inRange * 100) }
    var belowRangePercent: Int { Int(belowRange * 100) }
    var aboveRangePercent: Int { Int(aboveRange * 100) }
    var veryHighPercent: Int { Int(veryHigh * 100) }
}

// MARK: - Analytics Summary
struct GlucoseAnalyticsSummary {
    let average: Double
    let median: Double
    let standardDeviation: Double
    let coefficientOfVariation: Double
    let min: Double
    let max: Double
    let readingCount: Int
    let timeInRange: TimeInRangeResult
    let trend: GlucoseTrendDirection
}

enum GlucoseTrendDirection {
    case risingFast, rising, stable, falling, fallingFast

    var icon: String {
        switch self {
        case .risingFast: return "arrow.up.right.circle.fill"
        case .rising: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .falling: return "arrow.down.right"
        case .fallingFast: return "arrow.down.right.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .risingFast: return "Rising Quickly"
        case .rising: return "Rising"
        case .stable: return "Stable"
        case .falling: return "Falling"
        case .fallingFast: return "Falling Quickly"
        }
    }
}

// MARK: - Glucose Analytics Service
final class GlucoseAnalytics {
    static let shared = GlucoseAnalytics()

    func computeSummary(
        readings: [GlucoseReading],
        targetLow: Double = 70,
        targetHigh: Double = 180
    ) -> GlucoseAnalyticsSummary {
        guard !readings.isEmpty else {
            return GlucoseAnalyticsSummary(
                average: 0, median: 0, standardDeviation: 0,
                coefficientOfVariation: 0, min: 0, max: 0,
                readingCount: 0,
                timeInRange: TimeInRangeResult(inRange: 0, belowRange: 0, aboveRange: 0, veryHigh: 0),
                trend: .stable
            )
        }

        let values = readings.map { $0.valueInMgdL }
        let avg = values.reduce(0, +) / Double(values.count)
        let sorted = values.sorted()
        let median = sorted[sorted.count / 2]
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        let cv = avg > 0 ? (stdDev / avg) * 100 : 0

        let inRange = Double(values.filter { $0 >= targetLow && $0 <= targetHigh }.count) / Double(values.count)
        let below = Double(values.filter { $0 < targetLow }.count) / Double(values.count)
        let above = Double(values.filter { $0 > targetHigh && $0 <= 250 }.count) / Double(values.count)
        let veryHigh = Double(values.filter { $0 > 250 }.count) / Double(values.count)

        let tir = TimeInRangeResult(inRange: inRange, belowRange: below, aboveRange: above, veryHigh: veryHigh)
        let trend = computeTrend(readings: readings)

        return GlucoseAnalyticsSummary(
            average: avg,
            median: median,
            standardDeviation: stdDev,
            coefficientOfVariation: cv,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            readingCount: readings.count,
            timeInRange: tir,
            trend: trend
        )
    }

    private func computeTrend(readings: [GlucoseReading]) -> GlucoseTrendDirection {
        let recent = readings.sorted { $0.timestamp > $1.timestamp }.prefix(5)
        guard recent.count >= 3 else { return .stable }

        let values = recent.map { $0.valueInMgdL }
        let firstHalf = values.suffix(values.count / 2).reduce(0, +) / Double(values.count / 2)
        let lastHalf = values.prefix(values.count / 2).reduce(0, +) / Double(values.count / 2)
        let delta = lastHalf - firstHalf

        switch delta {
        case let d where d > 30: return .risingFast
        case let d where d > 10: return .rising
        case let d where d < -30: return .fallingFast
        case let d where d < -10: return .falling
        default: return .stable
        }
    }

    func dailyAverages(readings: [GlucoseReading], days: Int = 30) -> [(date: Date, average: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(date: Date, average: Double)] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayReadings = readings.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            if !dayReadings.isEmpty {
                let avg = dayReadings.map { $0.valueInMgdL }.reduce(0, +) / Double(dayReadings.count)
                result.append((date: date, average: avg))
            }
        }
        return result
    }

    func weeklyAverages(readings: [GlucoseReading]) -> [(week: Date, average: Double)] {
        let calendar = Calendar.current
        var weeklyData: [Date: [Double]] = [:]

        for reading in readings {
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reading.timestamp)) else { continue }
            weeklyData[weekStart, default: []].append(reading.valueInMgdL)
        }

        return weeklyData.map { (week, values) in
            (week: week, average: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.week < $1.week }
    }
}
