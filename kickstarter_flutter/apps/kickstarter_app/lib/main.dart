import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_router/hybrid_router.dart';
import 'package:project_details/project_details.dart';
import 'package:user_profile/user_profile.dart';

/// Paths implemented on the **native (iOS)** side. Owned here by the host app;
/// injected into [HybridRouter]. Feature packages never see this list.
final kNativeRoutes = NativeRouteRegistry.of({
  '/reward', // pledge / reward detail (doc case page 3)
  '/reward/*',
  '/checkout',
});

/// The single GoRouter that drives the one FlutterViewController.
GoRouter buildGoRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _FlutterHome(),
        ),
        // The invisible placeholder that stands in for an intervening native
        // page in an interleaved stack (see hybrid_router docs).
        GoRoute(
          path: NativePlaceholder.path,
          builder: (context, state) => const NativePlaceholderPage(),
        ),
        ...projectDetailsRoutes(),
        ...userProfileRoutes(),
      ],
    );

/// Build the app-wide [HybridRouter] from the GoRouter, the native registry and
/// the platform navigation channel.
HybridRouter buildHybridRouter() {
  final goRouter = buildGoRouter();
  return HybridRouter(
    flutter: GoRouterNavigation(goRouter),
    channel: NativeNavigatorChannel(),
    registry: kNativeRoutes,
  );
}

void main() {
  final goRouter = buildGoRouter();
  final router = HybridRouter(
    flutter: GoRouterNavigation(goRouter),
    channel: NativeNavigatorChannel(),
    registry: kNativeRoutes,
  );

  runApp(
    ProviderScope(
      overrides: [hybridRouterProvider.overrideWithValue(router)],
      child: KickstarterFlutterApp(goRouter: goRouter),
    ),
  );
}

/// Root widget. Uses `MaterialApp.router` so the single GoRouter owns the one
/// Flutter Navigator that the FlutterViewController displays.
class KickstarterFlutterApp extends StatelessWidget {
  const KickstarterFlutterApp({required this.goRouter, super.key});

  final GoRouter goRouter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kickstarter (Flutter)',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF05CE78),
        useMaterial3: true,
      ),
      routerConfig: goRouter,
    );
  }
}

/// Standalone landing shown when running the module on its own (`flutter run`).
/// In the embedded app this root sits under the native Discovery feed.
class _FlutterHome extends ConsumerWidget {
  const _FlutterHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kickstarter · Flutter module')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Single-engine hybrid routing demo'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.hybridPush('/project/42'),
              child: const Text('Open a project (Flutter)'),
            ),
          ],
        ),
      ),
    );
  }
}
