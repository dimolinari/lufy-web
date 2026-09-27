import Foundation
import SwiftData
import AprendeCore

@Model
final class LearnerRecord {
    var recordID: String
    var payload: Data

    init(recordID: String, payload: Data) {
        self.recordID = recordID
        self.payload = payload
    }
}

@MainActor
@Observable
final class LearnerRepository {
    private let context: ModelContext
    private let record: LearnerRecord
    private(set) var state: LearnerState
    let engine = ProgressEngine()

    init(context: ModelContext) {
        self.context = context
        let descriptor = FetchDescriptor<LearnerRecord>(
            predicate: #Predicate { $0.recordID == "local" }
        )
        if let existing = try? context.fetch(descriptor).first,
           let decoded = try? JSONDecoder().decode(LearnerState.self, from: existing.payload) {
            record = existing
            state = decoded
        } else {
            let fresh = LearnerState.empty
            let data = (try? JSONEncoder().encode(fresh)) ?? Data()
            let created = LearnerRecord(recordID: "local", payload: data)
            context.insert(created)
            try? context.save()
            record = created
            state = fresh
        }
    }

    func replace(_ newState: LearnerState) {
        state = newState
        guard let data = try? JSONEncoder().encode(newState) else { return }
        record.payload = data
        try? context.save()
    }
}
