import Foundation
import AprendeCore

@MainActor
@Observable
final class AsambleaStore {
    private(set) var directory: AsambleaDirectory
    private(set) var statusMessage: String
    private var lastSuccessDay: String?
    private let cacheURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("LufyAprende", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cacheURL = folder.appendingPathComponent("asamblea-cache.json")

        if let cached = Self.read(cacheURL),
           let saved = try? PublicRoleGate.validate(data: cached.payload) {
            directory = saved
            lastSuccessDay = cached.lastSuccessDay
            statusMessage = "Copia guardada en el dispositivo."
        } else if let bundled = try? FeedLibrary.loadBundled() {
            directory = bundled
            statusMessage = "Copia que viene con la app."
        } else {
            directory = AsambleaDirectory(
                schema: AsambleaSchema.name,
                exampleData: true,
                updatedAt: "",
                source: FeedSource(institution: "Copia de ejemplo", dataset: "", date: "", note: ""),
                legislators: []
            )
            statusMessage = "No hay copia local."
        }
    }

    func refreshIfDue(manifestURL: URL?) async {
        guard let manifestURL else {
            statusMessage = "Sin dirección de manifiesto. Se muestra la copia local."
            return
        }
        let today = DayClock.ecuador.day(for: Date()).iso
        if FeedRefreshPlan.decide(lastSuccessDay: lastSuccessDay, today: today) == .useCached {
            statusMessage = "Ya se consultó hoy. La próxima revisión es mañana."
            return
        }
        do {
            let (manifestData, _) = try await URLSession.shared.data(from: manifestURL)
            let manifest = try PublicRoleGate.validate(manifest: manifestData)
            guard let entry = manifest.file(named: AsambleaSchema.payloadFile) else {
                statusMessage = "El manifiesto no trae el archivo de la Asamblea. Se mantiene la copia anterior."
                return
            }
            let fileURL = manifestURL.deletingLastPathComponent().appendingPathComponent(entry.name)
            let (payload, _) = try await URLSession.shared.data(from: fileURL)
            guard SHA256.matches(data: payload, expectedHex: entry.sha256) else {
                statusMessage = "La copia nueva no coincidió con su huella. Se mantiene la anterior."
                return
            }
            directory = try PublicRoleGate.validate(data: payload)
            lastSuccessDay = today
            Self.write(cacheURL, day: today, payload: payload)
            statusMessage = directory.exampleData
                ? "Se descargó una copia marcada como datos de ejemplo."
                : "Copia actualizada."
        } catch {
            statusMessage = "No se pudo actualizar. Se mantiene la copia anterior."
        }
    }

    private struct CacheFile: Codable {
        var lastSuccessDay: String
        var payload: Data
    }

    private static func read(_ url: URL) -> CacheFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CacheFile.self, from: data)
    }

    private static func write(_ url: URL, day: String, payload: Data) {
        let file = CacheFile(lastSuccessDay: day, payload: payload)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
