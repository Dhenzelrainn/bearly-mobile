import '../../../core/network/api_client.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/account_role.dart';
import '../models/buyer_return_models.dart';

abstract interface class BuyerReturnsDataSource {
  Future<BuyerReturnWorkspace> getWorkspace(int sellerOrderId);

  Future<BuyerReturnCase> submitRequest({
    required int sellerOrderId,
    required String requestType,
    required String reasonCode,
    required Map<int, int> itemQuantities,
    required String buyerNote,
    required String? deliveryMethod,
    required List<BuyerReturnAttachment> evidence,
  });

  Future<BuyerReturnCase> getCase(int returnRequestId);

  Future<BuyerReturnCase> addEvidence({
    required int returnRequestId,
    required String note,
    required List<BuyerReturnAttachment> evidence,
  });

  Future<BuyerReturnCase> switchToPickup(int returnRequestId);

  Future<BuyerReturnFileContent> downloadEvidence(int evidenceId);

  Future<BuyerReturnFileContent> downloadRefundReceipt(int refundId);
}

/// Buyer-facing return actions backed by Laravel's Web ReturnRefundService.
class BuyerReturnsRepository implements BuyerReturnsDataSource {
  BuyerReturnsRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  @override
  Future<BuyerReturnWorkspace> getWorkspace(int sellerOrderId) async {
    _requireBuyer();
    _requireId(sellerOrderId, 'sellerOrderId');
    return BuyerReturnWorkspace.fromResponse(
      await _authService.getWithSession(
        '/api/mobile/buyer/seller-orders/$sellerOrderId/returns',
      ),
    );
  }

  @override
  Future<BuyerReturnCase> submitRequest({
    required int sellerOrderId,
    required String requestType,
    required String reasonCode,
    required Map<int, int> itemQuantities,
    required String buyerNote,
    required String? deliveryMethod,
    required List<BuyerReturnAttachment> evidence,
  }) async {
    _requireBuyer();
    _requireId(sellerOrderId, 'sellerOrderId');
    if (!const {'refund_only', 'return_refund'}.contains(requestType)) {
      throw ArgumentError.value(requestType, 'requestType');
    }
    if (itemQuantities.isEmpty ||
        itemQuantities.entries.any(
          (entry) => entry.key < 1 || entry.value < 0,
        )) {
      throw ArgumentError.value(itemQuantities, 'itemQuantities');
    }
    _validateEvidence(evidence);
    final fields = <String, String>{
      'request_type': requestType,
      'reason_code': reasonCode,
      'buyer_note': buyerNote.trim(),
      for (final entry in itemQuantities.entries)
        'item_quantities[${entry.key}]': '${entry.value}',
      if (requestType == 'return_refund' && deliveryMethod != null)
        'return_delivery_method': deliveryMethod,
    };
    final path = '/api/mobile/buyer/seller-orders/$sellerOrderId/returns';
    final jsonBody = <String, Object?>{
      'request_type': requestType,
      'reason_code': reasonCode,
      'buyer_note': buyerNote.trim(),
      'item_quantities': {
        for (final entry in itemQuantities.entries) '${entry.key}': entry.value,
      },
      if (requestType == 'return_refund' && deliveryMethod != null)
        'return_delivery_method': deliveryMethod,
    };
    return _sendCase(path, fields, evidence, jsonBody: jsonBody);
  }

  @override
  Future<BuyerReturnCase> getCase(int returnRequestId) async {
    _requireBuyer();
    _requireId(returnRequestId, 'returnRequestId');
    return BuyerReturnCase.fromResponse(
      await _authService.getWithSession(
        '/api/mobile/buyer/returns/$returnRequestId',
      ),
    );
  }

  @override
  Future<BuyerReturnCase> addEvidence({
    required int returnRequestId,
    required String note,
    required List<BuyerReturnAttachment> evidence,
  }) async {
    _requireBuyer();
    _requireId(returnRequestId, 'returnRequestId');
    if (note.trim().isEmpty && evidence.isEmpty) {
      throw ArgumentError('Add a note or at least one image.');
    }
    _validateEvidence(evidence);
    return _sendCase('/api/mobile/buyer/returns/$returnRequestId/evidence', {
      'note': note.trim(),
    }, evidence);
  }

  @override
  Future<BuyerReturnCase> switchToPickup(int returnRequestId) async {
    _requireBuyer();
    _requireId(returnRequestId, 'returnRequestId');
    final response = await _authService.requestWithSession<Object?>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/returns/$returnRequestId/switch-to-pickup',
      parse: (value) => value,
    );
    return BuyerReturnCase.fromResponse(response);
  }

  @override
  Future<BuyerReturnFileContent> downloadEvidence(int evidenceId) async {
    _requireBuyer();
    _requireId(evidenceId, 'evidenceId');
    final response = await _authService.downloadWithSession(
      path: '/api/mobile/buyer/returns/evidence/$evidenceId',
    );
    return BuyerReturnFileContent(
      bytes: response.bytes,
      mimeType: (response.contentType ?? 'application/octet-stream')
          .split(';')
          .first
          .trim()
          .toLowerCase(),
    );
  }

  @override
  Future<BuyerReturnFileContent> downloadRefundReceipt(int refundId) async {
    _requireBuyer();
    _requireId(refundId, 'refundId');
    final response = await _authService.downloadWithSession(
      path: '/api/mobile/buyer/returns/refunds/$refundId/receipt',
    );
    return BuyerReturnFileContent(
      bytes: response.bytes,
      mimeType: (response.contentType ?? 'application/octet-stream')
          .split(';')
          .first
          .trim()
          .toLowerCase(),
    );
  }

  Future<BuyerReturnCase> _sendCase(
    String path,
    Map<String, String> fields,
    List<BuyerReturnAttachment> evidence, {
    Object? jsonBody,
  }) async {
    final Object? response;
    if (evidence.isEmpty) {
      response = await _authService.requestWithSession<Object?>(
        method: AuthenticatedRequestMethod.post,
        path: path,
        body: jsonBody ?? fields,
        parse: (value) => value,
      );
    } else {
      response = await _authService.multipartFilesRequestWithSession<Object?>(
        path: path,
        fields: fields,
        files: [
          for (final file in evidence)
            ApiMultipartFile(
              field: 'evidence[]',
              bytes: file.bytes,
              fileName: file.fileName,
            ),
        ],
        parse: (value) => value,
      );
    }
    return BuyerReturnCase.fromResponse(response);
  }

  void _requireBuyer() {
    if (_authService.currentSession?.role != AccountRole.buyer) {
      throw const FormatException('Sign in with a Buyer account to continue.');
    }
  }

  void _requireId(int id, String name) {
    if (id < 1) throw RangeError.value(id, name);
  }

  void _validateEvidence(List<BuyerReturnAttachment> evidence) {
    if (evidence.length > 5) {
      throw ArgumentError.value(
        evidence,
        'evidence',
        'Choose at most 5 images.',
      );
    }
    for (final file in evidence) {
      final extension = file.fileName.split('.').last.toLowerCase();
      if (file.fileName.trim().isEmpty ||
          file.bytes.isEmpty ||
          file.bytes.length > 10 * 1024 * 1024 ||
          !const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        throw ArgumentError.value(
          file.fileName,
          'evidence',
          'Use JPG, PNG, or WebP images up to 10 MB each.',
        );
      }
    }
  }
}
