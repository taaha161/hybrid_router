import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:user_profile/user_profile.dart';

void main() {
  test('contributes a /backer/:id route', () {
    final routes = userProfileRoutes();
    expect(routes, hasLength(1));
    expect((routes.single as GoRoute).path, '/backer/:id');
  });

  testWidgets('renders the user handle', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UserProfilePage(userId: 'ada')),
      ),
    );

    expect(find.text('@ada'), findsWidgets);
    expect(find.textContaining('user_profile'), findsOneWidget);
  });
}
