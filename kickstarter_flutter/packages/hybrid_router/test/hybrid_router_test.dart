import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_router/hybrid_router.dart';

/// Records Flutter → native calls instead of crossing a platform channel.
class _FakeToNative extends ToNative {
  final List<String> calls = [];

  @override
  Future<void> pushNativeRoute(NavRoute route) async =>
      calls.add('pushNativeRoute ${route.path}');

  @override
  Future<void> returnToNative() async => calls.add('returnToNative');

  @override
  Future<void> popToRoot() async => calls.add('popToRoot');
}

Widget _page(String name) => Scaffold(body: Text(name));

GoRouter _goRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => _page('home')),
    nativePlaceholderRoute(),
    GoRoute(path: '/project/:id', builder: (_, s) => _page('project')),
    GoRoute(path: '/backer/:id', builder: (_, s) => _page('backer')),
  ],
);

void main() {
  late GoRouter goRouter;
  late _FakeToNative toNative;
  late HybridRouter router;
  late ToFlutterImpl toFlutter;

  final registry = NativeRouteRegistry.of({
    '/reward',
    '/reward/*',
    '/checkout',
  });

  Future<void> boot(WidgetTester tester) async {
    goRouter = _goRouter();
    toNative = _FakeToNative();
    router = HybridRouter(
      goRouter: goRouter,
      toNative: toNative,
      registry: registry,
    );
    toFlutter = ToFlutterImpl(goRouter: goRouter, toNative: toNative);
    await tester.pumpWidget(MaterialApp.router(routerConfig: goRouter));
  }

  group('push', () {
    testWidgets('a Flutter path goes straight to GoRouter', (tester) async {
      await boot(tester);
      router.push('/project/42');
      await tester.pumpAndSettle();

      expect(goRouter.currentTop, '/project/42');
      expect(toNative.calls, isEmpty);
    });

    testWidgets('a native path goes over the bridge, GoRouter untouched', (
      tester,
    ) async {
      await boot(tester);
      router.push('/reward/42');
      await tester.pumpAndSettle();

      expect(toNative.calls, ['pushNativeRoute /reward/42']);
      expect(goRouter.currentTop, '/');
    });
  });

  group('go', () {
    testWidgets('a native path resets the native stack first', (tester) async {
      await boot(tester);
      router.go('/checkout');
      await tester.pumpAndSettle();

      expect(toNative.calls, ['popToRoot', 'pushNativeRoute /checkout']);
    });

    testWidgets('a Flutter path resets GoRouter', (tester) async {
      await boot(tester);
      router.push('/project/42');
      router.push('/backer/ada');
      await tester.pumpAndSettle();
      router.go('/project/77');
      await tester.pumpAndSettle();

      expect(goRouter.currentTop, '/project/77');
      expect(goRouter.canPop(), isFalse);
    });
  });

  group('pushFlutterRoute (native opens a Flutter page)', () {
    testWidgets('pushes a bare placeholder, then the page', (tester) async {
      await boot(tester);
      toFlutter.pushFlutterRoute(NavRoute(path: '/project/42'));
      await tester.pumpAndSettle();

      expect(goRouter.currentTop, '/project/42');
      goRouter.pop();
      expect(isPlaceholder(goRouter.currentTop), isTrue);
    });
  });

  group('handleBack', () {
    testWidgets('at the root, returns false so native handles it', (
      tester,
    ) async {
      await boot(tester);

      expect(toFlutter.handleBack(), isFalse);
      expect(toNative.calls, isEmpty);
    });

    testWidgets('Flutter → Flutter: pops and stays in Flutter', (tester) async {
      await boot(tester);
      toFlutter.pushFlutterRoute(NavRoute(path: '/project/42'));
      router.push('/backer/ada');
      await tester.pumpAndSettle();

      expect(toFlutter.handleBack(), isTrue);
      await tester.pumpAndSettle();
      expect(goRouter.currentTop, '/project/42');
      expect(toNative.calls, isEmpty);
    });

    testWidgets('landing on a placeholder returns to native and drops it', (
      tester,
    ) async {
      await boot(tester);
      toFlutter.pushFlutterRoute(NavRoute(path: '/project/42'));
      await tester.pumpAndSettle();

      expect(toFlutter.handleBack(), isTrue);
      await tester.pumpAndSettle();
      expect(toNative.calls, ['returnToNative']);
      expect(goRouter.currentTop, '/');
    });
  });

  group('pop (in-page back arrow)', () {
    testWidgets('uses handleBack when Flutter can pop', (tester) async {
      await boot(tester);
      toFlutter.pushFlutterRoute(NavRoute(path: '/project/42'));
      router.push('/backer/ada');
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();
      expect(goRouter.currentTop, '/project/42');
      expect(toNative.calls, isEmpty);
    });

    testWidgets('leaves Flutter when there is nothing to pop', (tester) async {
      await boot(tester);
      router.pop();

      expect(toNative.calls, ['returnToNative']);
    });
  });

  testWidgets('the full Kickstarter journey, forward and back', (tester) async {
    await boot(tester);

    // Forward: feed (native) → project (Flutter).
    toFlutter.pushFlutterRoute(NavRoute(path: '/project/42'));
    await tester.pumpAndSettle();
    // project → reward (native): over the bridge, GoRouter untouched.
    router.push('/reward/42');
    // reward → backer (Flutter): native opens Flutter again.
    toFlutter.pushFlutterRoute(NavRoute(path: '/backer/ada'));
    await tester.pumpAndSettle();
    expect(goRouter.currentTop, '/backer/ada');
    expect(toNative.calls, ['pushNativeRoute /reward/42']);
    toNative.calls.clear();

    // Back from backer: lands on reward's placeholder → return to native.
    expect(toFlutter.handleBack(), isTrue);
    await tester.pumpAndSettle();
    expect(toNative.calls, ['returnToNative']);
    expect(goRouter.currentTop, '/project/42');

    // Back from reward: native page on top pops itself — Flutter isn't asked.

    // Back from project: lands on feed's placeholder → return to native.
    toNative.calls.clear();
    expect(toFlutter.handleBack(), isTrue);
    await tester.pumpAndSettle();
    expect(toNative.calls, ['returnToNative']);
    expect(goRouter.currentTop, '/');

    // Nothing left: native handles any further back.
    expect(toFlutter.handleBack(), isFalse);
  });
}
