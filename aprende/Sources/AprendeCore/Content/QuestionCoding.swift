import Foundation

extension Question: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case prompt
        case explanation
        case options
        case correctOptionId
        case correct
        case items
        case correctOrder
        case acceptedAnswers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let prompt = try container.decode(String.self, forKey: .prompt)
        let explanation = try container.decode(String.self, forKey: .explanation)
        let kind = try container.decode(String.self, forKey: .kind)
        let body: Body
        switch kind {
        case "multipleChoice":
            let options = try container.decode([Choice].self, forKey: .options)
            let correct = try container.decode(String.self, forKey: .correctOptionId)
            body = .multipleChoice(options: options, correctOptionID: correct)
        case "trueFalse":
            let correct = try container.decode(Bool.self, forKey: .correct)
            body = .trueFalse(correct: correct)
        case "order":
            let items = try container.decode([Choice].self, forKey: .items)
            let order = try container.decode([String].self, forKey: .correctOrder)
            body = .order(items: items, correctOrder: order)
        case "fillBlank":
            let answers = try container.decode([String].self, forKey: .acceptedAnswers)
            body = .fillBlank(acceptedAnswers: answers)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Tipo de pregunta desconocido: \(kind)"
            )
        }
        self.init(id: id, prompt: prompt, explanation: explanation, body: body)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(explanation, forKey: .explanation)
        switch body {
        case .multipleChoice(let options, let correctOptionID):
            try container.encode("multipleChoice", forKey: .kind)
            try container.encode(options, forKey: .options)
            try container.encode(correctOptionID, forKey: .correctOptionId)
        case .trueFalse(let correct):
            try container.encode("trueFalse", forKey: .kind)
            try container.encode(correct, forKey: .correct)
        case .order(let items, let correctOrder):
            try container.encode("order", forKey: .kind)
            try container.encode(items, forKey: .items)
            try container.encode(correctOrder, forKey: .correctOrder)
        case .fillBlank(let acceptedAnswers):
            try container.encode("fillBlank", forKey: .kind)
            try container.encode(acceptedAnswers, forKey: .acceptedAnswers)
        }
    }
}
