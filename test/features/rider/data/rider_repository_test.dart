import 'dart:async';
import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/auth/models/account_role.dart';
import 'package:bearly_mobile/features/rider/data/rider_repository.dart';
import 'package:bearly_mobile/features/rider/models/rider_assignment.dart';
import 'package:bearly_mobile/features/rider/models/rider_attendance_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RiderRepository', () {
    test(
      'submits only the scanned QR and parses server attendance evidence',
      () async {
        final requests = <http.Request>[];
        final repository = RiderRepository(
          authService: _authService((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'message':
                    'Attendance checked in with the current Logistics QR.',
                'data': {
                  'scan_type': 'check_in',
                  'scanned_at': '2026-11-08T08:30:00+08:00',
                  'work_date': '2026-11-08',
                  'shift_state': 'checked_in',
                  'shift': {
                    'id': 34,
                    'checked_in_at': '2026-11-08T08:30:00+08:00',
                    'checked_out_at': null,
                    'check_in_source': 'qr',
                    'check_out_source': null,
                  },
                  'evidence': {
                    'id': 91,
                    'scan_type': 'check_in',
                    'generation': 12,
                    'scanned_at': '2026-11-08T08:30:00+08:00',
                  },
                },
              }),
              200,
            );
          }),
        );
        const qrPayload =
            'bearly-attendance:v1:7:12:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        final result = await repository.scanAttendance(qrPayload);

        expect(result, isA<RiderAttendanceResult>());
        expect(result.checkedIn, isTrue);
        expect(result.workDate, '2026-11-08');
        expect(result.shiftId, 34);
        expect(result.evidenceGeneration, 12);
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/api/mobile/rider/attendance/scan');
        expect(jsonDecode(requests.single.body), {'qr_payload': qrPayload});
        expect(requests.single.headers['authorization'], 'Bearer rider-token');
      },
    );

    test('rejects a non-attendance QR before making an API request', () async {
      var requested = false;
      final repository = RiderRepository(
        authService: _authService((_) async {
          requested = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        repository.scanAttendance('not-a-bearly-qr'),
        throwsArgumentError,
      );
      expect(requested, isFalse);
    });

    test('loads dashboard and assigned pickup and delivery jobs', () async {
      final requests = <http.Request>[];
      final service = _authService((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/dashboard')) {
          return http.Response(
            jsonEncode({
              'rider': {
                'name': 'Ria Rider',
                'vehicle_type': 'Motorcycle',
                'plate_number': 'TEST-1',
                'availability_status': 'available',
                'logistics_provider': 'North Logistics',
              },
              'metrics': {
                'assigned_pickups': 1,
                'pickup_in_progress': 0,
                'assigned_deliveries': 1,
                'out_for_delivery': 1,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/pickups')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'kind': 'pickup',
                  'id': 'PU-100',
                  'title': 'Store A',
                  'status': 'Assigned',
                  'status_raw': 'assigned',
                  'address': 'Cubao, Quezon City',
                  'contact_name': 'Seller A',
                  'contact_phone': '09170000000',
                  'parcel_count': 2,
                  'window': 'Today',
                  'assigned_at': 'Now',
                  'instructions': 'Side entrance',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': [
              {
                'kind': 'delivery',
                'id': 'SH-200',
                'title': 'Buyer B',
                'status': 'Out for Delivery',
                'address': 'BGC, Taguig',
                'contact_phone': '09171112222',
                'waybill': 'WB-200',
                'purpose': 'outbound',
                'purpose_label': 'Buyer delivery',
                'parcel_count': 1,
                'zone': 'BGC',
                'zone_name': 'Bonifacio Global City',
                'batch_no': 'DB-1',
                'parcels': [
                  {
                    'parcel_no': 'P-200',
                    'status': 'out_for_delivery',
                    'size_class': 'small',
                    'weight_kg': 1.2,
                  },
                ],
              },
            ],
          }),
          200,
        );
      });
      final repository = RiderRepository(authService: service);

      final dashboard = await repository.dashboard();
      final pickups = await repository.pickupJobs();
      final deliveries = await repository.deliveryJobs();

      expect(dashboard.name, 'Ria Rider');
      expect(dashboard.logisticsProvider, 'North Logistics');
      expect(dashboard.assignedPickups, 1);
      expect(dashboard.outForDelivery, 1);
      expect(pickups.single.kind, RiderAssignmentKind.pickup);
      expect(pickups.single.id, 'PU-100');
      expect(pickups.single.parcelCount, 2);
      expect(deliveries.single.kind, RiderAssignmentKind.delivery);
      expect(deliveries.single.parcels.single.parcelNumber, 'P-200');
      expect(requests.map((request) => request.url.path), [
        '/api/mobile/rider/dashboard',
        '/api/mobile/rider/pickups',
        '/api/mobile/rider/deliveries',
      ]);
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer rider-token',
        ),
        isTrue,
      );
    });

    test('parses Courier work type and local workflow capability', () async {
      final repository = RiderRepository(
        authService: _authService((request) async {
          if (request.url.path.endsWith('/dashboard')) {
            return http.Response(
              jsonEncode({
                'rider': {
                  'name': 'Courier Rider',
                  'work_type': 'courier',
                  'capabilities': {
                    'local_pickup': false,
                    'local_delivery': false,
                  },
                },
                'metrics': {
                  'assigned_pickups': 0,
                  'pickup_in_progress': 0,
                  'assigned_deliveries': 0,
                  'out_for_delivery': 0,
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'name': 'Courier Rider',
                'work_type': 'courier',
                'capabilities': {
                  'local_pickup': false,
                  'local_delivery': false,
                },
                'vehicle': {'type': 'Van'},
                'logistics_provider': {},
                'sorting': {},
                'documents': {},
              },
            }),
            200,
          );
        }),
      );

      final dashboard = await repository.dashboard();
      final account = await repository.account();

      expect(dashboard.workType, 'courier');
      expect(dashboard.supportsLocalFulfillment, isFalse);
      expect(account.workType, 'courier');
      expect(account.supportsLocalFulfillment, isFalse);
    });

    test('missing work type and capabilities fail closed', () async {
      final repository = RiderRepository(
        authService: _authService((request) async {
          if (request.url.path.endsWith('/dashboard')) {
            return http.Response(
              jsonEncode({
                'rider': {'name': 'Unclassified Rider'},
                'metrics': {},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'name': 'Unclassified Rider',
                'vehicle': {},
                'logistics_provider': {},
                'sorting': {},
                'documents': {},
              },
            }),
            200,
          );
        }),
      );

      final dashboard = await repository.dashboard();
      final account = await repository.account();

      expect(dashboard.workType, 'unknown');
      expect(dashboard.supportsLocalFulfillment, isFalse);
      expect(account.workType, 'unknown');
      expect(account.supportsLocalFulfillment, isFalse);
    });

    test(
      'reuses recent server capability and force refreshes changes',
      () async {
        final paths = <String>[];
        var accountWorkType = 'courier';
        final service = _authService((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/dashboard')) {
            return http.Response(
              jsonEncode({
                'rider': {
                  'work_type': 'local',
                  'capabilities': {
                    'local_pickup': true,
                    'local_delivery': true,
                  },
                },
                'metrics': {},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'name': 'Ria Rider',
                'email': 'ria@example.test',
                'account_status': 'active',
                'verification_status': 'approved',
                'availability_status': 'available',
                'work_type': accountWorkType,
                'capabilities': {
                  'local_pickup': accountWorkType == 'local',
                  'local_delivery': accountWorkType == 'local',
                },
                'vehicle': {},
                'logistics_provider': {},
                'sorting': {},
                'addresses': [],
                'documents': {},
              },
            }),
            200,
          );
        });
        final firstRepository = RiderRepository(authService: service);
        final routeRepository = RiderRepository(authService: service);

        final dashboard = await firstRepository.dashboard();
        final cached = await routeRepository.workAccess();

        expect(dashboard.supportsLocalFulfillment, isTrue);
        expect(cached.supportsLocalFulfillment, isTrue);
        expect(paths, ['/api/mobile/rider/dashboard']);

        accountWorkType = 'courier';
        final refreshed = await routeRepository.workAccess(forceRefresh: true);

        expect(refreshed.workType, 'courier');
        expect(refreshed.supportsLocalFulfillment, isFalse);
        expect(routeRepository.verifiedWorkAccess?.workType, 'courier');
        expect(paths, [
          '/api/mobile/rider/dashboard',
          '/api/mobile/rider/account',
        ]);
      },
    );

    test('session switch and expiry invalidate cached work access', () async {
      var rejectAccount = false;
      final service = _authService((request) async {
        if (request.url.path.endsWith('/dashboard')) {
          return http.Response(
            jsonEncode({
              'rider': {
                'work_type': 'local',
                'capabilities': {'local_pickup': true, 'local_delivery': true},
              },
              'metrics': {},
            }),
            200,
          );
        }
        return rejectAccount
            ? http.Response('Unauthenticated', 401)
            : http.Response(
                jsonEncode({
                  'data': {
                    'name': 'Updated Rider',
                    'email': 'updated@example.test',
                    'account_status': 'active',
                    'verification_status': 'approved',
                    'availability_status': 'available',
                    'work_type': 'local',
                    'capabilities': {
                      'local_pickup': true,
                      'local_delivery': true,
                    },
                    'vehicle': {},
                    'logistics_provider': {},
                    'sorting': {},
                    'addresses': [],
                    'documents': {},
                  },
                }),
                200,
              );
      });
      final repository = RiderRepository(authService: service);
      await repository.dashboard();
      expect(repository.verifiedWorkAccess?.supportsLocalFulfillment, isTrue);

      service.currentSession = const AuthSession(
        id: 2,
        name: 'Different Rider',
        email: 'different@example.test',
        role: AccountRole.rider,
      );
      expect(repository.lastKnownWorkAccess, isNull);
      final switchedAccess = await repository.workAccess();
      expect(switchedAccess.supportsLocalFulfillment, isTrue);

      rejectAccount = true;
      await expectLater(
        repository.workAccess(forceRefresh: true),
        throwsA(isA<ApiHttpException>()),
      );
      expect(service.currentSession, isNull);
      expect(repository.lastKnownWorkAccess, isNull);
      expect(repository.verifiedWorkAccess, isNull);
    });

    test(
      'joins concurrent capability verification for the same session',
      () async {
        final accountResponse = Completer<http.Response>();
        final paths = <String>[];
        final service = _authService((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/dashboard')) {
            return http.Response(
              jsonEncode({
                'rider': {
                  'work_type': 'local',
                  'capabilities': {
                    'local_pickup': true,
                    'local_delivery': true,
                  },
                },
                'metrics': {},
              }),
              200,
            );
          }
          return accountResponse.future;
        });
        final repository = RiderRepository(authService: service);
        await repository.dashboard();

        final first = repository.workAccess(forceRefresh: true);
        final second = repository.workAccess(forceRefresh: true);
        await Future<void>.delayed(Duration.zero);
        expect(paths, [
          '/api/mobile/rider/dashboard',
          '/api/mobile/rider/account',
        ]);

        accountResponse.complete(
          http.Response(
            jsonEncode({
              'data': {
                'name': 'Ria Rider',
                'email': 'ria@example.test',
                'account_status': 'active',
                'verification_status': 'approved',
                'availability_status': 'available',
                'work_type': 'courier',
                'capabilities': {
                  'local_pickup': false,
                  'local_delivery': false,
                },
                'vehicle': {'type': 'Van'},
                'logistics_provider': {},
                'sorting': {},
                'addresses': [],
                'documents': {},
              },
            }),
            200,
          ),
        );
        final results = await Future.wait([first, second]);

        expect(results.map((access) => access.workType), [
          'courier',
          'courier',
        ]);
        expect(
          paths.where((path) => path == '/api/mobile/rider/account'),
          hasLength(1),
        );
      },
    );

    test('loads read-only pickup and delivery details', () async {
      final requestedPaths = <String>[];
      final service = _authService((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.contains('/pickups/')) {
          return http.Response(
            jsonEncode({
              'data': {
                'kind': 'pickup',
                'id': 'PU 100',
                'title': 'Store A',
                'status': 'Assigned',
                'status_raw': 'assigned',
                'address': 'Cubao',
                'contact_name': 'Seller A',
                'contact_phone': '0917',
                'parcel_count': 1,
                'window': 'Today',
                'assigned_at': 'Now',
                'instructions': 'Call first',
                'manifest': [
                  {
                    'waybill': 'WB-1',
                    'products': [
                      {'name': 'Phone', 'variant': 'Blue', 'quantity': 2},
                    ],
                    'parcels': [
                      {
                        'parcel_no': 'P-1',
                        'waybill': 'WB-1',
                        'size': 'Small',
                        'status': 'Created',
                      },
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'kind': 'delivery',
              'id': 'SH-200',
              'title': 'Buyer B',
              'status': 'Assigned',
              'address': 'BGC',
              'contact_phone': '0917',
              'waybill': 'WB-200',
              'purpose': 'outbound',
              'purpose_label': 'Buyer delivery',
              'parcel_count': 1,
              'zone': 'BGC',
              'zone_name': 'BGC Zone',
              'batch_no': 'DB-1',
              'parcels': [
                {
                  'parcel_no': 'P-200',
                  'status': 'dispatched',
                  'size_class': 'small',
                  'weight_kg': 1.2,
                },
              ],
            },
          }),
          200,
        );
      });
      final repository = RiderRepository(authService: service);

      final pickup = await repository.pickupDetail('PU 100');
      final delivery = await repository.deliveryDetail('SH-200');

      expect(pickup.products, ['Phone · Blue × 2']);
      expect(pickup.parcels.single.waybill, 'WB-1');
      expect(delivery.waybill, 'WB-200');
      expect(delivery.parcels.single.parcelNumber, 'P-200');
      expect(requestedPaths, [
        '/api/mobile/rider/pickups/PU%20100',
        '/api/mobile/rider/deliveries/SH-200',
      ]);
    });

    test(
      'posts pickup acceptance and waybill confirmation with session auth',
      () async {
        final requests = <http.Request>[];
        final service = _authService((request) async {
          requests.add(request);
          final status = request.url.path.endsWith('/accept')
              ? 'accepted'
              : 'picked_up';
          return http.Response(
            jsonEncode({'message': 'ok', 'data': _pickupPayload(status)}),
            200,
          );
        });
        final repository = RiderRepository(authService: service);

        final accepted = await repository.acceptPickup('PU-100');
        final collected = await repository.confirmPickup(
          'PU-100',
          waybillIdentifier: '  WB-100  ',
        );

        expect(accepted.statusRaw, 'accepted');
        expect(collected.statusRaw, 'picked_up');
        expect(requests.map((request) => request.method), ['POST', 'POST']);
        expect(requests.map((request) => request.url.path), [
          '/api/mobile/rider/pickups/PU-100/accept',
          '/api/mobile/rider/pickups/PU-100/confirm',
        ]);
        expect(
          requests.every(
            (request) =>
                request.headers['authorization'] == 'Bearer rider-token',
          ),
          isTrue,
        );
        expect(jsonDecode(requests[1].body), {
          'waybill_identifier': 'WB-100',
          'scan_method': 'manual',
        });
      },
    );

    test(
      'loads server progress and verifies an exact delivery Parcel barcode',
      () async {
        final requests = <http.Request>[];
        final service = _authService((request) async {
          requests.add(request);
          final verified = request.method == 'POST';
          return http.Response(
            jsonEncode({
              'data': {
                'assigned_parcel_nos': ['P-1', 'P-2'],
                'verified_parcel_nos': verified ? ['P-1'] : [],
                'verified_count': verified ? 1 : 0,
                'total_count': 2,
                'all_verified': false,
                if (verified) ...{
                  'parcel_no': 'P-1',
                  'newly_verified': true,
                  'verified_at': '2026-11-09T02:00:00Z',
                },
              },
            }),
            200,
          );
        });
        final repository = RiderRepository(authService: service);

        final before = await repository.deliveryVerificationProgress('SH 200');
        final after = await repository.verifyDeliveryParcel(
          'SH 200',
          barcode: ' P-1 ',
          scanMethod: 'camera',
        );

        expect(before.assignedParcelNumbers, ['P-1', 'P-2']);
        expect(before.verifiedCount, 0);
        expect(before.allVerified, isFalse);
        expect(after.verifiedParcelNumbers, ['P-1']);
        expect(after.parcelNumber, 'P-1');
        expect(after.newlyVerified, isTrue);
        expect(after.verifiedAt, DateTime.parse('2026-11-09T02:00:00Z'));
        expect(requests.map((request) => request.method), ['GET', 'POST']);
        expect(requests.map((request) => request.url.path), [
          '/api/mobile/rider/deliveries/SH%20200/verification-progress',
          '/api/mobile/rider/deliveries/SH%20200/verify-parcel',
        ]);
        expect(jsonDecode(requests[1].body), {
          'barcode': 'P-1',
          'scan_method': 'camera',
        });
        expect(
          requests.every(
            (request) =>
                request.headers['authorization'] == 'Bearer rider-token',
          ),
          isTrue,
        );
      },
    );

    test('posts delivery start with the authenticated Rider session', () async {
      final requests = <http.Request>[];
      final service = _authService((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'message': 'Delivery started.',
            'data': _deliveryPayload('Out for Delivery', canStart: false),
          }),
          200,
        );
      });
      final repository = RiderRepository(authService: service);

      final started = await repository.startDelivery('SH-200');

      expect(started.id, 'SH-200');
      expect(started.statusRaw, 'out_for_delivery');
      expect(started.canStartDelivery, isFalse);
      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.path,
        '/api/mobile/rider/deliveries/SH-200/start',
      );
      expect(requests.single.headers['authorization'], 'Bearer rider-token');
    });

    test(
      'posts a trimmed failed-delivery reason with Rider session auth',
      () async {
        late http.Request submitted;
        final service = _authService((request) async {
          submitted = request;
          return http.Response(
            jsonEncode({
              'message': 'Failed delivery attempt recorded.',
              'data': {
                ..._deliveryPayload('Delivery Failed', canStart: false),
                'status_raw': 'delivery_failed',
                'parcels': [
                  {
                    'parcel_no': 'P-200',
                    'status': 'failed',
                    'size_class': 'small',
                    'weight_kg': 1.2,
                  },
                ],
              },
            }),
            200,
          );
        });
        final repository = RiderRepository(authService: service);

        final failed = await repository.failDelivery(
          'SH-200',
          failureReason: '  Recipient unavailable  ',
        );

        expect(failed.statusRaw, 'delivery_failed');
        expect(submitted.method, 'POST');
        expect(submitted.url.path, '/api/mobile/rider/deliveries/SH-200/fail');
        expect(jsonDecode(submitted.body), {
          'failure_reason': 'Recipient unavailable',
        });
        expect(submitted.headers['authorization'], 'Bearer rider-token');
      },
    );

    test(
      'posts a retry to the authenticated delivery retry endpoint',
      () async {
        late http.Request submitted;
        final service = _authService((request) async {
          submitted = request;
          return http.Response(
            jsonEncode({
              'message': 'Delivery retry started.',
              'data': {
                ..._deliveryPayload('Out for Delivery', canStart: false),
                'status_raw': 'out_for_delivery',
                'can_retry': false,
              },
            }),
            200,
          );
        });
        final repository = RiderRepository(authService: service);

        final retry = await repository.retryDelivery('SH-200');

        expect(retry.statusRaw, 'out_for_delivery');
        expect(retry.canRetry, isFalse);
        expect(submitted.method, 'POST');
        expect(submitted.url.path, '/api/mobile/rider/deliveries/SH-200/retry');
        expect(submitted.headers['authorization'], 'Bearer rider-token');
      },
    );

    test('uploads private delivery proof and parses COD completion', () async {
      final requests = <http.Request>[];
      final service = _authService((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'data': {
              ..._deliveryPayload('Delivered', canStart: false),
              'shipment_status': 'delivered',
              'already_completed': false,
              'cod_collection': {
                'status': 'disputed',
                'amount_due_minor': 10000,
                'amount_collected_minor': 9500,
                'discrepancy_minor': -500,
              },
            },
          }),
          200,
        );
      });
      final repository = RiderRepository(authService: service);

      final completion = await repository.completeDelivery(
        'SH-200',
        recipientName: ' Buyer B ',
        proofPhotoBytes: [1, 2, 3, 4],
        proofPhotoName: 'delivery-proof.png',
        codCollectedAmount: '95.00',
      );

      expect(completion.assignment.statusRaw, 'delivered');
      expect(completion.shipmentStatus, 'delivered');
      expect(completion.codCollection?.status, 'disputed');
      expect(completion.codCollection?.amountDueMinor, 10000);
      expect(completion.codCollection?.discrepancyMinor, -500);
      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.path,
        '/api/mobile/rider/deliveries/SH-200/complete',
      );
      expect(requests.single.headers['authorization'], 'Bearer rider-token');
      expect(
        requests.single.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = utf8.decode(requests.single.bodyBytes, allowMalformed: true);
      expect(body, contains('name="recipient_name"'));
      expect(body, contains('Buyer B'));
      expect(body, contains('name="cod_collected_amount"'));
      expect(body, contains('95.00'));
      expect(body, contains('filename="delivery-proof.png"'));
      expect(body, contains('\u0001\u0002\u0003\u0004'));
    });

    test('refreshes delivery completion state from the server', () async {
      final requests = <http.Request>[];
      final service = _authService((request) async {
        requests.add(request);
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
      });
      final repository = RiderRepository(authService: service);

      final status = await repository.deliveryCompletionStatus('SH-200');

      expect(status.assignment.statusRaw, 'delivered');
      expect(status.shipmentStatus, 'delivered');
      expect(status.alreadyCompleted, isTrue);
      expect(
        requests.single.url.path,
        '/api/mobile/rider/deliveries/SH-200/completion-status',
      );
      expect(requests.single.method, 'GET');
    });

    test(
      'loads authenticated account data on each request without caching',
      () async {
        var call = 0;
        final service = _authService((request) async {
          expect(request.url.path, '/api/mobile/rider/account');
          call++;
          return http.Response(
            jsonEncode({
              'data': {
                'name': call == 1 ? 'Ria Rider' : 'Sam Rider',
                'email': call == 1 ? 'ria@example.test' : 'sam@example.test',
                'account_status': 'active',
                'verification_status': 'approved',
                'availability_status': 'available',
                'vehicle': {
                  'type': 'Motorcycle',
                  'model': 'Click 160',
                  'plate_number': 'TEST-1',
                  'parcel_capacity': 18,
                },
                'logistics_provider': {'name': 'North Logistics'},
                'sorting': {
                  'home_center': null,
                  'current_zone': null,
                  'current_zone_center': null,
                },
                'addresses': [],
                'documents': {
                  'valid_id': 'not_provided',
                  'or_cr': 'approved',
                  'driver_license': 'approved',
                },
              },
            }),
            200,
          );
        });
        final repository = RiderRepository(authService: service);

        final first = await repository.account();
        final second = await repository.account();

        expect(first.name, 'Ria Rider');
        expect(first.vehicleModel, 'Click 160');
        expect(first.logisticsProvider, 'North Logistics');
        expect(second.name, 'Sam Rider');
        expect(call, 2);
      },
    );

    test(
      'loads read-only history with URL-encoded search and pagination',
      () async {
        final requests = <http.Request>[];
        final service = _authService((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'shipment_no': 'SHIP-1',
                  'parcel_no': 'PARCEL-1',
                  'date': 'Oct 29, 2026',
                  'area': 'Lumban',
                  'status': 'delivered',
                  'status_label': 'Delivered',
                  'earning': 'No ledger entry',
                  'batch_no': 'BATCH-1',
                  'attempt': 'Attempt 1',
                },
              ],
              'meta': {
                'current_page': 2,
                'last_page': 3,
                'per_page': 20,
                'total': 45,
              },
              'summary': {'completed_this_month': 1},
            }),
            200,
          );
        });
        final repository = RiderRepository(authService: service);

        final history = await repository.history(search: 'SHIP 1', page: 2);

        expect(history.total, 45);
        expect(history.currentPage, 2);
        expect(history.entries.single.shipmentNumber, 'SHIP-1');
        expect(history.entries.single.status, 'delivered');
        expect(requests.single.url.queryParameters, {
          'search': 'SHIP 1',
          'page': '2',
        });
        expect(requests.single.headers['authorization'], 'Bearer rider-token');
      },
    );

    test(
      'loads read-only earnings with summary and pagination metadata',
      () async {
        final requests = <http.Request>[];
        final repository = RiderRepository(
          authService: _authService((request) async {
            requests.add(request);
            return http.Response.bytes(
              utf8.encode(jsonEncode(_earningsPayload(page: 2))),
              200,
            );
          }),
        );

        final earnings = await repository.earnings(page: 2);

        expect(earnings.workType, 'courier');
        expect(earnings.currency, 'PHP');
        expect(earnings.summary.combinedTotalMinor, 130000);
        expect(earnings.courierDaily?.qualifyingDays, 2);
        expect(earnings.entries.single.isCourierDaily, isTrue);
        expect(earnings.entries.single.statusLabel, 'Posted');
        expect(earnings.currentPage, 2);
        expect(earnings.hasMore, isFalse);
        expect(requests.single.url.path, '/api/mobile/rider/earnings');
        expect(requests.single.url.queryParameters, {'page': '2'});
        expect(requests.single.headers['authorization'], 'Bearer rider-token');
      },
    );

    test(
      'rejects invalid earnings pagination before making a request',
      () async {
        var requested = false;
        final repository = RiderRepository(
          authService: _authService((_) async {
            requested = true;
            return http.Response('{}', 200);
          }),
        );

        await expectLater(repository.earnings(page: 0), throwsRangeError);
        expect(requested, isFalse);
      },
    );
  });
}

