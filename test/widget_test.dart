import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/main.dart';

void main() {
  testWidgets('Medsina smoke test builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MedsinaApp());
    await tester.pump();
    expect(find.byType(MedsinaApp), findsOneWidget);
  });
}
