import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nas_sync/main.dart';

void main() {
  testWidgets('App widget builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const NasSyncApp());
    await tester.pump();

    // The app should at least render its root (loading indicator or home).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