Map<String, Object?> _earningsPayload({int page = 1}) => {
  'data': {
    'work_type': 'courier',
    'currency': 'PHP',
    'summary': {
      'today': {'amount_minor': 65000, 'amount': '₱650.00', 'entries': 1},
      'week': {'amount_minor': 130000, 'amount': '₱1,300.00', 'entries': 2},
      'month': {'amount_minor': 130000, 'amount': '₱1,300.00', 'entries': 2},
      'active_total_minor': 130000,
      'active_total': '₱1,300.00',
      'active_entries': 2,
      'pickup_total_minor': 0,
      'pickup_total': '₱0.00',
      'delivery_total_minor': 0,
      'delivery_total': '₱0.00',
      'delivery_pending_minor': 0,
      'delivery_pending': '₱0.00',
      'courier_daily_minor': 130000,
      'courier_daily': '₱1,300.00',
      'combined_total_minor': 130000,
      'combined_total': '₱1,300.00',
      'payout_eligible_minor': 65000,
      'payout_eligible': '₱650.00',
      'payout_paid_minor': 65000,
      'payout_paid': '₱650.00',
      'payout_status': 'Ready for payout',
    },
    'courier_daily': {
      'rate_minor': 65000,
      'rate': '₱650.00',
      'today_work_date': '2026-11-06',
      'qualifying_days': 2,
      'total_minor': 130000,
      'total': '₱1,300.00',
      'eligible_minor': 65000,
      'eligible': '₱650.00',
      'paid_minor': 65000,
      'paid': '₱650.00',
    },
    'items': [
      {
        'id': 14,
        'earned_at': 'Nov 6, 2026 · 6:00 PM',
        'earned_at_iso': '2026-11-06T18:00:00+08:00',
        'work_date': 'Nov 6, 2026',
        'work_date_label': 'Nov 6, 2026',
        'job': 'LH-14',
        'source': 'Courier line-haul run LH-14',
        'type': 'courier_daily',
        'type_label': 'Courier Daily',
        'amount_minor': 65000,
        'amount': '₱650.00',
        'status': 'posted',
        'status_label': 'Posted',
        'posted_at': 'Nov 6, 2026 · 6:01 PM',
        'paid_at': '—',
        'description': 'Courier daily pay',
        'linehaul_run_no': 'LH-14',
      },
    ],
    'meta': {
      'current_page': page,
      'last_page': 2,
      'per_page': 20,
      'total': 21,
      'next_page': null,
    },
  },
  'message': 'Rider earnings loaded.',
};

