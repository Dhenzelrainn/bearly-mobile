import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../rider/presentation/rider_waybill_scanner_page.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_incoming_parcel.dart';
import 'logistics_waybill_lookup_page.dart';

class LogisticsIncomingParcelsPage extends StatefulWidget {
  const LogisticsIncomingParcelsPage({
    super.key,
    required this.repository,
    this.scannerPreviewBuilder,
  });

  final LogisticsRepository repository;
  final WaybillScannerPreviewBuilder? scannerPreviewBuilder;

  @override
  State<LogisticsIncomingParcelsPage> createState() =>
      _LogisticsIncomingParcelsPageState();
}

class _LogisticsIncomingParcelsPageState
    extends State<LogisticsIncomingParcelsPage> {
  final _searchController = TextEditingController();
  final _destinationController = TextEditingController();
  List<LogisticsIncomingParcelRecord> _parcels = const [];
  String? _status;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore || (_loading && !reset)) return;
    final requestedPage = reset ? 1 : _currentPage + 1;
    setState(() {
      if (reset) _loading = true;
      if (!reset) _loadingMore = true;
      _error = null;
    });

    try {
      final result = await widget.repository.incomingParcels(
        status: _status,
        search: _searchController.text,
        destination: _destinationController.text,
        page: requestedPage,
      );
      if (!mounted) return;
      setState(() {
        _parcels = reset ? result.parcels : [..._parcels, ...result.parcels];
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
        _total = result.total;
      });
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = switch (error.statusCode) {
          401 => 'Your session expired. Sign in again to continue.',
          403 => 'This Logistics account cannot view incoming parcels.',
          429 => 'Too many requests. Wait a moment and try again.',
          _ => 'Incoming parcels could not be loaded. Try again shortly.',
        },
      );
    } on ApiTimeoutException {
      if (mounted) {
        setState(
          () => _error =
              'The request timed out. Check your connection and retry.',
        );
      }
    } on ApiTransportException {
      if (mounted) {
        setState(
          () => _error =
              'Could not reach Bearly. Check your connection and retry.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _error = 'Bearly returned parcel data in an unexpected format.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Incoming parcels could not be loaded. Try again shortly.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openScanner(String? identifier) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LogisticsWaybillLookupPage(
          repository: widget.repository,
          initialIdentifier: identifier,
        ),
      ),
    );
  }

  Future<void> _openDetails(LogisticsIncomingParcelRecord parcel) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LogisticsIncomingParcelDetailPage(
          repository: widget.repository,
          waybill: parcel.waybill,
          scannerPreviewBuilder: widget.scannerPreviewBuilder,
        ),
      ),
    );
    if (mounted) await _load(reset: true);
  }

  void _applyFilters() {
    FocusScope.of(context).unfocus();
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Incoming Parcels')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('logistics-incoming-scan-waybill'),
                    onPressed: _loading ? null : () => _openScanner(null),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan or look up a waybill'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open a waybill group to scan an individual Parcel, review server eligibility, and record one-piece intake.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('logistics-incoming-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyFilters(),
                  decoration: const InputDecoration(
                    labelText: 'Search waybill, order, Seller, or Rider',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('logistics-incoming-destination'),
                  controller: _destinationController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyFilters(),
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('logistics-incoming-status-filter'),
                        initialValue: _status ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Intake status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('All statuses'),
                          ),
                          DropdownMenuItem(
                            value: 'awaiting_intake',
                            child: Text('Awaiting Intake'),
                          ),
                          DropdownMenuItem(
                            value: 'received',
                            child: Text('Received'),
                          ),
                          DropdownMenuItem(
                            value: 'sorted',
                            child: Text('Sorted'),
                          ),
                          DropdownMenuItem(
                            value: 'exception',
                            child: Text('Exception'),
                          ),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) => setState(
                                () => _status = value == null || value.isEmpty
                                    ? null
                                    : value,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('logistics-incoming-apply-filters'),
                      onPressed: _loading ? null : _applyFilters,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _content(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _content() {
    if (_error != null && _parcels.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (!_loading && _parcels.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.inventory_2_outlined, size: 42),
          const SizedBox(height: 12),
          const Center(child: Text('No incoming parcels match these filters.')),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Pull down to refresh or scan a waybill to view its read-only status.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: _parcels.length + 1,
      itemBuilder: (context, index) {
        if (index == _parcels.length) return _paginationFooter();
        final parcel = _parcels[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            key: ValueKey('incoming-parcel-${parcel.waybill}'),
            leading: const CircleAvatar(
              child: Icon(Icons.inventory_2_outlined),
            ),
            title: Text(parcel.waybill),
            subtitle: Text(
              '${_statusLabel(parcel.status)} · ${parcel.receivedPieceCount} of ${parcel.expectedPieceCount} pieces received\n'
              '${parcel.seller} · ${parcel.destination}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDetails(parcel),
          ),
        );
      },
    );
  }

  Widget _paginationFooter() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: _loadingMore ? null : () => _load(),
              child: const Text('Retry loading more'),
            ),
          ],
        ),
      );
    }
    if (_currentPage >= _lastPage || _parcels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            '$_total waybill groups',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton(
          key: const ValueKey('logistics-incoming-load-more'),
          onPressed: _loadingMore ? null : () => _load(),
          child: Text(_loadingMore ? 'Loading…' : 'Load more'),
        ),
      ),
    );
  }
}

