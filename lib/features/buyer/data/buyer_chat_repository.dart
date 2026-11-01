import '../../auth/data/auth_service.dart';
import '../models/buyer_chat_models.dart';

abstract interface class BuyerChatDataSource {
  Future<List<BuyerChatConversation>> getConversations();
  Future<int> startProductConversation(int productId);
  Future<BuyerChatThread> getMessages(int conversationId, {int? afterId});
  Future<BuyerChatMessage> sendMessage(int conversationId, String message);
  Future<void> markRead(int conversationId);
}

/// Authenticated access to the Laravel Web conversation and message records.
/// The repository never stores the Sanctum token or retries message POSTs.
class BuyerChatRepository implements BuyerChatDataSource {
  BuyerChatRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  @override
  Future<List<BuyerChatConversation>> getConversations() async {
    final response = await _authService.getWithSession(
      '/api/mobile/buyer/chat/conversations',
    );
    final data = _chatEnvelope(response);
    final raw = data['conversations'];
    if (raw is! List) {
      throw const BuyerChatFormatException('data.conversations');
    }
    return List.unmodifiable(raw.map(BuyerChatConversation.fromJson));
  }

  @override
  Future<int> startProductConversation(int productId) async {
    if (productId < 1) {
      throw RangeError.value(productId, 'productId', 'Must be a positive ID.');
    }
    final response = await _authService.requestWithSession<int>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/chat/product',
      body: {'product_id': productId},
      parse: (response) {
        final data = _chatEnvelope(response);
        final id = data['conversation_id'];
        if (id is int && id > 0) return id;
        if (id is String) {
          final parsed = int.tryParse(id);
          if (parsed != null && parsed > 0) return parsed;
        }
        throw const BuyerChatFormatException('data.conversation_id');
      },
    );
    return response;
  }

  @override
  Future<BuyerChatThread> getMessages(
    int conversationId, {
    int? afterId,
  }) async {
    _checkConversationId(conversationId);
    final response = await _authService.getWithSession(
      '/api/mobile/buyer/chat/conversations/$conversationId/messages',
      queryParameters: afterId != null && afterId > 0
          ? {'after': afterId}
          : null,
    );
    return BuyerChatThread.fromJson(_chatEnvelope(response));
  }

  @override
  Future<BuyerChatMessage> sendMessage(
    int conversationId,
    String message,
  ) async {
    _checkConversationId(conversationId);
    final body = message.trim();
    if (body.isEmpty || body.length > 5000) {
      throw ArgumentError.value(
        message,
        'message',
        'Must contain 1 to 5000 characters.',
      );
    }
    return _authService.requestWithSession<BuyerChatMessage>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/chat/conversations/$conversationId/messages',
      body: {'message': body},
      parse: (response) =>
          BuyerChatMessage.fromJson(_chatEnvelope(response)['message']),
    );
  }

  @override
  Future<void> markRead(int conversationId) async {
    _checkConversationId(conversationId);
    await _authService.requestWithSession<void>(
      method: AuthenticatedRequestMethod.post,
      path: '/api/mobile/buyer/chat/conversations/$conversationId/read',
      parse: (_) {},
    );
  }

  void _checkConversationId(int id) {
    if (id < 1) {
      throw RangeError.value(id, 'conversationId', 'Must be a positive ID.');
    }
  }
}

Map<String, Object?> _chatEnvelope(Object? value) {
  if (value is! Map || value['data'] is! Map) {
    throw const BuyerChatFormatException('data');
  }
  final data = value['data'] as Map;
  final result = <String, Object?>{};
  for (final entry in data.entries) {
    if (entry.key is! String) throw const BuyerChatFormatException('data');
    result[entry.key as String] = entry.value;
  }
  return result;
}
