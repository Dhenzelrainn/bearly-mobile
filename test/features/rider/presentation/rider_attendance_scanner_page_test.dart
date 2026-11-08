import 'dart:async';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/rider/models/rider_attendance_result.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_attendance_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _qrPayload =
    'bearly-attendance:v1:7:12:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  testWidgets(
    'invalid QR is rejected locally and success shows server result',
    (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RiderAttendanceScannerPage(
            onSubmit: (_) async {
              submissions++;
              return _result();
            },
            previewBuilder: (context, callbacks) => Column(
              children: [
                TextButton(
                  onPressed: () => callbacks.onQrDetected('not attendance'),
                  child: const Text('Emit invalid QR'),
                ),
                TextButton(
                  onPressed: () => callbacks.onQrDetected(_qrPayload),
                  child: const Text('Emit valid QR'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Emit invalid QR'));
      await tester.pumpAndSettle();
      expect(submissions, 0);
      expect(find.textContaining('not a Bearly attendance QR'), findsOneWidget);

      await tester.tap(find.text('Emit valid QR'));
      await tester.pumpAndSettle();
      expect(submissions, 1);
      expect(find.text('Shift checked in'), findsOneWidget);
      expect(find.text('Work date: 2026-11-08'), findsOneWidget);
      expect(
        find.textContaining('Attendance evidence: QR scan 12'),
        findsOneWidget,
      );
      expect(find.text('Emit valid QR'), findsNothing);
    },
  );

  testWidgets(
    'duplicate camera callbacks submit only once while request is pending',
    (tester) async {
      final pending = Completer<RiderAttendanceResult>();
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RiderAttendanceScannerPage(
            onSubmit: (_) {
              submissions++;
              return pending.future;
            },
            previewBuilder: (context, callbacks) => TextButton(
              onPressed: () {
                callbacks.onQrDetected(_qrPayload);
                callbacks.onQrDetected(_qrPayload);
              },
              child: const Text('Emit QR twice'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Emit QR twice'));
      await tester.pump();
      expect(submissions, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(_result());
      await tester.pumpAndSettle();
      expect(find.text('Shift checked in'), findsOneWidget);
    },
  );

  testWidgets('shows server rejection and prevents retrying the same QR', (
    tester,
  ) async {
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAttendanceScannerPage(
          onSubmit: (_) async {
            submissions++;
            throw ApiHttpException(
              statusCode: 409,
              responseData: {'message': 'This attendance QR has expired.'},
              responseWasJson: true,
            );
          },
          previewBuilder: (context, callbacks) => TextButton(
            onPressed: () => callbacks.onQrDetected(_qrPayload),
            child: const Text('Emit QR'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Emit QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emit QR'));
    await tester.pumpAndSettle();

    expect(submissions, 1);
    expect(find.text('This attendance QR has expired.'), findsOneWidget);
  });

  testWidgets('camera permission errors offer return to dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAttendanceScannerPage(
          onSubmit: (_) async => _result(),
          previewBuilder: (context, callbacks) => TextButton(
            onPressed: () => callbacks.onCameraError(
              'Camera permission was denied. Allow camera access in settings.',
            ),
            child: const Text('Deny camera'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Deny camera'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Camera permission was denied'), findsOneWidget);
    expect(find.text('Back to dashboard'), findsOneWidget);
  });
}

RiderAttendanceResult _result() => RiderAttendanceResult(
  message: 'Attendance checked in with the current Logistics QR.',
  scanType: 'check_in',
  workDate: '2026-11-08',
  shiftState: 'checked_in',
  scannedAt: DateTime.parse('2026-11-08T08:30:00+08:00'),
  shiftId: 34,
  checkedInAt: DateTime.parse('2026-11-08T08:30:00+08:00'),
  checkedOutAt: null,
  evidenceId: 91,
  evidenceGeneration: 12,
);
