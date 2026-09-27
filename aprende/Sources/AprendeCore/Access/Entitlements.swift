import Foundation

/// Lo que la app ya sabe sobre compras. La versión 1 no vende nada:
/// `premium` queda en falso y los cursos publicados son `free`.
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
}
