//
//  NetworkMonitor.swift
//  idea-pilot
//
//  Wraps NWPathMonitor to provide observable connectivity state.
//  The SyncEngine uses this to trigger queue drains when
//  connectivity is restored and to gate drain attempts.
//

import Foundation
import Network

/// Observable wrapper around `NWPathMonitor` for network reachability.
///
/// Runs the monitor on a dedicated background queue. The `isConnected`
/// property is updated on the MainActor so SwiftUI views can observe it.
///
/// When connectivity is restored after being offline, the
/// `onConnectivityRestored` callback fires (used by `SyncEngine` to
/// trigger a drain).
///
/// Usage:
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.onConnectivityRestored = { syncEngine.triggerDrain() }
/// monitor.start()
/// ```
@Observable
final class NetworkMonitor {

    /// Whether the device currently has network connectivity.
    var isConnected: Bool = true

    /// Callback invoked on the MainActor when connectivity is restored
    /// after being offline.
    var onConnectivityRestored: (() -> Void)?

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "app.ideapilot.networkmonitor")
    }

    /// Starts monitoring network connectivity. Call once at app launch.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasConnected = self.isConnected
                let nowConnected = path.status == .satisfied
                self.isConnected = nowConnected

                if !wasConnected && nowConnected {
                    self.onConnectivityRestored?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Stops monitoring. Call on sign-out or app termination.
    func stop() {
        monitor.cancel()
    }
}
