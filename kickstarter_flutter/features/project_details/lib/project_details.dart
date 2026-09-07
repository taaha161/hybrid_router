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
/// `ref.hybridPush(...)`. Whether `/reward/...` is native and `/backer/...` is
/// Flutter is decided by the router's registry, not by this feature.
class ProjectDetailsPage extends ConsumerWidget {
  const ProjectDetailsPage({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Project #$projectId')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Banner(label: 'FLUTTER · project_details'),
          const SizedBox(height: 16),
          Text(
            'A Bold New Board Game',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('by Ada Studio · 1,204 backers · 18 days to go'),
          const SizedBox(height: 24),
          FilledButton(
            // Registered as NATIVE -> pushed onto the iOS nav stack.
            onPressed: () => ref.hybridPush('/reward/$projectId'),
            child: const Text('Back this project (native reward page)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            // Not in the native registry -> stays inside Flutter via GoRouter.
            onPressed: () => ref.hybridPush('/backer/ada'),
            child: const Text('View creator profile (Flutter page)'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.hybridPop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF05CE78),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
}
