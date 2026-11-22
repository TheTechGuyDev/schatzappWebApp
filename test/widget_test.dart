import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schatzapp_web/widgets/brand_logo.dart';

void main() {
  testWidgets('Brand logo renders wordmark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: SMark()))),
    );
    expect(find.byType(SMark), findsOneWidget);
  });
}
