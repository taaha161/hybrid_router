import Flutter
import hybrid_router
import UIKit

/// Drives the native stack. Plain UIKit: it owns the navigation controller and
/// holds the one warm engine.
///
/// The engine keeps every Flutter page's state, so a `FlutterViewController`
/// is just a disposable surface onto it: we create one to show Flutter and
/// destroy it on the way back. No reparenting, no `moveToFront`.
final class HybridNavigator: NSObject {
    let navController: UINavigationController
    let engine: FlutterEngine // the one warm engine

    /// Generated Pigeon caller: native → Flutter.
    let toFlutter: ToFlutter

    private let routeFactory = NativeRouteFactory()

    init(navController: UINavigationController, engine: FlutterEngine) {
        self.navController = navController
        self.engine = engine
        toFlutter = ToFlutter(binaryMessenger: engine.binaryMessenger)
        super.init()
        navController.delegate = self
        navController.interactivePopGestureRecognizer?.delegate = self
    }

    /// A native screen.
    func push(_ path: String) {
        guard let vc = routeFactory.make(path) else { return }
        (vc as? DemoNativePageViewController)?.onOpenFlutter = { [weak self] path in
            self?.openFlutter(path)
        }
        navController.pushViewController(vc, animated: true)
    }

    /// A fresh surface onto the engine.
    func showFlutter() {
        engine.viewController = nil // one view at a time
        navController.pushViewController(FlutterViewController(engine: engine, nibName: nil, bundle: nil), animated: true)
    }

    /// Leaving Flutter for good: just destroy the FlutterVC.
    func returnToNative() {
        navController.popViewController(animated: true)
    }

    func popToRoot() {
        navController.popToRootViewController(animated: true)
    }

    /// Native opens a Flutter page: Flutter pushes a placeholder + the page,
    /// then we show a fresh surface so it appears already on the right page.
    func openFlutter(_ path: String) {
        toFlutter.pushFlutterRoute(route: NavRoute(path: path)) { [weak self] _ in
            self?.showFlutter()
        }
    }

    /// Native owns the back gesture and asks Flutter first.
    func onBackPressed() {
        if navController.topViewController is FlutterViewController {
            toFlutter.handleBack { [weak self] result in
                if case .success(true) = result { return } // Flutter handled it
                self?.navController.popViewController(animated: true)
            }
        } else {
            navController.popViewController(animated: true) // native page pops itself
        }
    }
}

extension HybridNavigator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        // Flutter pages draw their own AppBar; native pages use the nav bar.
        navigationController.setNavigationBarHidden(viewController is FlutterViewController, animated: animated)

        // A native back revealed an older Flutter view: reattach it. The engine
        // kept the page's state, so it renders right where it was.
        if let flutterVC = viewController as? FlutterViewController, engine.viewController !== flutterVC {
            engine.viewController = nil
            engine.viewController = flutterVC
        }
    }
}

extension HybridNavigator: UIGestureRecognizerDelegate {
    /// The iOS edge-swipe goes through `onBackPressed` when Flutter is on top.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === navController.interactivePopGestureRecognizer else { return true }
        if navController.topViewController is FlutterViewController {
            onBackPressed()
            return false
        }
        return navController.viewControllers.count > 1
    }
}
