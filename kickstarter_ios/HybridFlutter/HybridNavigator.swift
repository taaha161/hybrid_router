import Flutter
import UIKit

/// Drives the host `UINavigationController` in response to the navigation
/// channel, and reports native-originated pops back to Flutter.
///
/// ## The single-FlutterViewController model
///
/// There is exactly one `FlutterViewController` (`flutterVC`) bound to the one
/// engine. It hosts *every* Flutter page via GoRouter. Native pages are ordinary
/// `UIViewController`s. Because `flutterVC` is a single instance, an interleaved
/// stack (`flutterA → native → flutterB`) is handled by **reordering** who sits
/// on top, not by creating a second Flutter view:
///
/// ```
/// push /project (flutter)   nav = [discovery, flutterVC(A)]
/// push /reward  (native)    nav = [discovery, flutterVC(A), rewardVC]
/// push /backer  (flutter)   Dart inserts a placeholder + shows B in GoRouter;
///                           native reorders -> [discovery, rewardVC, flutterVC(B)]
/// pop  (from B)             Dart pops B -> lands on placeholder -> showNative:
///                           native reorders -> [discovery, flutterVC, rewardVC]
/// pop  (from rewardVC)      native back -> didPopNative -> Dart pops placeholder
///                           -> flutterVC shows A -> [discovery, flutterVC(A)]
/// ```
final class HybridNavigator: NSObject {
    private unowned let navigationController: UINavigationController
    private let flutterVC: FlutterViewController
    private let channel: NavigationChannel
    private let routeFactory: NativeRouteFactory

    /// Native pages currently live, oldest → newest.
    private var nativeStack: [(path: String, vc: UIViewController)] = []

    init(
        navigationController: UINavigationController,
        flutterVC: FlutterViewController,
        channel: NavigationChannel,
        routeFactory: NativeRouteFactory = .init()
    ) {
        self.navigationController = navigationController
        self.flutterVC = flutterVC
        self.channel = channel
        self.routeFactory = routeFactory
        super.init()
        channel.navigator = self
        navigationController.delegate = self
    }

    // MARK: Flutter -> Native

    /// Push a native page for `path` on top of the current stack.
    func pushNative(path: String, args: Any?) {
        guard let vc = routeFactory.makeViewController(path: path, args: args) else { return }
        vc.hybridPath = path
        // Let a demo native page trigger a native -> Flutter push (interleaving).
        (vc as? DemoNativePageViewController)?.onOpenFlutter = { [weak self] target in
            self?.showFlutter(path: target)
        }
        nativeStack.append((path, vc))
        navigationController.pushViewController(vc, animated: true)
    }

    /// Pop the top native page (programmatic Flutter-initiated pop).
    func popNative() {
        guard nativeStack.last != nil else { return }
        nativeStack.removeLast()
        navigationController.popViewController(animated: true)
    }

    /// Bring the (already-existing) native page for `path` back to the front,
    /// stepping `flutterVC` behind it. Used when a Flutter pop lands on a
    /// placeholder standing in for this native page.
    func showNative(path: String) {
        guard let target = nativeStack.last(where: { $0.path == path })?.vc else { return }
        var vcs = navigationController.viewControllers
        // Move flutterVC directly beneath the target native page.
        vcs.removeAll { $0 === flutterVC || $0 === target }
        vcs.append(flutterVC)
        vcs.append(target)
        navigationController.setViewControllers(vcs, animated: true)
    }

    func popToRoot() {
        nativeStack.removeAll()
        navigationController.popToRootViewController(animated: true)
    }

    /// Show a Flutter route: ensure `flutterVC` is frontmost, then let GoRouter
    /// (via the channel) navigate. If a native page is currently on top, reorder
    /// so `flutterVC` sits above it (the interleaved case).
    func showFlutter(path: String, args: Any? = nil) {
        if navigationController.topViewController !== flutterVC {
            var vcs = navigationController.viewControllers
            if vcs.contains(where: { $0 === flutterVC }) {
                vcs.removeAll { $0 === flutterVC }
                vcs.append(flutterVC)
                navigationController.setViewControllers(vcs, animated: true)
            } else {
                navigationController.pushViewController(flutterVC, animated: true)
            }
        }
        channel.pushFlutter(path: path, args: args)
    }
}

// MARK: - Native-originated back detection

extension HybridNavigator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // A native page that we tracked is no longer in the stack => the user
        // popped it (back button / edge-swipe). Tell Flutter so GoRouter syncs.
        let liveVCs = Set(navigationController.viewControllers.map { ObjectIdentifier($0) })
        for entry in nativeStack.reversed() where !liveVCs.contains(ObjectIdentifier(entry.vc)) {
            nativeStack.removeAll { $0.vc === entry.vc }
            channel.didPopNative(path: entry.path)
        }
    }
}

private var kHybridPathKey: UInt8 = 0

extension UIViewController {
    /// The hybrid route path this native VC represents (for diagnostics).
    var hybridPath: String? {
        get { objc_getAssociatedObject(self, &kHybridPathKey) as? String }
        set { objc_setAssociatedObject(self, &kHybridPathKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
