import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/models/rider_assignment.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_assignment_pages.dart';
import 'package:bearly_mobile/features/rider/presentation/rider_waybill_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('assigned delivery list shows API data without accept controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAssignmentListPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({
                'data': [
                  {
                    'kind': 'delivery',
                    'id': 'SH-20',
                    'title': 'Buyer Rae',
                    'status': 'Assigned',
                    'address': 'Quezon City',
                    'contact_phone': '',
                    'waybill': 'WB-20',
                    'purpose': 'outbound',
                    'purpose_label': 'Buyer delivery',
                    'parcel_count': 1,
                    'zone': 'NCR',
                    'zone_name': 'North',
                    'batch_no': 'DB-20',
                    'parcels': [],
                  },
                ],
              }),
              200,
            ),
          ),
          kind: RiderAssignmentKind.delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buyer Rae'), findsOneWidget);
    expect(find.text('SH-20'), findsOneWidget);
    expect(find.text('1 parcel(s) · Assigned'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('assigned pickup list has an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAssignmentListPage(
          repository: _repository(
            (_) async => http.Response(jsonEncode({'data': []}), 200),
          ),
          kind: RiderAssignmentKind.pickup,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('There are no pickup assignments for you right now.'),
      findsOneWidget,
    );
  });

  testWidgets('read-only job detail displays waybill and parcel information', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({
                'data': {
                  'kind': 'delivery',
                  'id': 'SH-20',
                  'title': 'Buyer Rae',
                  'status': 'Assigned',
                  'address': 'Quezon City',
                  'contact_phone': '09170000000',
                  'waybill': 'WB-20',
                  'purpose': 'outbound',
                  'purpose_label': 'Buyer delivery',
                  'parcel_count': 1,
                  'zone': 'NCR',
                  'zone_name': 'North',
                  'batch_no': 'DB-20',
                  'parcels': [
                    {
                      'parcel_no': 'P-20',
                      'status': 'dispatched',
                      'size_class': 'small',
                      'weight_kg': 1.0,
                    },
                  ],
                },
              }),
              200,
            ),
          ),
          kind: RiderAssignmentKind.delivery,
          jobId: 'SH-20',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waybill: WB-20'), findsOneWidget);
    expect(find.text('P-20'), findsOneWidget);
    expect(find.text('Delivery Details'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('eligible delivery starts and refreshes server-confirmed state', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var detailCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository((request) async {
            requests.add(request);
            if (request.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'message': 'Delivery started.',
                  'data': _deliveryPayload('Out for Delivery', canStart: false),
                }),
                200,
              );
            }
            detailCalls++;
            final started = detailCalls > 1;
            return http.Response(
              jsonEncode({
                'data': _deliveryPayload(
                  started ? 'Out for Delivery' : 'Assigned',
                  canStart: !started,
                ),
              }),
              200,
            );
          }),
          kind: RiderAssignmentKind.delivery,
          jobId: 'SH-20',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Delivery'), findsOneWidget);
    await tester.tap(find.text('Start Delivery'));
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
    expect(requests[1].url.path, '/api/mobile/rider/deliveries/SH-20/start');
    expect(find.text('This delivery is out for delivery.'), findsOneWidget);
    expect(find.text('Start Delivery'), findsNothing);
  });

  testWidgets(
    'delivery start prevents repeated taps while the request is pending',
    (tester) async {
      final requests = <http.Request>[];
      final pendingResponse = Completer<http.Response>();
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RiderJobDetailPage(
            repository: _repository((request) async {
              requests.add(request);
              if (request.method == 'POST') {
                started = true;
                return pendingResponse.future;
              }
              return http.Response(
                jsonEncode({
                  'data': _deliveryPayload(
                    started ? 'Out for Delivery' : 'Assigned',
                    canStart: !started,
                  ),
                }),
                200,
              );
            }),
            kind: RiderAssignmentKind.delivery,
            jobId: 'SH-20',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Delivery'));
      await tester.pump();

      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Starting delivery…'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Starting delivery…'), findsOneWidget);
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );

      pendingResponse.complete(
        http.Response(
          jsonEncode({
            'message': 'Delivery started.',
            'data': _deliveryPayload('Out for Delivery', canStart: false),
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('already started delivery has no start action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({
                'data': _deliveryPayload('Out for Delivery', canStart: false),
              }),
              200,
            ),
          ),
          kind: RiderAssignmentKind.delivery,
          jobId: 'SH-20',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This delivery is out for delivery.'), findsOneWidget);
    expect(find.text('Start Delivery'), findsNothing);
  });

  testWidgets(
    'delivery completion form validates proof and COD before explicit upload',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      var photoPickerCalls = 0;
      final proofPhoto = _TestProofXFile();
      await tester.pumpWidget(
        MaterialApp(
          home: RiderJobDetailPage(
            repository: _repository((request) async {
              requests.add(request);
              if (request.method == 'POST') {
                return http.Response(
                  jsonEncode({
                    'message':
                        'Delivery completion was recorded by the server.',
                    'data': {
                      ..._deliveryPayload('Delivered', canStart: false),
                      'shipment_status': 'delivered',
                      'already_completed': false,
                      'cod_collection': {
                        'status': 'collected',
                        'amount_due_minor': 10000,
                        'amount_collected_minor': 10000,
                        'discrepancy_minor': 0,
                      },
                    },
                  }),
                  200,
                );
              }
              final isStatus = request.url.path.endsWith('/completion-status');
              return http.Response(
                jsonEncode({
                  'data': {
                    ..._deliveryPayload(
                      isStatus ? 'Delivered' : 'Out for Delivery',
                      canStart: false,
                    ),
                    'shipment_status': isStatus
                        ? 'delivered'
                        : 'out_for_delivery',
                    'already_completed': isStatus,
                    'cod_collection': isStatus
                        ? {
                            'status': 'collected',
                            'amount_due_minor': 10000,
                            'amount_collected_minor': 10000,
                            'discrepancy_minor': 0,
                          }
                        : null,
                  },
                }),
                200,
              );
            }),
            kind: RiderAssignmentKind.delivery,
            jobId: 'SH-20',
            proofPhotoPicker: (_) async {
              photoPickerCalls++;
              return proofPhoto;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete Delivery'), findsOneWidget);
      await tester.tap(find.text('Complete Delivery'));
      await tester.pumpAndSettle();
      expect(find.text('COD amount due: ₱100.00'), findsOneWidget);
      expect(requests, hasLength(1));

      await tester.ensureVisible(find.text('Confirm delivery').last);
      await tester.tap(find.text('Confirm delivery').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter the recipient name.'), findsOneWidget);
      expect(find.text('Enter the actual cash collected.'), findsOneWidget);
      expect(requests.where((request) => request.method == 'POST'), isEmpty);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Buyer Rae');
      await tester.enterText(fields.at(1), '100.00');
      await tester.ensureVisible(find.text('Confirm delivery').last);
      await tester.tap(find.text('Confirm delivery').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Add a proof-of-delivery photo before confirming.'),
        findsOneWidget,
      );
      expect(requests.where((request) => request.method == 'POST'), isEmpty);

      await tester.ensureVisible(find.text('Capture proof photo'));
      await tester.tap(find.text('Capture proof photo'));
      await tester.pumpAndSettle();
      expect(photoPickerCalls, 1);
      expect(find.text('Choose a JPG, PNG, or WebP photo.'), findsNothing);
      expect(
        find.text('Could not select a proof photo. Try again.'),
        findsNothing,
      );
      expect(find.text('Selected: proof.png'), findsOneWidget);
      expect(requests.where((request) => request.method == 'POST'), isEmpty);

      await tester.ensureVisible(find.text('Confirm delivery').last);
      await tester.tap(find.text('Confirm delivery').last);
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(
        requests[1].url.path,
        '/api/mobile/rider/deliveries/SH-20/complete',
      );
      final multipartBody = utf8.decode(
        requests[1].bodyBytes,
        allowMalformed: true,
      );
      expect(multipartBody, contains('Buyer Rae'));
      expect(multipartBody, contains('100.00'));
      expect(multipartBody, contains('proof.png'));
      expect(
        find.text(
          'The server confirmed that your assigned parcels are delivered.',
        ),
        findsOneWidget,
      );
      expect(find.text('Complete Delivery'), findsNothing);
    },
  );

  testWidgets(
    'uncertain completion refreshes server state before allowing retry',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final proofPhoto = _TestProofXFile();
      final requests = <http.Request>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RiderJobDetailPage(
            repository: _repository((request) async {
              requests.add(request);
              if (request.method == 'POST') {
                return http.Response(
                  jsonEncode({'message': 'Server error.'}),
                  500,
                );
              }
              if (!request.url.path.endsWith('/completion-status')) {
                return http.Response(
                  jsonEncode({
                    'data': _deliveryPayload(
                      'Out for Delivery',
                      canStart: false,
                    ),
                  }),
                  200,
                );
              }
              return http.Response(
                jsonEncode({
                  'data': {
                    ..._deliveryPayload('Delivered', canStart: false),
                    'shipment_status': 'delivered',
                    'already_completed': true,
                    'cod_collection': null,
                  },
                }),
                200,
              );
            }),
            kind: RiderAssignmentKind.delivery,
            jobId: 'SH-20',
            proofPhotoPicker: (_) async => proofPhoto,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete Delivery'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Buyer Rae');
      await tester.enterText(find.byType(TextFormField).at(1), '100.00');
      await tester.ensureVisible(find.text('Capture proof photo'));
      await tester.tap(find.text('Capture proof photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm delivery').last);
      await tester.tap(find.text('Confirm delivery').last);
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(requests.last.url.path, endsWith('/completion-status'));
      expect(
        find.text(
          'The server confirmed that your assigned parcels are delivered.',
        ),
        findsOneWidget,
      );
      expect(find.text('Complete Delivery'), findsNothing);
    },
  );

  testWidgets(
    'delivery request error refreshes before offering another start',
    (tester) async {
      final requests = <http.Request>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RiderJobDetailPage(
            repository: _repository((request) async {
              requests.add(request);
              if (request.method == 'POST') {
                return http.Response(
                  jsonEncode({'message': 'Dispatch is no longer eligible.'}),
                  409,
                );
              }
              return http.Response(
                jsonEncode({
                  'data': _deliveryPayload('Assigned', canStart: true),
                }),
                200,
              );
            }),
            kind: RiderAssignmentKind.delivery,
            jobId: 'SH-20',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Delivery'));
      await tester.pumpAndSettle();

      expect(find.text('Dispatch is no longer eligible.'), findsOneWidget);
      expect(find.text('Start Delivery'), findsOneWidget);
      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
    },
  );

  testWidgets(
    'delivery timeout refreshes and does not replay a committed start',
    (tester) async {
      final requests = <http.Request>[];
      var detailCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RiderJobDetailPage(
            repository: _repository((request) async {
              requests.add(request);
              if (request.method == 'POST') {
                return http.Response(
                  jsonEncode({'message': 'Request timed out.'}),
                  504,
                );
              }
              detailCalls++;
              final started = detailCalls > 1;
              return http.Response(
                jsonEncode({
                  'data': _deliveryPayload(
                    started ? 'Out for Delivery' : 'Assigned',
                    canStart: !started,
                  ),
                }),
                200,
              );
            }),
            kind: RiderAssignmentKind.delivery,
            jobId: 'SH-20',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Delivery'));
      await tester.pumpAndSettle();

      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(find.text('This delivery is out for delivery.'), findsOneWidget);
      expect(find.text('Start Delivery'), findsNothing);
    },
  );

  testWidgets('pickup detail accepts and confirms using server responses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var status = 'assigned';
    final requests = <http.Request>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository((request) async {
            requests.add(request);
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({'data': _pickupPayload(status)}),
                200,
              );
            }
            if (request.url.path.endsWith('/accept')) {
              status = 'accepted';
              return http.Response(
                jsonEncode({
                  'message': 'Pickup assignment accepted.',
                  'data': _pickupPayload(status),
                }),
                200,
              );
            }
            status = 'picked_up';
            return http.Response(
              jsonEncode({
                'message': 'Pickup confirmed.',
                'data': _pickupPayload(status),
              }),
              200,
            );
          }),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept pickup'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Scan Barcode'), findsOneWidget);
    expect(
      find.text('The server confirmed that this pickup is accepted.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField), 'WB-10');
    final confirmButton = find.text('Verify waybill and confirm pickup');
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(
      find.text('The server confirmed collection of this pickup.'),
      findsOneWidget,
    );
    expect(requests.map((request) => request.method), ['GET', 'POST', 'POST']);
    expect(requests[1].url.path, '/api/mobile/rider/pickups/PU-10/accept');
    expect(requests[2].url.path, '/api/mobile/rider/pickups/PU-10/confirm');
    expect(jsonDecode(requests[2].body), {
      'waybill_identifier': 'WB-10',
      'scan_method': 'manual',
    });
  });

  testWidgets('waybill rejection shows server error and allows correction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var rejected = true;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({'data': _pickupPayload('accepted')}),
                200,
              );
            }
            if (rejected) {
              rejected = false;
              return http.Response(
                jsonEncode({
                  'message':
                      'The scanned waybill does not belong to this pickup.',
                }),
                409,
              );
            }
            return http.Response(
              jsonEncode({
                'message': 'Pickup confirmed.',
                'data': _pickupPayload('picked_up'),
              }),
              200,
            );
          }),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'WRONG-WB');
    final confirmButton = find.text('Verify waybill and confirm pickup');
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(
      find.text('The scanned waybill does not belong to this pickup.'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'WB-10');
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(
      find.text('The server confirmed collection of this pickup.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'scanner is hidden until pickup acceptance and after collection',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final status in ['assigned', 'picked_up', 'completed']) {
        await tester.pumpWidget(
          MaterialApp(
            home: RiderJobDetailPage(
              repository: _repository(
                (_) async => http.Response(
                  jsonEncode({'data': _pickupPayload(status)}),
                  200,
                ),
              ),
              kind: RiderAssignmentKind.pickup,
              jobId: 'PU-10',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Scan Barcode'), findsNothing, reason: status);
      }
    },
  );

  testWidgets('scan fills the field once and does not submit confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    var status = 'accepted';

    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository((request) async {
            requests.add(request);
            if (request.method == 'POST') status = 'picked_up';
            return http.Response(
              jsonEncode({'data': _pickupPayload(status)}),
              200,
            );
          }),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
          scannerPreviewBuilder: _fakeScannerPreview,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decode duplicate values'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'BRLY-CAMERA-WAYBILL-10',
    );
    expect(find.text('Verify waybill and confirm pickup'), findsOneWidget);
    expect(requests.map((request) => request.method), ['GET']);

    await tester.tap(find.text('Verify waybill and confirm pickup'));
    await tester.pumpAndSettle();
    expect(requests.map((request) => request.method), ['GET', 'POST']);
    expect(jsonDecode(requests.last.body), {
      'waybill_identifier': 'BRLY-CAMERA-WAYBILL-10',
      'scan_method': 'camera',
    });
  });

  testWidgets('manually correcting a scanned value uses manual confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    var status = 'accepted';

    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository((request) async {
            requests.add(request);
            if (request.method == 'POST') status = 'picked_up';
            return http.Response(
              jsonEncode({'data': _pickupPayload(status)}),
              200,
            );
          }),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
          scannerPreviewBuilder: _fakeScannerPreview,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decode duplicate values'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'CORRECTED-MANUALLY');
    await tester.tap(find.text('Verify waybill and confirm pickup'));
    await tester.pumpAndSettle();

    expect(jsonDecode(requests.last.body), {
      'waybill_identifier': 'CORRECTED-MANUALLY',
      'scan_method': 'manual',
    });
  });

  testWidgets('empty scan stays open and cancellation preserves manual entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({'data': _pickupPayload('accepted')}),
              200,
            ),
          ),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
          scannerPreviewBuilder: _fakeScannerPreview,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emit empty barcode'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No readable Code 128 value was found'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Cancel scan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'MANUAL-WAYBILL-10');
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'MANUAL-WAYBILL-10',
    );
    expect(find.text('Verify waybill and confirm pickup'), findsOneWidget);
  });

  testWidgets('camera permission denial returns to manual waybill entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({'data': _pickupPayload('accepted')}),
              200,
            ),
          ),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
          scannerPreviewBuilder: _fakeScannerPreview,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deny camera permission'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera permission was denied'), findsOneWidget);

    await tester.tap(find.text('Return to manual entry'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'MANUAL-WAYBILL-20');
    expect(find.text('Verify waybill and confirm pickup'), findsOneWidget);
  });

  testWidgets('canceling scanner returns without changing the waybill field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RiderJobDetailPage(
          repository: _repository(
            (_) async => http.Response(
              jsonEncode({'data': _pickupPayload('accepted')}),
              200,
            ),
          ),
          kind: RiderAssignmentKind.pickup,
          jobId: 'PU-10',
          scannerPreviewBuilder: _fakeScannerPreview,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'MANUAL-BEFORE-SCAN');

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel scan'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'MANUAL-BEFORE-SCAN',
    );
  });

  testWidgets('failed job list request provides retry state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderAssignmentListPage(
          repository: _repository(
            (_) async => http.Response('server error', 500),
          ),
          kind: RiderAssignmentKind.delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load assigned jobs'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Map<String, Object?> _pickupPayload(String statusRaw) => {
  'kind': 'pickup',
  'id': 'PU-10',
  'title': 'Store A',
  'status': switch (statusRaw) {
    'accepted' => 'Accepted',
    'picked_up' => 'Picked Up',
    'completed' => 'Completed',
    _ => 'Assigned',
  },
  'status_raw': statusRaw,
  'address': 'San Pablo',
  'contact_name': 'Seller A',
  'contact_phone': '09170000000',
  'parcel_count': 1,
  'window': 'Today',
  'assigned_at': 'Now',
  'instructions': '',
  'manifest': [],
};

