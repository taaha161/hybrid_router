import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_router/hybrid_router.dart';

/// GoRoutes contributed by this feature. The host app collects these from every
/// feature to build the single GoRouter.
List<RouteBase> projectDetailsRoutes() => [
  GoRoute(
    path: '/project/:id',
    builder: (context, state) =>
        ProjectDetailsPage(projectId: state.pathParameters['id'] ?? '?'),
  ),
];

/// Kickstarter project details — the Flutter analogue of the doc's Yelp
/// "restaurant details" page (case page 2).
///
/// Note there is **no native-vs-Flutter branching** here: the page just calls
/// `ref.read(routerProvider).push(...)`. Whether `/reward/...` is native and `/backer/...` is
/// Flutter is decided by the router's registry, not by this feature.
class ProjectDetailsPage extends ConsumerWidget {
  const ProjectDetailsPage({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E9AAA),
        foregroundColor: Colors.white,
        leading: const HybridBackButton(),
        title: Text('Project #$projectId'),
        bottom: const _FlutterBanner(feature: 'project_details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'A Bold New Board Game',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('by Ada Studio · 1,204 backers · 18 days to go'),
          const SizedBox(height: 24),
          FilledButton(
            // Registered as NATIVE -> pushed onto the iOS nav stack.
            onPressed: () =>
                ref.read(routerProvider).push('/reward/$projectId'),
            child: const Text('Back this project (native reward page)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            // Not in the native registry -> stays inside Flutter via GoRouter.
            onPressed: () => ref.read(routerProvider).push('/backer/ada'),
            child: const Text('View creator profile (Flutter page)'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.read(routerProvider).pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

/// Big "this is Flutter" strip under the AppBar, so a screen recording shows
/// which side of the seam each screen lives on.
class _FlutterBanner extends StatelessWidget implements PreferredSizeWidget {
  const _FlutterBanner({required this.feature});
  final String feature;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    color: const Color(0xFF0B6E79),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        const FlutterLogo(size: 20),
        const SizedBox(width: 10),
        const Text(
          'FLUTTER SCREEN',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Text(
          feature,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}
