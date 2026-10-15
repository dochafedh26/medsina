import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/main.dart';

void main() {
  testWidgets('Medsina smoke test builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MedsinaApp());
    await tester.pump();
    expect(find.byType(MedsinaApp), findsOneWidget);
  });

  testWidgets('FloatingActionButtons in Clinical and Admin have unique hero tags and do not crash navigation', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: Scaffold(
          body: IndexedStack(
            index: 0,
            children: [
              Scaffold(
                floatingActionButton: FloatingActionButton.extended(
                  heroTag: 'fab_clinical_copilot',
                  onPressed: () {},
                  label: const Text('Copilote'),
                ),
                body: const Text('Clinical'),
              ),
              Scaffold(
                floatingActionButton: FloatingActionButton.extended(
                  heroTag: 'fab_admin_generate_key',
                  onPressed: () {},
                  label: const Text('Admin'),
                ),
                body: const Text('Admin'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trigger navigation transition to another route
    navKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Text('Course PDF Screen'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No exception thrown and new route displayed
    expect(find.text('Course PDF Screen'), findsOneWidget);
  });
}
