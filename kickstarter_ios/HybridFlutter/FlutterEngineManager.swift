import Flutter
import FlutterPluginRegistrant
import UIKit

/// Owns the **single, long-lived** `FlutterEngine` for the whole app.
///
/// This is the crux of the memory story: one engine, warmed once, reused by the
/// one `FlutterViewController` for every Flutter page. We deliberately do *not*
/// use `FlutterEngineGroup` / an engine-per-page, which the "Multiple Flutters"
/// doc shows costs ~38 MB of dirty memory per view.
final class FlutterEngineManager {
    static let shared = FlutterEngineManager()

    let engine: FlutterEngine
    private(set) var navigation: NavigationChannel!

    private init() {
        engine = FlutterEngine(name: "hybrid_router.engine")
    }

    /// Warm the engine at app launch (e.g. from `AppDelegate`), before any
    /// Flutter page is shown, so the first navigation is warm.
    func warmUp() {
        guard !engine.hasRun else { return }
        engine.run() // runs the module's `main()` -> GoRouter at '/'
        // If the module used plugins, register them here:
        // GeneratedPluginRegistrant.register(with: engine)
        navigation = NavigationChannel(
            binaryMessenger: engine.binaryMessenger
        )
    }
}

private extension FlutterEngine {
    var hasRun: Bool { isolateId != nil }
}
