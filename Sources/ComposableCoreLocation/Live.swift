import ConcurrencyExtras
import CoreLocation

extension LocationManager: DependencyKey {
    /// The live implementation of the `LocationManager` interface. This implementation is capable of
    /// creating real `CLLocationManager` instances, listening to its delegate methods, and invoking
    /// its methods. You will typically use this when building for the simulator or device:
    ///
    /// ```swift
    /// let store = Store(
    ///     initialState: AppState(),
    ///     reducer: appReducer,
    ///     environment: AppEnvironment(
    ///       locationManager: LocationManager.live
    ///     )
    /// )
    /// ```
    public static var liveValue: Self {
        let task = Task<LocationManagerSendableBox, Never> { @MainActor in
            let manager = CLLocationManager()
            let delegate = LocationManagerDelegate()
            manager.delegate = delegate
            return .init(manager: manager, delegate: delegate)
        }

        return Self(
            accuracyAuthorization: { @MainActor in
                return await AccuracyAuthorization(task.value.manager.accuracyAuthorization)
            },
            authorizationStatus: { @MainActor in
                return await task.value.manager.authorizationStatus
            },
            delegate: { @MainActor in
                let delegate = await task.value.delegate
                return AsyncStream { delegate.registerContinuation($0) }
            },
            dismissHeadingCalibrationDisplay: { @MainActor in
                await task.value.manager.dismissHeadingCalibrationDisplay()
            },
            heading: { @MainActor in
                return await task.value.manager.heading.map(Heading.init(rawValue:))
            },
            headingAvailable: { @MainActor in
                return CLLocationManager.headingAvailable()
            },
            isRangingAvailable: { @MainActor in
                return CLLocationManager.isRangingAvailable()
            },
            location: { @MainActor in await task.value.manager.location.map(Location.init(rawValue:)) },
            locationServicesEnabled: { CLLocationManager.locationServicesEnabled() },
            maximumRegionMonitoringDistance: { @MainActor in
                return await task.value.manager.maximumRegionMonitoringDistance
            },
            monitoredRegions: { @MainActor in
                return await Set(task.value.manager.monitoredRegions.map(Region.init(rawValue:)))
            },
            requestAlwaysAuthorization: { @MainActor in
                await task.value.manager.requestAlwaysAuthorization()
            },
            requestLocation: { @MainActor in
                await task.value.manager.requestLocation()
            },
            requestWhenInUseAuthorization: { @MainActor in
                await task.value.manager.requestWhenInUseAuthorization()
            },
            requestTemporaryFullAccuracyAuthorization: { @MainActor purposeKey in
                try await task.value.manager.requestTemporaryFullAccuracyAuthorization(
                    withPurposeKey: purposeKey)
            },
            set: { @MainActor properties in
                let manager = await task.value.manager

                if let activityType = properties.activityType {
                    manager.activityType = activityType
                }
                if let allowsBackgroundLocationUpdates = properties.allowsBackgroundLocationUpdates {
                    manager.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
                }
                if let desiredAccuracy = properties.desiredAccuracy {
                    manager.desiredAccuracy = desiredAccuracy
                }
                if let distanceFilter = properties.distanceFilter {
                    manager.distanceFilter = distanceFilter
                }
                if let headingFilter = properties.headingFilter {
                    manager.headingFilter = headingFilter
                }
                if let headingOrientation = properties.headingOrientation {
                    manager.headingOrientation = headingOrientation
                }
                if let pausesLocationUpdatesAutomatically = properties
                    .pausesLocationUpdatesAutomatically
                {
                    manager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
                }
                if let showsBackgroundLocationIndicator = properties.showsBackgroundLocationIndicator {
                    manager.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
                }
            },
            significantLocationChangeMonitoringAvailable: { @MainActor in
                return CLLocationManager.significantLocationChangeMonitoringAvailable()
            },
            startMonitoringForRegion: { @MainActor region in
                await task.value.manager.startMonitoring(for: region.rawValue!)
            },
            startMonitoringSignificantLocationChanges: { @MainActor in
                await task.value.manager.startMonitoringSignificantLocationChanges()
            },
            startMonitoringVisits: { @MainActor in
                await task.value.manager.startMonitoringVisits()
            },
            startUpdatingHeading: { @MainActor in
                await task.value.manager.startUpdatingHeading()
            },
            startUpdatingLocation: { @MainActor in
                await task.value.manager.startUpdatingLocation()
            },
            stopMonitoringForRegion: { @MainActor region in
                await task.value.manager.stopMonitoring(for: region.rawValue!)
            },
            stopMonitoringSignificantLocationChanges: { @MainActor in
                await task.value.manager.stopMonitoringSignificantLocationChanges()
            },
            stopMonitoringVisits: { @MainActor in
                await task.value.manager.stopMonitoringVisits()
            },
            stopUpdatingHeading: { @MainActor in
                await task.value.manager.stopUpdatingHeading()
            },
            stopUpdatingLocation: { @MainActor in
                await task.value.manager.stopUpdatingLocation()
            }
        )
    }
}

private struct LocationManagerSendableBox: Sendable {
    @UncheckedSendable var manager: CLLocationManager
    var delegate: LocationManagerDelegate
}

private final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, Sendable {
    let continuations: LockIsolated<[UUID: AsyncStream<LocationManager.Action>.Continuation]>

    override init() {
        self.continuations = .init([:])
        super.init()
    }

    func registerContinuation(_ continuation: AsyncStream<LocationManager.Action>.Continuation) {
        Task { [continuations] in
            continuations.withValue {
                let id = UUID()
                $0[id] = continuation
                continuation.onTermination = { [weak self] _ in self?.unregisterContinuation(withID: id) }
            }
        }
    }

    private func unregisterContinuation(withID id: UUID) {
        Task { [continuations] in continuations.withValue { $0.removeValue(forKey: id) } }
    }

    private func send(_ action: LocationManager.Action) {
        Task { [continuations] in
            continuations.withValue { $0.values.forEach { $0.yield(action) } }
        }
    }

    func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        send(.didChangeAuthorization(status))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        send(.didFailWithError(LocationManager.Error(error)))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        send(.didUpdateLocations(locations.map(Location.init(rawValue:))))
    }

    func locationManager(
        _ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?
    ) {
        send(
            .didFinishDeferredUpdatesWithError(error.map(LocationManager.Error.init))
        )
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        send(.didPauseLocationUpdates)
    }

    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        send(.didResumeLocationUpdates)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        send(.didUpdateHeading(newHeading: Heading(rawValue: newHeading)))
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        send(.didEnterRegion(Region(rawValue: region)))
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        send(.didExitRegion(Region(rawValue: region)))
    }

    func locationManager(
        _ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion
    ) {
        send(.didDetermineState(state, region: Region(rawValue: region)))
    }

    func locationManager(
        _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
    ) {
        send(
            .monitoringDidFail(
                region: region.map(Region.init(rawValue:)), error: LocationManager.Error(error)))
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        send(.didStartMonitoring(region: Region(rawValue: region)))
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        send(.didVisit(Visit(visit: visit)))
    }
}

extension DependencyValues {
    var locationManager: LocationManager {
        get { self[LocationManager.self] }
        set { self[LocationManager.self] = newValue }
    }
}
