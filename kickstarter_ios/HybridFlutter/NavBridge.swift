import Flutter
import hybrid_router

/// ✎ Implements the generated `ToNative`. Every Dart `toNative` call lands
/// here, and each method is a one-liner into `HybridNavigator`.
final class ToNativeImpl: ToNative {
    let nav: HybridNavigator

    init(nav: HybridNavigator) {
        self.nav = nav
    }

    func pushNativeRoute(route: NavRoute) { nav.push(route.path) }
    func returnToNative() { nav.returnToNative() }
    func popToRoot() { nav.popToRoot() }
}

extension HybridNavigator {
    /// Register once — now Dart can drive native.
    func registerBridge() {
        ToNativeSetup.setUp(binaryMessenger: engine.binaryMessenger, api: ToNativeImpl(nav: self))
    }
}
