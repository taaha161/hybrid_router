import Flutter

/// The plugin entry point, registered by the host's GeneratedPluginRegistrant.
///
/// The plugin ships the Pigeon-generated bridge (`HybridNav.g.swift`): the
/// `ToNative` protocol the host implements and the `ToFlutter` caller it uses.
/// The host wires both to its own engine (see `NavBridge.swift` in the app),
/// so there is nothing to register here.
public class HybridRouterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {}
}
