import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_returns_repository.dart';
import '../models/buyer_return_models.dart';

class BuyerReturnsPage extends StatefulWidget {
  const BuyerReturnsPage({
    super.key,
    required this.repository,
    required this.sellerOrderId,
  });

  final BuyerReturnsDataSource repository;
  final int sellerOrderId;

  @override
  State<BuyerReturnsPage> createState() => _BuyerReturnsPageState();
}

class _BuyerReturnsPageState extends State<BuyerReturnsPage> {
  final _note = TextEditingController();
  final _imagePicker = ImagePicker();
  BuyerReturnWorkspace? _workspace;
  Object? _error;
  List<BuyerReturnAttachment> _evidence = const [];
  Map<int, int> _quantities = {};
  String _requestType = 'return_refund';
  String? _reasonCode;
  String? _deliveryMethod;
  bool _loading = true;
  bool _submitting = false;
  Future<void>? _pending;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() {
    final pending = _pending;
    if (pending != null) return pending;
    final request = _fetch();
    _pending = request.whenComplete(() => _pending = null);
    return _pending!;
  }

  Future<void> _fetch() async {
    setState(() {
      if (_workspace == null) _loading = true;
      _error = null;
    });
    try {
      final workspace = await widget.repository.getWorkspace(
        widget.sellerOrderId,
      );
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _deliveryMethod ??= workspace.deliveryMethods
            .where((method) => method.available)
            .firstOrNull
            ?.value;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _pickEvidence() async {
    try {
      final selected = await _imagePicker.pickMultiImage(imageQuality: 88);
      if (!mounted || selected.isEmpty) return;
      final files = <BuyerReturnAttachment>[];
      for (final image in selected.take(5)) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          throw const FormatException('Each image must be 10 MB or smaller.');
        }
        final extension = image.name.split('.').last.toLowerCase();
        if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
          throw const FormatException('Choose JPG, PNG, or WebP images.');
        }
        files.add(BuyerReturnAttachment(fileName: image.name, bytes: bytes));
      }
      setState(() => _evidence = files);
    } catch (error) {
      if (!mounted) return;
      _message(_errorText(error), error: true);
    }
  }

  Future<void> _submit() async {
    final workspace = _workspace;
    if (workspace == null || _submitting) return;
    final selected = Map<int, int>.fromEntries(
      _quantities.entries.where((entry) => entry.value > 0),
    );
    if (selected.isEmpty) {
      _message('Choose at least one item quantity.', error: true);
      return;
    }
    if (_reasonCode == null ||
        (_requestType == 'return_refund' && _deliveryMethod == null)) {
      _message('Complete the return reason and delivery method.', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await widget.repository.submitRequest(
        sellerOrderId: workspace.sellerOrderId,
        requestType: _requestType,
        reasonCode: _reasonCode!,
        itemQuantities: selected,
        buyerNote: _note.text,
        deliveryMethod: _requestType == 'return_refund'
            ? _deliveryMethod
            : null,
        evidence: _evidence,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _note.clear();
        _evidence = const [];
        _quantities = {};
      });
      await _load();
      if (!mounted) return;
      _message('Your request was submitted for Seller review.');
      await _openCase(result.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _message(_errorText(error), error: true);
    }
  }

  Future<void> _openCase(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuyerReturnCasePage(
          repository: widget.repository,
          returnRequestId: id,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _workspace;
    if (_loading && workspace == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Returns & refunds')),
        body: const Center(
          child: CircularProgressIndicator(
            key: ValueKey('buyer-returns-loading'),
          ),
        ),
      );
    }
    if (_error != null && workspace == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Returns & refunds')),
        body: _errorState(_error!, onRetry: _load),
      );
    }
    if (workspace == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Returns & refunds')),
        body: const Center(child: Text('Return details are unavailable.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns & refunds'),
        actions: [
          IconButton(
            tooltip: 'Refresh return details',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const ValueKey('buyer-returns-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            _orderCard(workspace),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _inlineError(_errorText(_error!)),
            ],
            if (workspace.canRequest) ...[
              const SizedBox(height: 12),
              _requestForm(workspace),
            ] else ...[
              const SizedBox(height: 12),
              _informationCard(
                workspace.ineligibilityReason ??
                    'A new return request is not available for this Seller Order.',
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Request history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (workspace.cases.isEmpty)
              _informationCard(
                'There are no return or refund requests for this order.',
              )
            else
              for (final request in workspace.cases)
                Card(
                  child: ListTile(
                    key: ValueKey('buyer-return-case-${request.id}'),
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(
                      '${request.reference} · ${_label(request.requestType)}',
                    ),
                    subtitle: Text(
                      '${_label(request.status)} · Requested ${_money(request.requestedAmountMinor)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openCase(request.id),
                  ),
                ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(BuyerReturnWorkspace workspace) => Card(
    color: BearlyColors.cream100,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workspace.storeName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('Seller order ${workspace.sellerOrderReference}'),
          Text(
            'Order ${workspace.orderReference} · ${_label(workspace.status)}',
          ),
          if (workspace.deadline != null)
            Text('Request by ${_dateTime(workspace.deadline!)}'),
          if (workspace.dropoffCenter != null) ...[
            const SizedBox(height: 8),
            Text(
              'Buyer drop-off available at ${workspace.dropoffCenter!['name'] ?? 'the local sorting center'}.',
            ),
          ],
        ],
      ),
    ),
  );

  Widget _requestForm(BuyerReturnWorkspace workspace) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start a request',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Laravel checks eligibility, reserves quantities, and calculates any approved refund.',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const ValueKey('buyer-return-type'),
            initialValue: _requestType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Request type'),
            items: const [
              DropdownMenuItem(
                value: 'refund_only',
                child: Text('Refund only'),
              ),
              DropdownMenuItem(
                value: 'return_refund',
                child: Text('Return item + request refund'),
              ),
            ],
            onChanged: _submitting
                ? null
                : (value) =>
                      setState(() => _requestType = value ?? 'refund_only'),
          ),
          if (_requestType == 'return_refund') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('buyer-return-delivery'),
              isExpanded: true,
              initialValue:
                  _availableDeliveryMethods(
                    workspace,
                  ).any((method) => method.value == _deliveryMethod)
                  ? _deliveryMethod
                  : _availableDeliveryMethods(workspace).firstOrNull?.value,
              decoration: const InputDecoration(labelText: 'Return delivery'),
              items: [
                for (final method in _availableDeliveryMethods(workspace))
                  DropdownMenuItem(
                    value: method.value,
                    child: Text(method.label),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _deliveryMethod = value),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pickup or drop-off begins only after the required review and approval.',
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('buyer-return-reason'),
            isExpanded: true,
            initialValue: _reasonCode,
            decoration: const InputDecoration(labelText: 'Reason'),
            hint: const Text('Choose a reason'),
            items: [
              for (final entry in workspace.reasonCodes.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() => _reasonCode = value),
          ),
          const SizedBox(height: 12),
          for (final item in workspace.items.where(
            (item) => item.returnableQuantity > 0,
          ))
            _quantitySelector(item),
          TextField(
            key: const ValueKey('buyer-return-note'),
            controller: _note,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('buyer-return-add-images'),
            onPressed: _submitting ? null : _pickEvidence,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _evidence.isEmpty
                  ? 'Add evidence photos (optional)'
                  : 'Choose photos (${_evidence.length}/5)',
            ),
          ),
          if (_evidence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_evidence.map((file) => file.fileName).join(' · ')),
            ),
          const SizedBox(height: 8),
          const Text('JPG, PNG, or WebP · up to 5 images · 10 MB each.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('buyer-return-submit'),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_submitting ? 'Submitting…' : 'Submit request'),
          ),
        ],
      ),
    ),
  );

  Widget _quantitySelector(BuyerReturnItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${item.name}${item.variant.isEmpty ? '' : ' · ${item.variant}'}\nUp to ${item.returnableQuantity} of ${item.quantity} eligible',
          ),
        ),
        DropdownButton<int>(
          key: ValueKey('buyer-return-quantity-${item.id}'),
          value: (_quantities[item.id] ?? 0).clamp(0, item.returnableQuantity),
          items: [
            for (
              var quantity = 0;
              quantity <= item.returnableQuantity;
              quantity++
            )
              DropdownMenuItem(value: quantity, child: Text('$quantity')),
          ],
          onChanged: _submitting
              ? null
              : (value) => setState(() => _quantities[item.id] = value ?? 0),
        ),
      ],
    ),
  );

  List<BuyerReturnDeliveryMethod> _availableDeliveryMethods(
    BuyerReturnWorkspace workspace,
  ) => workspace.deliveryMethods.where((method) => method.available).toList();

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? BearlyColors.error : null,
        ),
      );
  }
}

