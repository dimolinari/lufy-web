import Foundation

public struct ElevenLabsBrand: Codable, Equatable, Sendable {
    public var modelId: String
    public var voiceId: String

    public init(modelId: String, voiceId: String) {
        self.modelId = modelId
        self.voiceId = voiceId
    }
}

public struct StoreKitBrand: Codable, Equatable, Sendable {
    public var premiumProductIds: [String]

    public init(premiumProductIds: [String]) {
        self.premiumProductIds = premiumProductIds
    }
}

/// Nombre, identificadores y voz. El archivo `brand.json` es el único lugar
/// donde se cambia el nombre de la app.
public struct Brand: Codable, Equatable, Sendable {
    public var appName: String
    public var bundleIdentifier: String
    public var macBundleIdentifier: String
    public var developmentTeam: String
    public var elevenlabs: ElevenLabsBrand
    public var storeKit: StoreKitBrand

    public init(
        appName: String,
        bundleIdentifier: String,
        macBundleIdentifier: String,
        developmentTeam: String,
        elevenlabs: ElevenLabsBrand,
        storeKit: StoreKitBrand
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.macBundleIdentifier = macBundleIdentifier
        self.developmentTeam = developmentTeam
        self.elevenlabs = elevenlabs
        self.storeKit = storeKit
    }

    public static func load(from data: Data) throws -> Brand {
        try JSONDecoder().decode(Brand.self, from: data)
    }

    public static func bundled() throws -> Brand {
        guard let url = Bundle.module.url(forResource: "brand", withExtension: "json") else {
            throw ContentError.invalid("No está brand.json en el paquete.")
        }
        return try load(from: Data(contentsOf: url))
    }
}
