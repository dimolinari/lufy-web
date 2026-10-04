import XCTest
@testable import AprendeCore

final class ShareTests: XCTestCase {
    func testStoryCardsStayFactualAndSizedForStories() throws {
        let brand = try Brand.bundled()
        let streak = try XCTUnwrap(ShareCardBuilder.streak(days: 7, appName: brand.appName, inviteURL: ""))
        XCTAssertEqual(streak.width, ShareCanvas.storyWidth)
        XCTAssertEqual(streak.height, ShareCanvas.storyHeight)
        XCTAssertEqual(streak.width, 1080)
        XCTAssertEqual(streak.height, 1920)
        XCTAssertNil(ShareCardBuilder.streak(days: 2, appName: brand.appName, inviteURL: ""))
        XCTAssertTrue(ShareCopyGate.isClean(streak))
        XCTAssertTrue(streak.qrPayload == brand.appName)

        let library = try FigureLibrary.loadBundled()
        let inflation = try XCTUnwrap(library.dataset(id: "inflacion-anual"))
        let learned = ShareCardBuilder.learnedToday(dataset: inflation, appName: brand.appName, inviteURL: "https://ejemplo.invalid/lufy")
        XCTAssertEqual(learned.headline, ShareCardBuilder.learnedHeadline)
        XCTAssertEqual(learned.evidence, .confirmado)
        XCTAssertFalse(learned.exampleData)
        XCTAssertTrue(learned.sourceLine.contains("Banco Mundial"))
        XCTAssertFalse(learned.points.isEmpty)
        XCTAssertEqual(learned.qrPayload, "https://ejemplo.invalid/lufy")
        XCTAssertTrue(ShareCopyGate.isClean(learned))

        var invented = inflation
        invented.exampleData = true
        let sampleChart = ShareCardBuilder.learnedToday(dataset: invented, appName: brand.appName, inviteURL: "")
        XCTAssertTrue(sampleChart.exampleData)
        XCTAssertNil(sampleChart.evidence)
        XCTAssertEqual(sampleChart.labelText, DataCaution.exampleBanner)
        XCTAssertTrue(sampleChart.sourceLine.contains(DataCaution.exampleBanner))

        let directory = try FeedLibrary.loadBundled()
        let vote = ShareCardBuilder.provinceVote(district: "Pichincha", directory: directory, appName: brand.appName, inviteURL: "")
        XCTAssertEqual(vote.headline, ShareCardBuilder.provinceHeadline)
        XCTAssertTrue(vote.exampleData)
        XCTAssertNil(vote.evidence)
        XCTAssertEqual(vote.labelText, DataCaution.exampleBanner)
        XCTAssertTrue(vote.sourceLine.contains("Acta de ejemplo, no oficial, 12 de septiembre de 2026"))
        XCTAssertTrue(vote.body.contains("Lucía Ejemplo Andes"))
        XCTAssertTrue(vote.body.contains("Abstención"))
        XCTAssertTrue(ShareCopyGate.isClean(vote))

        let invite = ShareCardBuilder.invite(appName: brand.appName, inviteURL: "https://ejemplo.invalid/lufy")
        XCTAssertTrue(invite.detail.contains("https://ejemplo.invalid/lufy"))
        XCTAssertTrue(invite.message.contains(brand.appName))
        XCTAssertTrue(ShareCopyGate.isClean(invite))

        var accused = invite
        accused.body = "Esta persona es corrupta."
        XCTAssertFalse(ShareCopyGate.isClean(accused))
    }

    func testSubscriptionStaysOffAndCoreLessonsStayFree() throws {
        let brand = try Brand.bundled()
        XCTAssertFalse(brand.storeKit.subscriptionsEnabled)
        XCTAssertEqual(
            brand.storeKit.subscriptionProductIds,
            ["com.lufy.aprende.plus.monthly", "com.lufy.aprende.plus.yearly"]
        )
        XCTAssertTrue(brand.storeKit.activeProductIDs.isEmpty)
        var enabled = brand.storeKit
        enabled.subscriptionsEnabled = true
        XCTAssertEqual(enabled.activeProductIDs, brand.storeKit.subscriptionProductIds)

        let catalog = try ContentLoader.loadBundled()
        for course in catalog.courses {
            XCTAssertEqual(course.offeringKind, .core, course.id)
            XCTAssertEqual(course.access, .free, course.id)
        }
        let offerings = Set(catalog.planned.map(\.offeringKind))
        XCTAssertTrue(offerings.contains(.extra))
        XCTAssertTrue(offerings.contains(.earlyData))
        XCTAssertTrue(offerings.contains(.narrated))

        let early = course(id: "nuevo", offering: CourseOffering.earlyData.rawValue, access: .free)
        let narrated = course(id: "voz", offering: CourseOffering.narrated.rawValue, access: .free)
        let extra = course(id: "extra", offering: CourseOffering.extra.rawValue, access: .premium)
        let core = course(id: "nucleo", offering: nil, access: .free)
        XCTAssertFalse(Entitlements.freeOnly.canOpen(early))
        XCTAssertFalse(Entitlements.freeOnly.canOpen(narrated))
        XCTAssertFalse(Entitlements.freeOnly.canOpen(extra))
        XCTAssertTrue(Entitlements.freeOnly.canOpen(core))
        let plus = Entitlements(premium: true)
        XCTAssertTrue(plus.canOpen(early))
        XCTAssertTrue(plus.canOpen(narrated))
        XCTAssertTrue(plus.canOpen(extra))

        let storekit = try String(contentsOf: storeKitFile(), encoding: .utf8)
        for identifier in brand.storeKit.subscriptionProductIds {
            XCTAssertTrue(storekit.contains(identifier), identifier)
        }
        XCTAssertTrue(storekit.contains("RecurringSubscription"))
    }

    private func course(id: String, offering: String?, access: CourseAccess) -> Course {
        Course(
            id: id,
            title: id,
            summary: id,
            access: access,
            offering: offering,
            units: []
        )
    }

    private func storeKitFile() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Products.storekit")
    }
}
