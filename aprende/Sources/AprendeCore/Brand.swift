import Foundation

public struct ElevenLabsBrand: Codable, Equatable, Sendable {
    public var modelId: String
    public var voiceId: String

    public init(modelId: String, voiceId: String) {
        self.modelId = modelId
        self.voiceId = voiceId
    }
}

public struct AsambleaFeedBrand: Codable, Equatable, Sendable {
    public var manifestURL: String

    public init(manifestURL: String) {
        self.manifestURL = manifestURL
    }
}

public struct ShareBrand: Codable, Equatable, Sendable {
    public var inviteURL: String

    public init(inviteURL: String) {
        self.inviteURL = inviteURL
    }
}

public struct StoreKitBrand: Equatable, Sendable {
    public var premiumProductIds: [String]
    public var subscriptionsEnabled: Bool
    public var subscriptionProductIds: [String]

    public init(
        premiumProductIds: [String],
        subscriptionsEnabled: Bool = false,
        subscriptionProductIds: [String] = []
    ) {
        self.premiumProductIds = premiumProductIds
        self.subscriptionsEnabled = subscriptionsEnabled
        self.subscriptionProductIds = subscriptionProductIds
    }

    /// Con el interruptor apagado no hay productos activos, aunque el archivo
    /// ya traiga identificadores de prueba.
    public var activeProductIDs: [String] {
        guard subscriptionsEnabled else { return [] }
        if !subscriptionProductIds.isEmpty { return subscriptionProductIds }
        return premiumProductIds
    }

    private enum CodingKeys: String, CodingKey {
        case premiumProductIds, subscriptionsEnabled, subscriptionProductIds
    }
}

extension StoreKitBrand: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        premiumProductIds = try container.decodeIfPresent([String].self, forKey: .premiumProductIds) ?? []
        subscriptionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .subscriptionsEnabled) ?? false
        subscriptionProductIds = try container.decodeIfPresent([String].self, forKey: .subscriptionProductIds) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(premiumProductIds, forKey: .premiumProductIds)
        try container.encode(subscriptionsEnabled, forKey: .subscriptionsEnabled)
        try container.encode(subscriptionProductIds, forKey: .subscriptionProductIds)
    }
}

/// Nombre, identificadores y voz. El archivo `brand.json` es el único lugar
/// donde se cambia el nombre de la app.
public struct Brand: Codable, Equatable, Sendable {
    public var appName: String
    public var bundleIdentifier: String
    public var macBundleIdentifier: String
    public var visionBundleIdentifier: String
    public var developmentTeam: String
    public var elevenlabs: ElevenLabsBrand
    public var storeKit: StoreKitBrand
    public var share: ShareBrand?
    public var asambleaFeed: AsambleaFeedBrand?

    public init(
        appName: String,
        bundleIdentifier: String,
        macBundleIdentifier: String,
        visionBundleIdentifier: String = "com.lufy.aprende.vision",
        developmentTeam: String,
        elevenlabs: ElevenLabsBrand,
        storeKit: StoreKitBrand,
        share: ShareBrand? = nil,
        asambleaFeed: AsambleaFeedBrand? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.macBundleIdentifier = macBundleIdentifier
        self.visionBundleIdentifier = visionBundleIdentifier
        self.developmentTeam = developmentTeam
        self.elevenlabs = elevenlabs
        self.storeKit = storeKit
        self.share = share
        self.asambleaFeed = asambleaFeed
    }

    public var inviteURL: String {
        share?.inviteURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public var asambleaManifestURL: URL? {
        let raw = asambleaFeed?.manifestURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
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
