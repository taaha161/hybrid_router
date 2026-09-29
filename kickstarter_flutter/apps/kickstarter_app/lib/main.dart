import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_router/hybrid_router.dart';
import 'package:project_details/project_details.dart';
import 'package:user_profile/user_profile.dart';

/// The native screens — the migration dial. The host app owns this list;
/// feature packages never see it. Migrate a screen to Flutter → delete its line.
final kNativeRoutes = NativeRouteRegistry.of({
  '/reward',
  '/reward/*',
  '/checkout',
});

/// The one GoRouter in the one warm engine.
GoRouter buildGoRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _FlutterHome()),
    nativePlaceholderRoute(),
    ...projectDetailsRoutes(),
    ...userProfileRoutes(),
  ],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final goRouter = buildGoRouter();

  // Flutter → native: the generated caller. Nothing to set up.
  final toNative = ToNative();

  // Native → Flutter: register what native asks Flutter to do. One line.
  ToFlutter.setUp(ToFlutterImpl(goRouter: goRouter, toNative: toNative));

  final router = HybridRouter(
    goRouter: goRouter,
    toNative: toNative,
    registry: kNativeRoutes,
  );

  runApp(
    ProviderScope(
      overrides: [routerProvider.overrideWithValue(router)],
      child: KickstarterFlutterApp(goRouter: goRouter),
    ),
  );
}

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
        // Native owns the iOS swipe-back (onBackPressed → handleBack), so
        // Flutter pages use a transition without its own back-swipe gesture.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      routerConfig: goRouter,
    );
  }
}

/// The GoRouter root. Only seen when running the module on its own; in the
/// app it sits under the native feed.
class _FlutterHome extends ConsumerWidget {
  const _FlutterHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kickstarter · Flutter module')),
      body: Center(
        child: FilledButton(
          onPressed: () => ref.read(routerProvider).push('/project/42'),
          child: const Text('Open a project (Flutter)'),
        ),
      ),
    );
  }
}
