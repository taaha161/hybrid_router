import 'package:go_router/go_router.dart';

import 'hybrid_nav.g.dart';
import 'native_route_registry.dart';
import 'placeholder.dart';

/// A thin wrapper over GoRouter that feature teams use exactly like GoRouter.
///
/// Every call asks one question — is this destination native? Native paths
/// go over the typed bridge ([ToNative]); everything else goes straight to
/// GoRouter. When the app is fully Flutter the registry is empty, every call
/// falls through to GoRouter, and this wrapper can be deleted.
class HybridRouter {
  HybridRouter({
    required this.goRouter,
    required this.toNative,
    required this.registry,
  });

  final GoRouter goRouter;

  /// Generated Pigeon caller: Flutter → native.
  final ToNative toNative;

  /// The native screens — the migration dial.
  final NativeRouteRegistry registry;

  /// Back logic shared with native's `onBackPressed` (see [ToFlutterImpl]).
  late final ToFlutterImpl _back = ToFlutterImpl(
    goRouter: goRouter,
    toNative: toNative,
  );

  void push(String path) {
    if (registry.isNative(path)) {
      toNative.pushNativeRoute(NavRoute(path: path)); // → ask iOS
    } else {
      goRouter.push(path); // → stay in Flutter
    }
  }

  /// Resets history — the right semantics for tabs and deep links.
  void go(String path) {
    if (registry.isNative(path)) {
      toNative.popToRoot(); // clear native stack
      toNative.pushNativeRoute(NavRoute(path: path));
    } else {
      goRouter.go(path); // GoRouter reset
    }
  }

  /// In-page back (e.g. the AppBar arrow). Runs the same logic native uses
  /// via `handleBack`; if Flutter has nothing to pop, leave Flutter.
  void pop() {
    if (!_back.handleBack()) toNative.returnToNative();
  }
}

/// Implements the generated [ToFlutter]: what native asks Flutter to do.
///
/// Register once at startup with `ToFlutter.setUp(ToFlutterImpl(...))`.
class ToFlutterImpl implements ToFlutter {
  ToFlutterImpl({required this.goRouter, required this.toNative});

  final GoRouter goRouter;
  final ToNative toNative;

  /// Native opened a Flutter page.
  @override
  void pushFlutterRoute(NavRoute r) {
    goRouter.push(placeholder()); // bare "native is here" marker
    goRouter.push(r.path); // show the page
  }

  /// Native asks first on every back gesture. Returns whether Flutter
  /// consumed it; `false` means native should handle it.
  @override
  bool handleBack() {
    if (!goRouter.canPop() || atRoot) return false;
    goRouter.pop();
    if (isPlaceholder(goRouter.currentTop)) {
      toNative.returnToNative(); // pop the FlutterVC
      goRouter.pop(); // drop placeholder
    }
    return true;
  }

  bool get atRoot => goRouter.currentTop == '/';
}

extension CurrentTop on GoRouter {
  /// The location of the page currently on top of GoRouter's stack,
  /// including imperatively pushed pages (and placeholders).
  String get currentTop => state.uri.path;
}
