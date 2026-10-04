import XCTest
@testable import AprendeCore

final class AsambleaFeedTests: XCTestCase {
    func testSHA256KnownAnswers() {
        XCTAssertEqual(
            SHA256.hex(of: Data()),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        XCTAssertEqual(
            SHA256.hex(of: Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testRefreshSkipsTheSameEcuadorDay() {
        XCTAssertEqual(FeedRefreshPlan.decide(lastSuccessDay: nil, today: "2026-09-27"), .download)
        XCTAssertEqual(FeedRefreshPlan.decide(lastSuccessDay: "2026-09-26", today: "2026-09-27"), .download)
        XCTAssertEqual(FeedRefreshPlan.decide(lastSuccessDay: "2026-09-27", today: "2026-09-27"), .useCached)
    }

    func testExampleFeedMatchesManifestAndStaysFictional() throws {
        let payload = try Data(contentsOf: sharedFile("asamblea.json"))
        let bundled = try Data(contentsOf: feedResource("asamblea.json"))
        XCTAssertEqual(payload, bundled)
        let manifest = try PublicRoleGate.validate(manifest: Data(contentsOf: sharedFile("manifest.json")))
        let digest = try XCTUnwrap(manifest.file(named: AsambleaSchema.payloadFile)?.sha256)
        XCTAssertTrue(SHA256.matches(data: payload, expectedHex: digest))
        let directory = try PublicRoleGate.validate(data: payload)
        XCTAssertTrue(directory.exampleData)
        XCTAssertEqual(directory.legislators(in: "Guayas").count, 2)
        XCTAssertEqual(directory.legislators(in: "Nacional").count, 1)
        XCTAssertEqual(directory.legislators(in: "Exterior").count, 1)
        XCTAssertTrue(directory.legislators(in: "Loja").isEmpty)
        XCTAssertEqual(FeedStamp.label(updatedAt: directory.updatedAt), "Actualizado: 27 de septiembre de 2026")
        XCTAssertEqual(try FeedLibrary.loadBundled().legislators.count, directory.legislators.count)
        for person in directory.legislators {
            XCTAssertTrue(person.publicName.contains("Ejemplo"))
            XCTAssertNil(person.photo)
        }
    }

    func testGateRejectsJudgmentsIdentifiersAndClosedPhotos() throws {
        let payload = try Data(contentsOf: sharedFile("asamblea.json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object["note"] = "testaferro"
        try assertRejected(object)

        object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object["cedula"] = "no"
        try assertRejected(object)

        object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object["note"] = "0912345678"
        try assertRejected(object)

        object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        var people = try XCTUnwrap(object["legislators"] as? [[String: Any]])
        people[0]["photo"] = ["url": "https://example.invalid/a.jpg", "author": "", "license": "CC BY-NC 4.0", "license_url": "", "source_url": ""]
        object["legislators"] = people
        try assertRejected(object)
    }

    private func assertRejected(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try PublicRoleGate.validate(data: data))
    }

    private func sharedFile(_ name: String) -> URL {
        workspaceRoot().appendingPathComponent("data/app/v1").appendingPathComponent(name)
    }

    private func feedResource(_ name: String) -> URL {
        workspaceRoot()
            .appendingPathComponent("aprende/Sources/AprendeCore/Resources/Feed")
            .appendingPathComponent(name)
    }

    private func workspaceRoot() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
