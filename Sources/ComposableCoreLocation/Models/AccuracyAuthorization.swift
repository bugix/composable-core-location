import CoreLocation
import Foundation

/// A value type wrapper for `CLAccuracyAuthorization`
public enum AccuracyAuthorization: Int {
    case fullAccuracy = 0
    case reducedAccuracy = 1
}

extension AccuracyAuthorization {
    init?(_ accuracyAuth: CLAccuracyAuthorization?) {
        switch accuracyAuth {
        case .fullAccuracy:
            self = .fullAccuracy
        case .reducedAccuracy:
            self = .reducedAccuracy
        default:
            return nil
        }
    }
}
