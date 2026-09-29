import Flutter
import FlutterPluginRegistrant
import UIKit

/// Owns the **one warm engine** for the whole app.
///
/// One engine, warmed once at launch. Flutter view controllers come and go
/// around it; the engine keeps all Flutter state. We deliberately don't use an
/// engine per page (~38 MB each) or FlutterEngineGroup (separate isolates, no
/// shared back stack).
final class FlutterEngineManager {
    static let shared = FlutterEngineManager()

    let engine = FlutterEngine(name: "hybrid_router.engine")

    private init() {}

    /// Warm the engine at app launch (from `AppDelegate`), before any Flutter
    /// page is shown, so the first navigation is warm.
    func warmUp() {
        guard engine.isolateId == nil else { return }
        engine.run() // runs the module's main(): GoRouter at '/', ToFlutter set up
        GeneratedPluginRegistrant.register(with: engine)
    }
}
