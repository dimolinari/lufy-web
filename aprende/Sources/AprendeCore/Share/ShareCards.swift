import Foundation

public struct SharePoint: Equatable, Sendable, Identifiable {
    public var label: String
    public var value: Double

    public var id: String { label }

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct ShareCard: Equatable, Sendable {
    public var headline: String
    public var body: String
    public var detail: String
    public var sourceLine: String
    public var evidence: EvidenceMark?
    public var exampleData: Bool
    public var appName: String
    public var inviteURL: String
    public var points: [SharePoint]
    public var chartKind: String
    public var width: Int
    public var height: Int

    public init(
        headline: String,
        body: String,
        detail: String,
        sourceLine: String = "",
        evidence: EvidenceMark? = nil,
        exampleData: Bool = false,
        appName: String,
        inviteURL: String,
        points: [SharePoint] = [],
        chartKind: String = "",
        width: Int = ShareCanvas.storyWidth,
        height: Int = ShareCanvas.storyHeight
    ) {
        self.headline = headline
        self.body = body
        self.detail = detail
        self.sourceLine = sourceLine
        self.evidence = evidence
        self.exampleData = exampleData
        self.appName = appName
        self.inviteURL = inviteURL
        self.points = points
        self.chartKind = chartKind
        self.width = width
        self.height = height
    }

    public var labelText: String {
        if exampleData { return DataCaution.exampleBanner }
        return evidence?.rawValue ?? ""
    }

    public var qrPayload: String {
        let link = inviteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !link.isEmpty { return link }
        return appName
    }

    public var message: String {
        var lines = [headline, body]
        if !detail.isEmpty { lines.append(detail) }
        if !labelText.isEmpty { lines.append(labelText) }
        if !sourceLine.isEmpty { lines.append(sourceLine) }
        lines.append(appName)
        let link = inviteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !link.isEmpty { lines.append(link) }
        return lines.joined(separator: "\n")
    }

    public var plainText: String {
        [headline, body, detail, labelText, sourceLine, appName, inviteURL, message].joined(separator: "\n")
    }
}

public enum ShareCanvas {
    public static let storyWidth = 1080
    public static let storyHeight = 1920
    public static let milestones = [1, 3, 7, 14, 30, 60, 100, 365]

    public static func isMilestone(_ days: Int) -> Bool {
        milestones.contains(days)
    }
}

public enum ShareCopyGate {
    /// Raíces, para cubrir «corrupto» y «corrupta» sin dejar pasar un juicio.
    public static let forbiddenStems = ["corrupt", "culpable", "testaferro", "delincuente"]

    public static func isClean(_ card: ShareCard) -> Bool {
        let folded = FeedText.fold(card.plainText)
        if forbiddenStems.contains(where: { folded.contains($0) }) {
            return false
        }
        if card.plainText.range(of: #"\b\d{10}\b"#, options: .regularExpression) != nil {
            return false
        }
        if card.plainText.range(
            of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return false
        }
        return true
    }
}

public enum ShareCardBuilder {
    public static let learnedHeadline = "Aprendí esto hoy"
    public static let provinceHeadline = "Así votó mi provincia"

    public static func streak(days: Int, appName: String, inviteURL: String) -> ShareCard? {
        guard ShareCanvas.isMilestone(days) else { return nil }
        return ShareCard(
            headline: "Racha de \(days) \(days == 1 ? "día" : "días")",
            body: "Sigo el camino de Lufy Aprende. Una lección corta, y el día cuenta.",
            detail: "La racha es el estudio de esta persona en este dispositivo. No describe a nadie más.",
            appName: appName,
            inviteURL: inviteURL
        )
    }

    public static func learnedToday(dataset: StudyDataset, appName: String, inviteURL: String) -> ShareCard {
        let ordered = dataset.points.sorted { $0.year < $1.year }
        let latest = ordered.last
        let value = latest.map { "\(ChartFormat.spanish($0.value, decimals: dataset.decimals)) \(dataset.unit)" } ?? ""
        let year = latest.map { String($0.year) } ?? ""
        let signNote = dataset.kind == "bar"
            ? " El verde es cero o positivo y el rojo es negativo. El color es el signo, no una recomendación."
            : " El gráfico muestra la serie. No es una recomendación."
        return ShareCard(
            headline: learnedHeadline,
            body: "\(dataset.title). \(year): \(value).\(signNote)",
            detail: dataset.note,
            sourceLine: DataCaution.caption(dataset),
            evidence: dataset.exampleData ? nil : .confirmado,
            exampleData: dataset.exampleData,
            appName: appName,
            inviteURL: inviteURL,
            points: ordered.map { SharePoint(label: String($0.year), value: $0.value) },
            chartKind: dataset.kind
        )
    }

    public static func provinceVote(
        district: String,
        directory: AsambleaDirectory,
        voteTitle: String? = nil,
        appName: String,
        inviteURL: String
    ) -> ShareCard {
        let people = directory.legislators(in: district)
        let counts = voteCounts(people)
        let chosen: String
        if let voteTitle, counts[voteTitle] != nil {
            chosen = voteTitle
        } else {
            chosen = counts.keys.sorted { left, right in
                let leftCount = counts[left] ?? 0
                let rightCount = counts[right] ?? 0
                if leftCount != rightCount { return leftCount > rightCount }
                return left < right
            }.first ?? ""
        }
        var lines: [String] = []
        var sources: [String] = []
        for person in people {
            if let vote = person.votes.first(where: { $0.title == chosen }) {
                lines.append("\(person.publicName): \(vote.choiceLabel).")
                if !sources.contains(vote.source) {
                    sources.append(vote.source)
                }
            } else {
                lines.append("\(person.publicName): \(HemicycleLayout.absentLabel).")
            }
        }
        if lines.isEmpty {
            lines.append("Esta copia no lista asambleístas de \(district).")
        }
        let sourceLine = sources.isEmpty
            ? "\(directory.source.institution). \(directory.source.dataset). \(directory.source.date)."
            : sources.joined(separator: "\n")
        let voteLine = chosen.isEmpty ? "Sin una votación en esta copia." : chosen
        return ShareCard(
            headline: provinceHeadline,
            body: "\(district). \(voteLine). " + lines.joined(separator: " "),
            detail: "La palabra es el voto registrado en la fuente. No es un juicio sobre la persona.",
            sourceLine: sourceLine,
            evidence: directory.exampleData ? nil : .confirmado,
            exampleData: directory.exampleData,
            appName: appName,
            inviteURL: inviteURL
        )
    }

    public static func invite(appName: String, inviteURL: String) -> ShareCard {
        let link = inviteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = link.isEmpty
            ? "El enlace de invitación se pega en la configuración. Mientras esté vacío, la tarjeta lleva el nombre."
            : link
        return ShareCard(
            headline: appName,
            body: "Lecciones cortas sobre el Ecuador: historia, territorio, economía y la Asamblea.",
            detail: detail,
            appName: appName,
            inviteURL: inviteURL
        )
    }

    private static func voteCounts(_ people: [Legislator]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for person in people {
            for vote in person.votes {
                counts[vote.title, default: 0] += 1
            }
        }
        return counts
    }
}
