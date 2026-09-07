import 'package:go_router/go_router.dart';

/// The subset of navigation actions the [HybridRouter] needs from the Flutter
/// side. Abstracted behind an interface so the router's stack-mixing logic can
/// be unit-tested with a fake, without pumping a full widget tree / GoRouter.
abstract interface class FlutterNavigation {
  void push(String location, {Object? extra});
  void go(String location, {Object? extra});
  void pushReplacement(String location, {Object? extra});
  void pop([Object? result]);
}

/// Production [FlutterNavigation] backed by a real [GoRouter].
class GoRouterNavigation implements FlutterNavigation {
  GoRouterNavigation(this.router);

  final GoRouter router;

  @override
  void push(String location, {Object? extra}) =>
      router.push(location, extra: extra);

  @override
  void go(String location, {Object? extra}) =>
      router.go(location, extra: extra);

  @override
  void pushReplacement(String location, {Object? extra}) =>
      router.pushReplacement(location, extra: extra);

  @override
  void pop([Object? result]) {
    if (router.canPop()) router.pop(result);
  }
}
