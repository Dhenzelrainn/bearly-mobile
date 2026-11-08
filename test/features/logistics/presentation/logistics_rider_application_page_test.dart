import 'dart:convert';

import 'package:bearly_mobile/core/network/api_client.dart';
import 'package:bearly_mobile/features/auth/data/auth_service.dart';
import 'package:bearly_mobile/features/logistics/data/logistics_repository.dart';
import 'package:bearly_mobile/features/logistics/models/logistics_rider.dart';
import 'package:bearly_mobile/features/logistics/models/logistics_rider_application.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_rider_application_page.dart';
import 'package:bearly_mobile/features/logistics/presentation/logistics_riders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('application appears in the provider list and opens details', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(applications: [_application()]);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRidersPage(repository: repository),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LogisticsRiderApplicationPage(
            repository: repository,
            applicationId: settings.arguments! as int,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rider applications'), findsOneWidget);
    expect(find.text('Taylor Applicant'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('logistics-rider-application-91')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Applicant details'), findsOneWidget);
    expect(find.text('Taylor Applicant'), findsOneWidget);
  });

  testWidgets('details render documents and refresh after verification', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(applications: [_application()]);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderApplicationPage(
          repository: repository,
          applicationId: 91,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Application documents'), findsOneWidget);
    expect(find.text('Driver License'), findsOneWidget);
    expect(find.textContaining('Review started 2026-11-08'), findsOneWidget);
    final verify = find.byKey(
      const ValueKey('rider-application-document-verify-11'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(verify);
    await tester.pumpAndSettle();
    expect(repository.documentReviews, 1);
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('previews a private document image in-app', (tester) async {
    final repository = _FakeLogisticsRepository(applications: [_application()]);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderApplicationPage(
          repository: repository,
          applicationId: 91,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final open = find.byKey(
      const ValueKey('rider-application-document-open-11'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    Navigator.of(tester.element(find.byType(InteractiveViewer))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('Local Rider approval uses the existing confirmation flow', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(
      applications: [
        _application(
          documents: [
            _document(status: 'verified'),
            _document(
              id: 12,
              type: 'or_cr',
              label: 'OR/CR',
              status: 'verified',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderApplicationPage(
          repository: repository,
          applicationId: 91,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final approve = find.byKey(const ValueKey('rider-application-approve'));
    await tester.drag(find.byType(ListView), const Offset(0, -1100));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(repository.approvalRequests, 1);
    expect(repository.lastLinehaulCapacity, isNull);
  });

  testWidgets('Courier approval requires a valid line-haul capacity', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(
      applications: [
        _application(
          workType: 'courier',
          documents: [
            _document(status: 'verified'),
            _document(
              id: 12,
              type: 'or_cr',
              label: 'OR/CR',
              status: 'verified',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderApplicationPage(
          repository: repository,
          applicationId: 91,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rider-application-approve')));
    await tester.pumpAndSettle();
    final approveCourier = find.byKey(
      const ValueKey('rider-application-approve-courier'),
    );
    await tester.tap(approveCourier);
    await tester.pumpAndSettle();
    expect(repository.approvalRequests, 0);
    await tester.enterText(
      find.byKey(const ValueKey('rider-application-linehaul-capacity')),
      '24',
    );
    await tester.tap(approveCourier);
    await tester.pumpAndSettle();
    expect(repository.approvalRequests, 1);
    expect(repository.lastLinehaulCapacity, 24);
  });

  testWidgets('reject actions require a reason and submit the provided text', (
    tester,
  ) async {
    final repository = _FakeLogisticsRepository(applications: [_application()]);
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderApplicationPage(
          repository: repository,
          applicationId: 91,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rejectDocument = find.byKey(
      const ValueKey('rider-application-document-reject-11'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(rejectDocument);
    await tester.pumpAndSettle();
    final rejectDocumentConfirm = find.widgetWithText(
      FilledButton,
      'Reject document',
    );
    await tester.tap(rejectDocumentConfirm);
    await tester.pumpAndSettle();
    expect(repository.documentReviews, 0);
    await tester.enterText(find.byType(TextField).last, 'Image is unreadable');
    await tester.tap(rejectDocumentConfirm);
    await tester.pumpAndSettle();
    expect(repository.lastDocumentReason, 'Image is unreadable');

    final rejectApplication = find.byKey(
      const ValueKey('rider-application-reject'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(rejectApplication);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Application incomplete',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Reject application'));
    await tester.pumpAndSettle();
    expect(repository.lastApplicationReason, 'Application incomplete');
  });

  testWidgets('detail load failure offers a retry', (tester) async {
    var attempts = 0;
    final repository = _FakeLogisticsRepository(
      applications: [_application()],
      onApplication: () {
        attempts++;
        if (attempts == 1) throw StateError('offline');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsRiderApplicationPage(
          repository: repository,
          applicationId: 91,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load this provider-owned'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Applicant details'), findsOneWidget);
  });
}

class _FakeLogisticsRepository extends LogisticsRepository {
  _FakeLogisticsRepository({required this.applications, this.onApplication})
    : super(
        authService: AuthService(
          apiClient: ApiClient(),
          tokenStore: _TokenStore(),
        ),
      );

  final List<LogisticsRiderApplication> applications;
  final void Function()? onApplication;
  int documentReviews = 0;
  int approvalRequests = 0;
  String? lastDocumentReason;
  String? lastApplicationReason;
  int? lastLinehaulCapacity;

  @override
  Future<List<LogisticsRider>> riders() async => const [];

  @override
  Future<List<LogisticsRiderApplication>> riderApplications() async =>
      applications;

  @override
  Future<LogisticsRiderApplication> riderApplication(int applicationId) async {
    onApplication?.call();
    return applications.singleWhere(
      (application) => application.id == applicationId,
    );
  }

  @override
  Future<LogisticsRiderApplication> reviewRiderApplicationDocument({
    required int applicationId,
    required int documentId,
    required String verificationStatus,
    String? rejectionReason,
  }) async {
    documentReviews++;
    lastDocumentReason = rejectionReason;
    final original = applications.single;
    return _application(
      documents: original.documents
          .map(
            (document) => document.id == documentId
                ? _document(status: verificationStatus, reason: rejectionReason)
                : document,
          )
          .toList(),
    );
  }

  @override
  Future<LogisticsRiderApplication> rejectRiderApplication({
    required int applicationId,
    required String reason,
  }) async {
    lastApplicationReason = reason;
    return _application(status: 'rejected', statusLabel: 'Rejected');
  }

  @override
  Future<LogisticsRiderApplication> approveRiderApplication({
    required int applicationId,
    int? linehaulCapacity,
  }) async {
    approvalRequests++;
    lastLinehaulCapacity = linehaulCapacity;
    return _application(status: 'approved', statusLabel: 'Approved');
  }

  @override
  Future<LogisticsRiderApplicationDocumentContent>
  downloadRiderApplicationDocument({
    required int applicationId,
    required int documentId,
  }) async => LogisticsRiderApplicationDocumentContent(
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aRkAAAAASUVORK5CYII=',
    ),
    mimeType: 'image/png',
  );
}

LogisticsRiderApplication _application({
  String status = 'under_review',
  String statusLabel = 'Needs Review',
  String workType = 'local',
  List<LogisticsRiderApplicationDocument>? documents,
}) => LogisticsRiderApplication(
  id: 91,
  applicationNumber: 'RIDER-2026-0091',
  status: status,
  statusLabel: statusLabel,
  requestedWorkType: workType,
  requestedWorkTypeLabel: workType == 'courier' ? 'Courier' : 'Local Rider',
  submittedAt: DateTime.parse('2026-11-07T09:00:00Z'),
  reviewStartedAt: DateTime.parse('2026-11-08T10:00:00Z'),
  decidedAt: null,
  decisionReason: null,
  revisionNotes: null,
  accountStatus: 'pending',
  canReviewDocuments: true,
  canDecide: true,
  ownershipConsistent: true,
  vehicle: 'Motorcycle',
  vehicleModel: 'Cargo 150',
  plateNumber: 'ABC-1234',
  documentCount: documents?.length ?? 2,
  applicant: const LogisticsRiderApplicant(
    name: 'Taylor Applicant',
    email: 'taylor@example.test',
    phone: '09170000000',
    birthday: null,
    sex: 'Female',
    area: 'North District',
    street: 'Main Street',
    barangay: 'North Barangay',
    cityMunicipality: 'Sample City',
    province: 'Sample Province',
    postalCode: '1000',
  ),
  documents:
      documents ??
      [_document(), _document(id: 12, type: 'or_cr', label: 'OR/CR')],
);

LogisticsRiderApplicationDocument _document({
  int id = 11,
  String type = 'driver_license',
  String label = 'Driver License',
  String status = 'pending',
  String? reason,
}) => LogisticsRiderApplicationDocument(
  id: id,
  type: type,
  label: label,
  filename: '$type.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 1200,
  status: status,
  rejectionReason: reason,
  verifiedAt: status == 'pending'
      ? null
      : DateTime.parse('2026-11-08T11:00:00Z'),
  fileUrl: '/private/$id',
);

class _TokenStore implements SessionTokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}
