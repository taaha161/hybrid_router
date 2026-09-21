import Flutter
import Foundation

/// Method names on the `com.hybridrouter/navigation` channel. These MUST stay in
/// lockstep with `NavMethods` in
/// `packages/hybrid_router/lib/src/native_navigator_channel.dart`.
enum NavMethod {
    // Flutter -> Native
    static let pushNative = "pushNative"
    static let popNative = "popNative"
    static let showNative = "showNative"
    static let popToRoot = "popToRoot"
    static let closeFlutter = "closeFlutter"
    // Native -> Flutter
    static let pushFlutter = "pushFlutter"
    static let popFlutter = "popFlutter"
    static let didPopNative = "didPopNative"
}

/// The native end of the navigation bridge.
///
/// Receives Flutter -> Native calls and forwards them to the [HybridNavigator]
/// (which manipulates the host `UINavigationController`), and exposes helpers to
/// send Native -> Flutter calls.
final class NavigationChannel {
    static let channelName = "com.hybridrouter/navigation"

    private let channel: FlutterMethodChannel

    /// Set by the host once the navigation controller exists.
    weak var navigator: HybridNavigator?

    init(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: NavigationChannel.channelName,
            binaryMessenger: binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let path = args?["path"] as? String
        switch call.method {
        case NavMethod.pushNative:
            guard let path else { return result(argError("pushNative")) }
            navigator?.pushNative(path: path, args: args?["args"])
            result(nil)
        case NavMethod.popNative:
            navigator?.popNative()
            result(nil)
        case NavMethod.showNative:
            guard let path else { return result(argError("showNative")) }
            navigator?.showNative(path: path)
            result(nil)
        case NavMethod.popToRoot:
            navigator?.popToRoot()
            result(nil)
        case NavMethod.closeFlutter:
            navigator?.closeFlutter()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func argError(_ method: String) -> FlutterError {
        FlutterError(code: "bad_args", message: "\(method) missing path", details: nil)
    }

    // MARK: Native -> Flutter

    /// Ask Flutter (GoRouter) to push a Flutter route, e.g. when a native list
    /// cell that maps to a Flutter page is tapped.
    func pushFlutter(path: String, args: Any? = nil, reset: Bool = false) {
        channel.invokeMethod(
            NavMethod.pushFlutter,
            arguments: ["path": path, "args": args as Any, "reset": reset]
        )
    }

    /// Ask Flutter to pop its top route.
    func popFlutter() {
        channel.invokeMethod(NavMethod.popFlutter, arguments: nil)
    }

    /// Tell Flutter a native page was popped (back button / edge-swipe) so the
    /// GoRouter stack stays in sync with the native one.
    func didPopNative(path: String) {
        channel.invokeMethod(NavMethod.didPopNative, arguments: ["path": path])
    }
}