Map<String, Object?> _deliveryPayload(
  String status, {
  required bool canStart,
}) => {
  'kind': 'delivery',
  'id': 'SH-20',
  'title': 'Buyer Rae',
  'status': status,
  'can_start_delivery': canStart,
  'cod_due_minor': 10000,
  'requires_cod_collection': true,
  'address': 'Quezon City',
  'contact_phone': '09170000000',
  'waybill': 'WB-20',
  'purpose': 'outbound',
  'purpose_label': 'Buyer delivery',
  'parcel_count': 1,
  'zone': 'NCR',
  'zone_name': 'North',
  'batch_no': 'DB-20',
  'parcels': [
    {
      'parcel_no': 'P-20',
      'status': switch (status) {
        'Out for Delivery' => 'out_for_delivery',
        'Delivered' => 'delivered',
        _ => 'dispatched',
      },
      'size_class': 'small',
      'weight_kg': 1.0,
    },
  ],
};

final _proofPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);

class _TestProofXFile extends XFile {
  _TestProofXFile() : super('proof.png');

  @override
  String get name => 'proof.png';

  @override
  Future<Uint8List> readAsBytes() async => _proofPng;
}

Widget _fakeScannerPreview(
  BuildContext context,
  WaybillScannerCallbacks callbacks,
) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () {
          callbacks.onBarcodeDetected('BRLY-CAMERA-WAYBILL-10');
          callbacks.onBarcodeDetected('DUPLICATE-WAYBILL-IGNORED');
        },
        child: const Text('Decode duplicate values'),
      ),
      TextButton(
        onPressed: () => callbacks.onBarcodeDetected(null),
        child: const Text('Emit empty barcode'),
      ),
      TextButton(
        onPressed: () => callbacks.onCameraError(
          'Camera permission was denied. Allow camera access in device settings, or return to enter the waybill manually.',
        ),
        child: const Text('Deny camera permission'),
      ),
    ],
  ),
);

RiderRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => RiderRepository(
  authService:
      AuthService(
          apiClient: ApiClient(
            httpClient: MockClient(handler),
            baseUri: Uri.parse('http://127.0.0.1:8000'),
          ),
          tokenStore: _MemoryTokenStore()..token = 'rider-token',
        )
        ..currentSession = const AuthSession(
          id: 1,
          name: 'Rider Rae',
          email: 'rae@example.test',
          role: AccountRole.rider,
        ),
);

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
