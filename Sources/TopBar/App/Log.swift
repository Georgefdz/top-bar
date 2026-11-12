import os

/// Read with: log show --last 5m --predicate 'subsystem == "dev.topbar.TopBar"'
enum Log {
    static let reconcile = Logger(subsystem: "dev.topbar.TopBar", category: "reconcile")
}
