import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_details/project_details.dart';

void main() {
  test('contributes a /project/:id route', () {
    final routes = projectDetailsRoutes();
    expect(routes, hasLength(1));
    expect((routes.single as GoRoute).path, '/project/:id');
  });

  testWidgets('renders the project id and actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProjectDetailsPage(projectId: '42')),
      ),
    );

    expect(find.text('Project #42'), findsOneWidget);
    expect(find.textContaining('native reward page'), findsOneWidget);
    expect(find.textContaining('creator profile'), findsOneWidget);
  });
}