Map<String, Object?> _pickupPayload(String statusRaw) => {
  'kind': 'pickup',
  'id': 'PU-100',
  'title': 'Store A',
  'status': switch (statusRaw) {
    'accepted' => 'Accepted',
    'picked_up' => 'Picked Up',
    _ => 'Assigned',
  },
  'status_raw': statusRaw,
  'address': 'Cubao',
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
  'id': 'SH-200',
  'title': 'Buyer B',
  'status': status,
  'can_start_delivery': canStart,
  'can_retry': false,
  'retry_available_at': null,
  'retry_unavailable_reason': null,
  'cod_due_minor': 10000,
  'requires_cod_collection': true,
  'address': 'BGC, Taguig',
  'contact_phone': '09171112222',
  'waybill': 'WB-200',
  'purpose': 'outbound',
  'purpose_label': 'Buyer delivery',
  'parcel_count': 1,
  'zone': 'BGC',
  'zone_name': 'Bonifacio Global City',
  'batch_no': 'DB-1',
  'parcels': [
    {
      'parcel_no': 'P-200',
      'status': switch (status) {
        'Out for Delivery' => 'out_for_delivery',
        'Delivered' => 'delivered',
        _ => 'dispatched',
      },
      'size_class': 'small',
      'weight_kg': 1.2,
    },
  ],
};

AuthService _authService(Future<http.Response> Function(http.Request) handler) {
  final service = AuthService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('http://127.0.0.1:8000'),
    ),
    tokenStore: _MemoryTokenStore()..token = 'rider-token',
  );
  service.currentSession = const AuthSession(
    id: 1,
    name: 'Ria Rider',
    email: 'ria@example.test',
    role: AccountRole.rider,
  );
  return service;
}

class _MemoryTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
