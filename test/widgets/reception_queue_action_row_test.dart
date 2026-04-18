import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital_queue/screens/receptionist/widgets/reception_queue_action_row.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('ReceptionQueueActionRow visibility', () {
    testWidgets(
      'shows check-in and No Show actions for waiting not-checked-in patient',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const ReceptionQueueActionRow(
              canCheckIn: true,
              canCall: false,
              canComplete: false,
              canNoShow: true,
              isProcessing: false,
            ),
          ),
        );

        expect(find.text('Check In'), findsOneWidget);
        expect(find.text('No Show'), findsOneWidget);
        expect(find.text('Call'), findsNothing);
        expect(find.text('Complete'), findsNothing);
      },
    );

    testWidgets('shows call action for checked-in waiting patient', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ReceptionQueueActionRow(
            canCheckIn: false,
            canCall: true,
            canComplete: false,
            canNoShow: false,
            isProcessing: false,
          ),
        ),
      );

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Check In'), findsNothing);
      expect(find.text('Complete'), findsNothing);
      expect(find.text('No Show'), findsNothing);
    });

    testWidgets('shows complete action for in-progress patient', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ReceptionQueueActionRow(
            canCheckIn: false,
            canCall: false,
            canComplete: true,
            canNoShow: false,
            isProcessing: false,
          ),
        ),
      );

      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Check In'), findsNothing);
      expect(find.text('Call'), findsNothing);
      expect(find.text('No Show'), findsNothing);
    });
  });

  group('ReceptionQueueActionRow interaction', () {
    testWidgets('fires callback when action is enabled', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          ReceptionQueueActionRow(
            canCheckIn: true,
            canCall: false,
            canComplete: false,
            canNoShow: false,
            isProcessing: false,
            onCheckIn: () => tapped++,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('queue-action-checkin')));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('does not fire callback while processing', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          ReceptionQueueActionRow(
            canCheckIn: true,
            canCall: false,
            canComplete: false,
            canNoShow: false,
            isProcessing: true,
            onCheckIn: () => tapped++,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('queue-action-checkin')));
      await tester.pump();

      expect(tapped, 0);
    });
  });
}
