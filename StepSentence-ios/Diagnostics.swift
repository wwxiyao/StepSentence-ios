import Foundation

final class Diagnostics {
    static let shared = Diagnostics()
    private init() {}

    var lastProjectTapAt: Date?
    var lastProjectsDisappearAt: Date?
}
