import XCTest
@testable import AprendeCore

final class FigureTests: XCTestCase {
    func testScrubLandsOnEndsAndMiddle() {
        XCTAssertEqual(ChartProbe.index(at: 0, count: 5), 0)
        XCTAssertEqual(ChartProbe.index(at: 1, count: 5), 4)
        XCTAssertEqual(ChartProbe.index(at: 0.5, count: 5), 2)
        XCTAssertEqual(ChartProbe.index(at: -1, count: 5), 0)
        XCTAssertEqual(ChartProbe.index(at: 2, count: 3), 2)
    }

    func testSpanishFormatUsesComma() {
        XCTAssertEqual(ChartFormat.spanish(96.1, decimals: 2), "96,10")
        XCTAssertEqual(ChartFormat.spanish(-1.94, decimals: 2), "-1,94")
        XCTAssertEqual(ChartFormat.spanish(123.8, decimals: 1), "123,8")
    }

    func testCompoundInterestWithoutRateIsJustContributions() {
        let flat = CompoundInterest.balances(principal: 100, annualRate: 0, years: 1, monthlyContribution: 10)
        XCTAssertEqual(flat.last?.value ?? 0, 220, accuracy: 0.001)
        let still = CompoundInterest.balances(principal: 80, annualRate: 0, years: 2, monthlyContribution: 0)
        XCTAssertEqual(still.last?.value ?? 0, 80, accuracy: 0.001)
    }

    func testCompoundInterestGrowsAndClampRejectsExtremes() {
        let grown = CompoundInterest.balances(principal: 100, annualRate: 1, years: 1, monthlyContribution: 0)
        let expected = 100 * pow(1 + 1.0 / 12, 12)
        XCTAssertEqual(grown.last?.value ?? 0, expected, accuracy: 0.001)
        let clamped = CompoundInterest.clamped(principal: -5, annualPercent: 80, years: 0, monthly: 9_000)
        XCTAssertEqual(clamped.principal, 0)
        XCTAssertEqual(clamped.annualRate, 0.2, accuracy: 0.0001)
        XCTAssertEqual(clamped.years, 1)
        XCTAssertEqual(clamped.monthly, 5_000)
    }

    func testExampleBannerAndOpenLicenses() {
        let example = StudyDataset(
            id: "demo",
            title: "Demo",
            kind: "line",
            unit: "%",
            decimals: 1,
            exampleData: true,
            diagram: false,
            note: "no usar",
            source: DataCitation(institution: "Ninguna", dataset: "Inventado", date: "sin fecha", url: ""),
            points: [YearPoint(year: 2000, value: 1), YearPoint(year: 2001, value: 2)]
        )
        XCTAssertTrue(DataCaution.caption(example).contains(DataCaution.exampleBanner))
        XCTAssertTrue(OpenLicense.isAllowed("CC BY-SA 4.0"))
        XCTAssertTrue(OpenLicense.isAllowed("CC BY 2.0"))
        XCTAssertTrue(OpenLicense.isAllowed("Public domain"))
        XCTAssertFalse(OpenLicense.isAllowed("CC BY-NC 4.0"))
        XCTAssertFalse(OpenLicense.isAllowed("CC BY-ND 4.0"))
    }

    func testOldProgressWithoutNoticesStillDecodes() throws {
        let json = """
        {"totalXP":3,"streak":{"current":1,"best":1,"lastActiveDay":"2026-09-26"},"settings":{"playbackSpeed":1},"lessons":{},"reviews":{}}
        """.data(using: .utf8)!
        let state = try JSONDecoder().decode(LearnerState.self, from: json)
        XCTAssertEqual(state.totalXP, 3)
        XCTAssertTrue(state.acknowledgedNotices.isEmpty)
    }
}