class LogisticsIncomingParcelDetailPage extends StatefulWidget {
  const LogisticsIncomingParcelDetailPage({
    super.key,
    required this.repository,
    required this.waybill,
    this.scannerPreviewBuilder,
  });

  final LogisticsRepository repository;
  final String waybill;
  final WaybillScannerPreviewBuilder? scannerPreviewBuilder;

  @override
  State<LogisticsIncomingParcelDetailPage> createState() =>
      _LogisticsIncomingParcelDetailPageState();
}

class _LogisticsIncomingParcelDetailPageState
    extends State<LogisticsIncomingParcelDetailPage> {
  final _barcodeController = TextEditingController();
  late Future<LogisticsIncomingParcelRecord> _parcel;
  String? _selectedParcelNumber;
  String? _selectedSizeClass;
  String? _actionMessage;
  bool _isReceiving = false;
  bool _requiresRefresh = false;
  String _scanMethod = 'manual';

  @override
  void initState() {
    super.initState();
    _parcel = widget.repository.incomingParcel(widget.waybill);
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = widget.repository.incomingParcel(widget.waybill);
    setState(() {
      _parcel = next;
    });
    try {
      await next;
      if (mounted) setState(() => _requiresRefresh = false);
    } catch (_) {
      // FutureBuilder displays the current request error and retains retry.
    }
  }

  Future<void> _openReadOnlyLookup() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => LogisticsWaybillLookupPage(
        repository: widget.repository,
        initialIdentifier: widget.waybill,
      ),
    ),
  );

  Future<void> _scanPiece(LogisticsIncomingParcelRecord parcel) async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RiderWaybillScannerPage(
          previewBuilder: widget.scannerPreviewBuilder,
        ),
      ),
    );
    if (!mounted || scannedValue == null || scannedValue.trim().isEmpty) return;
    _barcodeController.text = scannedValue;
    _selectPiece(parcel, scannedValue, scanMethod: 'barcode');
  }

  void _selectPiece(
    LogisticsIncomingParcelRecord parcel,
    String value, {
    required String scanMethod,
  }) {
    final barcode = value.trim();
    LogisticsIncomingParcelPiece? matched;
    for (final piece in parcel.pieces) {
      if (piece.parcel == barcode) {
        matched = piece;
        break;
      }
    }

    setState(() {
      _scanMethod = scanMethod;
      _selectedParcelNumber = matched?.parcel;
      _selectedSizeClass = null;
      _actionMessage = matched == null
          ? 'No Parcel in this Waybill matches that exact barcode.'
          : 'Selected piece ${matched.pieceSequence}: ${matched.parcel}.';
    });
  }

  Future<void> _confirmReceipt(
    LogisticsIncomingParcelRecord parcel,
    LogisticsIncomingParcelPiece piece,
  ) async {
    if (_isReceiving ||
        _requiresRefresh ||
        !piece.receiptEligibility.eligible ||
        _selectedSizeClass == null) {
      return;
    }

    final centerName =
        parcel.receivingSortingCenter?.name ?? 'your Sorting Center';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm single-parcel intake'),
        content: Text(
          'Receive ${piece.parcel} as ${_selectedSizeClass!} at $centerName?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('logistics-piece-receipt-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-piece-receipt-confirm-dialog'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm intake'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _receivePiece(parcel, piece);
  }

  Future<void> _receivePiece(
    LogisticsIncomingParcelRecord parcel,
    LogisticsIncomingParcelPiece piece,
  ) async {
    if (_isReceiving || _requiresRefresh) return;
    setState(() {
      _isReceiving = true;
      _actionMessage = 'Recording intake for ${piece.parcel}…';
    });

    try {
      final receipt = await widget.repository.receiveParcel(
        waybill: parcel.waybill,
        parcel: piece.parcel,
        sizeClass: _selectedSizeClass!,
        scanMethod: _scanMethod,
      );
      if (!mounted) return;
      final receivedPieces = parcel.pieces
          .map(
            (current) => current.parcel == receipt.piece.parcel
                ? receipt.piece
                : current,
          )
          .toList(growable: false);
      setState(() {
        _parcel = Future.value(
          receipt.waybill.withPieces(
            receivedPieces,
            receivingCenter: parcel.receivingSortingCenter,
            availableSizeClasses: parcel.sizeClasses,
          ),
        );
        _actionMessage = receipt.evidence?.occurredAt == null
            ? 'Bearly confirmed intake for ${receipt.piece.parcel}.'
            : 'Bearly confirmed intake for ${receipt.piece.parcel} at ${_date(receipt.evidence!.occurredAt!)}.';
      });
      await _refresh();
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      setState(() {
        _actionMessage = switch (error.statusCode) {
          401 => 'Your session expired. Sign in again to continue.',
          403 => 'This Logistics account cannot receive this Parcel.',
          404 => 'This Parcel is not available to your Logistics provider.',
          409 =>
            'The Parcel state changed. Refresh and review its eligibility.',
          422 => error.message,
          429 => 'Too many intake scans. Wait a moment and try again.',
          _ =>
            'Parcel intake was rejected. Refresh and review the current state.',
        };
      });
      if (error.statusCode == 409) await _refresh();
    } on ApiTimeoutException {
      if (mounted) {
        setState(() {
          _requiresRefresh = true;
          _actionMessage =
              'The request timed out. Refresh server state before any further intake attempt.';
        });
      }
    } on ApiTransportException {
      if (mounted) {
        setState(() {
          _requiresRefresh = true;
          _actionMessage =
              'The connection was lost. Refresh server state before any further intake attempt.';
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _requiresRefresh = true;
          _actionMessage = error.message;
        });
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          _requiresRefresh = true;
          _actionMessage =
              'Bearly returned an incomplete receipt confirmation. Refresh server state before trying again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _requiresRefresh = true;
          _actionMessage =
              'Receipt state could not be confirmed. Refresh server state before trying again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isReceiving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Parcel details')),
    body: FutureBuilder<LogisticsIncomingParcelRecord>(
      future: _parcel,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Parcel details are unavailable. Check access or connection and retry.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: _details(snapshot.data!),
        );
      },
    ),
  );

  Widget _details(LogisticsIncomingParcelRecord parcel) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parcel.waybill,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(label: Text(_statusLabel(parcel.status))),
                  Chip(label: Text(_purposeLabel(parcel.purpose))),
                ],
              ),
              Text(
                'Shipment ${parcel.shipmentReference} · ${_statusLabel(parcel.shipmentStatus)}',
              ),
              Text('Seller: ${parcel.seller}'),
              Text('Received from: ${parcel.receivedFrom}'),
              Text('Destination: ${parcel.destination}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _count('Expected', parcel.expectedPieceCount),
                  _count('Parcel records', parcel.parcelRecordCount),
                  _count('Received', parcel.receivedPieceCount),
                  _count('Remaining', parcel.remainingPieceCount),
                ],
              ),
              Text(
                '${parcel.receivedPieceCount} of ${parcel.expectedPieceCount} pieces received · ${parcel.remainingPieceCount} remaining',
              ),
              if (parcel.currentSortingCenters.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Current Sorting Center: ${parcel.currentSortingCenters.map((center) => '${center.name} (${center.code})').join(', ')}',
                ),
              ],
              if (parcel.receivedAt != null) ...[
                const SizedBox(height: 6),
                Text('Latest recorded intake: ${_date(parcel.receivedAt!)}'),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      _pieceIntakeControls(parcel),
      if (_actionMessage != null) ...[
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            key: const ValueKey('logistics-piece-intake-message'),
            leading: Icon(
              _requiresRefresh ? Icons.sync_problem : Icons.info_outline,
            ),
            title: Text(_actionMessage!),
          ),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const ValueKey('logistics-incoming-open-readonly-scanner'),
        onPressed: _openReadOnlyLookup,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan or look up waybill'),
      ),
      const SizedBox(height: 12),
      Text('Parcel pieces', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      if (parcel.pieces.isEmpty)
        const Card(
          child: ListTile(
            title: Text('No parcel records are attached to this waybill.'),
          ),
        )
      else
        ...parcel.pieces.map(_pieceCard),
    ],
  );

  Widget _pieceIntakeControls(LogisticsIncomingParcelRecord parcel) {
    final selectedPieces = parcel.pieces.where(
      (piece) => piece.parcel == _selectedParcelNumber,
    );
    final selectedPiece = selectedPieces.isEmpty ? null : selectedPieces.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receive one parcel',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Scan or enter the individual Parcel barcode. Intake applies only to the exact selected piece.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
            ),
            if (parcel.receivingSortingCenter case final center?) ...[
              const SizedBox(height: 8),
              Text('Receiving center: ${center.name} (${center.code})'),
            ] else ...[
              const SizedBox(height: 8),
              const Text('An active Sorting Center is required before intake.'),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('logistics-piece-barcode-input'),
              controller: _barcodeController,
              maxLength: 120,
              enabled: !_isReceiving,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Individual Parcel barcode',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_selectedParcelNumber != null) {
                  setState(() {
                    _selectedParcelNumber = null;
                    _selectedSizeClass = null;
                    _actionMessage = null;
                    _scanMethod = 'manual';
                  });
                }
              },
              onSubmitted: (value) =>
                  _selectPiece(parcel, value, scanMethod: 'manual'),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('logistics-scan-piece-barcode'),
                    onPressed: _isReceiving ? null : () => _scanPiece(parcel),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan piece'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    key: const ValueKey('logistics-select-piece-barcode'),
                    onPressed: _isReceiving
                        ? null
                        : () => _selectPiece(
                            parcel,
                            _barcodeController.text,
                            scanMethod: 'manual',
                          ),
                    child: const Text('Find exact piece'),
                  ),
                ),
              ],
            ),
            if (selectedPiece != null) ...[
              const Divider(height: 24),
              Text(
                'Selected piece ${selectedPiece.pieceSequence}: ${selectedPiece.parcel}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(selectedPiece.receiptEligibility.message),
              if (selectedPiece.receiptEligibility.eligible &&
                  parcel.sizeClasses.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const ValueKey('logistics-piece-size-class'),
                  initialValue: _selectedSizeClass,
                  decoration: const InputDecoration(
                    labelText: 'Parcel size class',
                    border: OutlineInputBorder(),
                  ),
                  items: parcel.sizeClasses
                      .map(
                        (sizeClass) => DropdownMenuItem(
                          value: sizeClass,
                          child: Text(_statusLabel(sizeClass)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isReceiving
                      ? null
                      : (value) => setState(() => _selectedSizeClass = value),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('logistics-confirm-piece-intake'),
                    onPressed:
                        _isReceiving ||
                            _requiresRefresh ||
                            _selectedSizeClass == null
                        ? null
                        : () => _confirmReceipt(parcel, selectedPiece),
                    icon: _isReceiving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.inventory_2_outlined),
                    label: Text(
                      _isReceiving
                          ? 'Recording intake'
                          : 'Confirm single-parcel intake',
                    ),
                  ),
                ),
              ] else if (selectedPiece.receiptEligibility.eligible) ...[
                const SizedBox(height: 8),
                const Text(
                  'No size classes are currently available from the server.',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _count(String label, int value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$value', style: Theme.of(context).textTheme.titleMedium),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _pieceCard(LogisticsIncomingParcelPiece piece) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Piece ${piece.pieceSequence} · ${piece.parcel}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('Status: ${_statusLabel(piece.status)}'),
          Text(
            'Weight: ${piece.weightKg} kg${piece.sizeClass == null ? '' : ' · ${piece.sizeClass}'}',
          ),
          if (piece.currentSortingCenter != null)
            Text(
              'Current center: ${piece.currentSortingCenter!.name} (${piece.currentSortingCenter!.code})',
            ),
          const SizedBox(height: 8),
          Text(
            'Intake and sorting history',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (piece.intakeHistory.isEmpty)
            Text(
              'No recorded intake or sorting events.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...piece.intakeHistory.map(
              (event) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(_eventLabel(event.event)),
                subtitle: Text(
                  [
                    if (event.sortingCenterName.isNotEmpty)
                      '${event.sortingCenterName}${event.sortingCenterCode.isEmpty ? '' : ' (${event.sortingCenterCode})'}',
                    '${_statusLabel(event.fromStatus)} → ${_statusLabel(event.toStatus)}',
                    if (event.scanMethod.isNotEmpty)
                      'Scan: ${event.scanMethod}',
                    if (event.occurredAt != null) _date(event.occurredAt!),
                  ].join(' · '),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

String _statusLabel(String value) => value
    .split('_')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _purposeLabel(String value) =>
    value == 'return' ? 'Return to Seller' : 'Buyer delivery';

String _eventLabel(String value) => switch (value) {
  'received_at_center' => 'Received at Sorting Center',
  'logistics_handoff_accepted' => 'City handoff accepted',
  'parcel_sorted' => 'Sorted',
  'parcel_resorted' => 'Resorted',
  _ => _statusLabel(value),
};

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
