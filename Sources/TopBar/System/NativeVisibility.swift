import Foundation
import MenuBarClientShim

/// macOS 27+: asks the system to show only allow-listed apps' status items.
/// macOS hides the rest and reflows the bar, so no separators or dragging are needed.
@MainActor
final class NativeVisibility {
    static let isAvailable = TBVisibilityIsAvailable()

    /// Keep every system item (clock, Control Center, ...); only apps are filtered.
    private static let systemItems = (0..<64).map { NSNumber(value: $0) }

    /// Called with an error message when activation fails, nil when it succeeds.
    var onResult: ((String?) -> Void)?

    private var assertion: Any?
    private var generation = 0 // drops completions from requests that were superseded

    /// `nil` lifts the restriction and shows everything.
    func apply(allowedBundles: [String]?) {
        generation += 1
        let generation = generation
        guard let allowedBundles else {
            invalidateCurrent()
            return
        }
        TBVisibilityActivate(Self.systemItems, allowedBundles) { [weak self] newAssertion, error in
            MainActor.assumeIsolated {
                guard let self, generation == self.generation else {
                    if let newAssertion { TBVisibilityInvalidate(newAssertion) }
                    return
                }
                if let error {
                    Log.reconcile.error("native visibility failed: \(error.localizedDescription, privacy: .public)")
                    self.onResult?(error.localizedDescription)
                    return
                }
                // Activate the new restriction before dropping the old one, so icons don't flash.
                let old = self.assertion
                self.assertion = newAssertion
                if let old { TBVisibilityInvalidate(old) }
                self.onResult?(nil)
            }
        }
    }

    private func invalidateCurrent() {
        if let assertion { TBVisibilityInvalidate(assertion) }
        assertion = nil
    }
}