class BuyerReturnCasePage extends StatefulWidget {
  const BuyerReturnCasePage({
    super.key,
    required this.repository,
    required this.returnRequestId,
  });

  final BuyerReturnsDataSource repository;
  final int returnRequestId;

  @override
  State<BuyerReturnCasePage> createState() => _BuyerReturnCasePageState();
}

class _BuyerReturnCasePageState extends State<BuyerReturnCasePage> {
  final _note = TextEditingController();
  final _imagePicker = ImagePicker();
  BuyerReturnCase? _case;
  Object? _error;
  List<BuyerReturnAttachment> _evidence = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.getCase(widget.returnRequestId);
      if (mounted) {
        setState(() {
          _case = result;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickEvidence() async {
    try {
      final selected = await _imagePicker.pickMultiImage(imageQuality: 88);
      if (!mounted || selected.isEmpty) return;
      final files = <BuyerReturnAttachment>[];
      for (final image in selected.take(5)) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          throw const FormatException('Each image must be 10 MB or smaller.');
        }
        if (!const {
          'jpg',
          'jpeg',
          'png',
          'webp',
        }.contains(image.name.split('.').last.toLowerCase())) {
          throw const FormatException('Choose JPG, PNG, or WebP images.');
        }
        files.add(BuyerReturnAttachment(fileName: image.name, bytes: bytes));
      }
      setState(() => _evidence = files);
    } catch (error) {
      if (mounted) _message(_errorText(error), error: true);
    }
  }

  Future<void> _sendEvidence() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final updated = await widget.repository.addEvidence(
        returnRequestId: widget.returnRequestId,
        note: _note.text,
        evidence: _evidence,
      );
      if (!mounted) return;
      setState(() {
        _case = updated;
        _sending = false;
        _note.clear();
        _evidence = const [];
      });
      _message('Additional information sent.');
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        _message(_errorText(error), error: true);
      }
    }
  }

  Future<void> _switchToPickup() async {
    setState(() => _sending = true);
    try {
      final updated = await widget.repository.switchToPickup(
        widget.returnRequestId,
      );
      if (mounted) {
        setState(() {
          _case = updated;
          _sending = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        _message(_errorText(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _case;
    return Scaffold(
      appBar: AppBar(title: const Text('Return request')),
      body: _loading && request == null
          ? const Center(
              child: CircularProgressIndicator(
                key: ValueKey('buyer-return-case-loading'),
              ),
            )
          : _error != null && request == null
          ? _errorState(_error!, onRetry: _load)
          : request == null
          ? const Center(child: Text('Request details are unavailable.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  _panel(
                    title: request.reference,
                    children: [
                      Text(
                        '${_label(request.requestType)} · ${_label(request.status)}',
                        key: const ValueKey('buyer-return-case-status'),
                      ),
                      Text('Store · ${request.storeName}'),
                      if (request.reasonLabel.isNotEmpty)
                        Text('Reason · ${request.reasonLabel}'),
                      if (request.buyerNote?.isNotEmpty == true)
                        Text('Your note · ${request.buyerNote}'),
                      if (request.resolution?.isNotEmpty == true)
                        Text('Update · ${request.resolution}'),
                      if (request.responseDueAt != null)
                        Text(
                          'Seller response due · ${_dateTime(request.responseDueAt!)}',
                        ),
                      if (request.dropoffDueAt != null)
                        Text(
                          'Drop-off deadline · ${_dateTime(request.dropoffDueAt!)}',
                        ),
                      Text(
                        'Requested amount · ${_money(request.requestedAmountMinor)} (subject to review)',
                      ),
                    ],
                  ),
                  if (request.items.isNotEmpty)
                    _panel(
                      title: 'Requested items',
                      children: [
                        for (final item in request.items)
                          Text(
                            '${item.productName} · ${item.quantity} · ${_money(item.refundAmountMinor)}',
                          ),
                      ],
                    ),
                  if (request.shipment != null)
                    _shipmentPanel(request.shipment!, request.refunds),
                  if (request.deliveryMethod == 'rider_pickup' &&
                      request.status == 'return_pickup_requested')
                    _informationCard(
                      'Logistics is arranging Rider pickup from your order address. The return delivery fee is handled separately from the refund.',
                    ),
                  if (request.deliveryMethod == 'buyer_dropoff' &&
                      request.status == 'return_dropoff_pending')
                    _informationCard(
                      'Bring the sealed parcel and present the return waybill at the assigned Logistics Sorting Center. Check the center and due date in Return shipment above.',
                    ),
                  if (request.evidence.isNotEmpty)
                    _panel(
                      title: 'Evidence',
                      children: [
                        for (final item in request.evidence)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.attach_file_rounded),
                            title: Text(item.name),
                            subtitle: Text(
                              '${_label(item.type)} · ${_size(item.sizeBytes)}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Open evidence',
                              onPressed: () => _openEvidence(item),
                              icon: const Icon(Icons.download_rounded),
                            ),
                          ),
                      ],
                    ),
                  if (request.canAddEvidence) _evidenceForm(),
                  if (request.canSwitchToPickup) ...[
                    _informationCard(
                      'The drop-off deadline passed. You can ask Logistics to arrange Rider pickup at your order address.',
                    ),
                    FilledButton(
                      onPressed: _sending ? null : _switchToPickup,
                      child: const Text('Switch to Rider pickup'),
                    ),
                  ],
                  if (request.events.isNotEmpty)
                    _panel(
                      title: 'Case activity',
                      children: [
                        for (final event in request.events)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.circle,
                              size: 10,
                              color: BearlyColors.brown700,
                            ),
                            title: Text(_label(event.type)),
                            subtitle: Text(
                              [
                                if (event.note?.isNotEmpty == true) event.note!,
                                if (event.actorName.isNotEmpty) event.actorName,
                                if (event.occurredAt != null)
                                  _dateTime(event.occurredAt!),
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  if (request.refunds.isNotEmpty) _refundPanel(request.refunds),
                  _informationCard(
                    'Refunds are reviewed and paid outside the app by the existing Bearly process. This screen does not initiate a payout.',
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  Widget _shipmentPanel(
    BuyerReturnShipment shipment,
    List<BuyerReturnRefund> refunds,
  ) {
    final center = shipment.dropoffCenter;
    final address = center == null ? null : center['address'];
    final addressMap = address is Map ? address : null;
    final responsibleParty = refunds
        .map((refund) => refund.financiallyResponsibleParty)
        .whereType<String>()
        .where((party) => party.isNotEmpty)
        .lastOrNull;
    return _panel(
      title: 'Return shipment',
      children: [
        Text('${shipment.reference} · ${_label(shipment.status)}'),
        if (shipment.waybillReference?.isNotEmpty == true)
          Text('Waybill · ${shipment.waybillReference}'),
        if (shipment.shippingFeeMinor > 0)
          Text(
            'Return delivery fee · ${_money(shipment.shippingFeeMinor)}${responsibleParty == null ? '' : ' · covered by ${_label(responsibleParty)}'}. It is handled separately and is not deducted from the refund.',
          ),
        if (center != null)
          Text(
            'Drop-off · ${center['name'] ?? 'Sorting center'}${addressMap == null ? '' : ' · ${[addressMap['street'], addressMap['house_number'], addressMap['barangay'], addressMap['city_municipality'], addressMap['province']].where((part) => part != null && '$part'.isNotEmpty).join(', ')}'}',
          ),
        for (final event in shipment.events)
          Text(
            '${_label(event.type)}${event.note?.isNotEmpty == true ? ' · ${event.note}' : ''}${event.occurredAt == null ? '' : ' · ${_dateTime(event.occurredAt!)}'}',
          ),
      ],
    );
  }

  Widget _refundPanel(List<BuyerReturnRefund> refunds) => _panel(
    title: 'Refund transaction',
    children: [
      for (final refund in refunds) ...[
        if (refund.reference?.isNotEmpty == true)
          Text('Refund ${refund.reference}'),
        Text(
          '${refund.status == 'completed' ? 'Amount paid' : 'Approved amount'} · ${_money(refund.paidAmountMinor ?? refund.approvedAmountMinor)}',
        ),
        Text(
          'Status · ${refund.status == 'completed' ? 'Paid externally' : _label(refund.status)}',
        ),
        if (refund.method?.isNotEmpty == true)
          Text('Payment method · ${_label(refund.method!)}'),
        if (refund.providerReference?.isNotEmpty == true)
          Text('Transaction reference · ${refund.providerReference}'),
        if (refund.paidOn != null)
          Text('Date paid · ${_dateTime(refund.paidOn!)}'),
        if (refund.receiptAvailable)
          if (refund.id != null)
            TextButton.icon(
              onPressed: () => _saveReceipt(refund),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download payout receipt'),
            ),
      ],
    ],
  );

  Future<void> _openEvidence(BuyerReturnEvidence evidence) async {
    try {
      final content = await widget.repository.downloadEvidence(evidence.id);
      if (!mounted) return;
      if (content.mimeType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(
                Uint8List.fromList(content.bytes),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('This image could not be previewed.'),
                ),
              ),
            ),
          ),
        );
      } else {
        final path = await FilePicker.saveFile(
          fileName: evidence.name,
          bytes: Uint8List.fromList(content.bytes),
        );
        if (mounted) {
          _message(
            path == null ? 'File save was cancelled.' : 'Evidence saved.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Could not retrieve this evidence. Check your connection.',
          error: true,
        );
      }
    }
  }

  Future<void> _saveReceipt(BuyerReturnRefund refund) async {
    final id = refund.id;
    if (id == null) return;
    try {
      final content = await widget.repository.downloadRefundReceipt(id);
      final extension = switch (content.mimeType) {
        'application/pdf' => 'pdf',
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
      final path = await FilePicker.saveFile(
        fileName: '${refund.reference ?? 'refund-receipt'}.$extension',
        bytes: Uint8List.fromList(content.bytes),
      );
      if (mounted) {
        _message(
          path == null ? 'File save was cancelled.' : 'Refund receipt saved.',
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Could not retrieve the refund receipt. Check your connection.',
          error: true,
        );
      }
    }
  }

  Widget _evidenceForm() => _panel(
    title: 'Additional evidence requested',
    children: [
      TextField(
        controller: _note,
        maxLength: 1000,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Additional note'),
      ),
      OutlinedButton.icon(
        onPressed: _sending ? null : _pickEvidence,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(
          _evidence.isEmpty
              ? 'Add evidence photos'
              : 'Choose photos (${_evidence.length}/5)',
        ),
      ),
      if (_evidence.isNotEmpty)
        Text(_evidence.map((file) => file.fileName).join(' · ')),
      FilledButton(
        onPressed: _sending ? null : _sendEvidence,
        child: Text(_sending ? 'Sending…' : 'Send additional evidence'),
      ),
    ],
  );

  Widget _panel({required String title, required List<Widget> children}) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children.map(
                (child) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? BearlyColors.error : null,
      ),
    );
  }
}

Widget _errorState(Object error, {required VoidCallback onRetry}) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 42,
          color: BearlyColors.error,
        ),
        const SizedBox(height: 12),
        Text(_errorText(error), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  ),
);

Widget _inlineError(String text) => Card(
  color: BearlyColors.error.withValues(alpha: 0.08),
  child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
);

Widget _informationCard(String text) => Card(
  color: BearlyColors.cream100,
  child: Padding(padding: const EdgeInsets.all(14), child: Text(text)),
);

String _errorText(Object error) => error is FormatException
    ? error.message
    : 'Bearly could not complete the request. Check your connection and try again.';

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _money(int minor) => '₱${(minor / 100).toStringAsFixed(2)}';

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';

String _dateTime(DateTime value) =>
    '${value.toLocal()}'.replaceFirst(RegExp(r'\.\d+$'), '');
