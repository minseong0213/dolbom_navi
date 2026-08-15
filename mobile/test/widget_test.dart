import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pregnant_nav/main.dart';

const _showDriveRecordTab = bool.fromEnvironment(
  'SHOW_DRIVE_RECORD_TAB',
  defaultValue: true,
);

void main() {
  testWidgets('renders app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const PregnantNavApp(autoLocateOrigin: false));

    expect(find.text('돌봄 내비게이션'), findsOneWidget);
  });

  testWidgets('starts with safety route recommendation and no mode toggle',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PregnantNavApp(autoLocateOrigin: false));

    expect(find.byType(Switch), findsNothing);
    expect(find.text('돌봄 내비게이션'), findsOneWidget);
    expect(find.text('안심경로 추천'), findsOneWidget);
  });

  testWidgets('shows the drive record tab only when enabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PregnantNavApp(autoLocateOrigin: false));

    expect(
      find.text('기록'),
      _showDriveRecordTab ? findsOneWidget : findsNothing,
    );
  });
}
