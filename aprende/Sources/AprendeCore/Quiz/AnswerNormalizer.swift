import Foundation

public enum AnswerNormalizer {
    public static func normalize(_ raw: String) -> String {
        let folded = raw.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
        let lowered = folded.lowercased(with: Locale(identifier: "es"))
        var words: [String] = []
        var current = ""
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words.joined(separator: " ")
    }
}
