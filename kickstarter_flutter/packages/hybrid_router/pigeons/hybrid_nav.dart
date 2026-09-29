// The whole bridge is one schema file. Regenerate with `tool/generate.sh`.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/hybrid_nav.g.dart',
    swiftOut: 'ios/Classes/HybridNav.g.swift',
    dartPackageName: 'hybrid_router',
  ),
)
/// A destination path, e.g. `/project/42`.
class NavRoute {
  NavRoute({required this.path});
  String path;
}

/// Flutter → native. Swift/Kotlin implement it; Dart calls it.
@HostApi()
abstract class ToNative {
  /// Push a native screen for [route].
  void pushNativeRoute(NavRoute route);

  /// We're leaving Flutter: destroy the Flutter view and reveal the native
  /// screen underneath.
  void returnToNative();

  /// Clear the native stack back to its root.
  void popToRoot();
}

/// Native → Flutter. Dart implements it; Swift/Kotlin call it.
@FlutterApi()
abstract class ToFlutter {
  /// Show a Flutter page that native opened.
  void pushFlutterRoute(NavRoute route);

  /// Native asks first on every back gesture. Returns whether Flutter
  /// consumed it.
  bool handleBack();
}
