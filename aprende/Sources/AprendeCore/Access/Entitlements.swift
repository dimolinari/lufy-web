import Foundation

public enum CourseOffering: String, Codable, Equatable, Sendable {
    case core
    case extra
    case earlyData = "early-data"
    case narrated
}

/// Lo que la app ya sabe sobre compras. Con la suscripción apagada,
/// `premium` queda en falso y los cursos del núcleo siguen abiertos.
public struct Entitlements: Equatable, Sendable {
    public var premium: Bool

    public init(premium: Bool) {
        self.premium = premium
    }

    public static let freeOnly = Entitlements(premium: false)

    public func canOpen(_ access: CourseAccess) -> Bool {
        switch access {
        case .free:
            return true
        case .premium:
            return premium
        }
    }

    /// El núcleo abre según `access`. Cursos extra, el dato más reciente
    /// y los audiolibros narrados piden la suscripción.
    public func canOpen(_ course: Course) -> Bool {
        switch course.offeringKind {
        case .core:
            return canOpen(course.access)
        case .extra, .earlyData, .narrated:
            return premium
        }
    }
}
