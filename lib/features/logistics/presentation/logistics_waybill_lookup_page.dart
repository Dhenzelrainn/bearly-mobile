import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../rider/presentation/rider_waybill_scanner_page.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_dashboard.dart';

class LogisticsWaybillLookupPage extends StatefulWidget {
  const LogisticsWaybillLookupPage({
    super.key,
    required this.repository,
    this.scannerPreviewBuilder,
  });

  final LogisticsRepository repository;
  final WaybillScannerPreviewBuilder? scannerPreviewBuilder;

  @override
  State<LogisticsWaybillLookupPage> createState() =>
      _LogisticsWaybillLookupPageState();
}

class _LogisticsWaybillLookupPageState
    extends State<LogisticsWaybillLookupPage> {
  final _identifierController = TextEditingController();
  LogisticsWaybillLookup? _result;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RiderWaybillScannerPage(
          previewBuilder: widget.scannerPreviewBuilder,
        ),
      ),
    );
    if (!mounted || scannedValue == null || scannedValue.trim().isEmpty) return;

    setState(() {
      // Keep the scanner's exact Code 128 value for display and lookup.
      _identifierController.text = scannedValue;
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _lookup() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _result = null;
        _errorMessage = 'Enter or scan a waybill before looking it up.';
      });
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final result = await widget.repository.lookupWaybill(identifier);
      if (mounted) setState(() => _result = result);
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = switch (error.statusCode) {
          401 => 'Your session expired. Sign in again to continue.',
          403 =>
            'This Logistics account cannot perform waybill lookups right now.',
          404 =>
            'No parcel with that waybill is available to your Logistics account.',
          422 => 'Enter a valid waybill or barcode value and try again.',
          429 => 'Too many lookups. Wait a moment and try again.',
          _ => 'The server could not complete the lookup. Try again shortly.',
        },
      );
    } on ApiTimeoutException {
      if (mounted) {
        setState(
          () => _errorMessage =
              'The lookup timed out. Check your connection and try again.',
        );
      }
    } on ApiTransportException {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Could not reach Bearly. Check your connection and try again.',
        );
      }
    } on ApiException {
      if (mounted) {
        setState(
          () => _errorMessage =
              'The lookup could not be completed. Try again shortly.',
        );
      }
    } on FormatException {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Bearly returned parcel data in an unexpected format.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'The lookup could not be completed. Try again shortly.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanAnother() async {
    setState(() {
      _identifierController.clear();
      _result = null;
      _errorMessage = null;
    });
    await _scan();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Waybill lookup')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Read-only parcel lookup',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Scan a Code 128 waybill or enter it manually. Looking up a parcel never changes its status or custody.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('logistics-waybill-input'),
            controller: _identifierController,
            maxLength: 120,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Waybill or barcode',
              hintText: 'BRLY-…',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorMessage != null || _result != null) {
                setState(() {
                  _errorMessage = null;
                  _result = null;
                });
              }
            },
            onSubmitted: (_) => _isLoading ? null : _lookup(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('logistics-scan-waybill'),
                  onPressed: _isLoading ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan with camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('logistics-lookup-waybill'),
                  onPressed: _isLoading ? null : _lookup,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(_isLoading ? 'Looking up' : 'Look up'),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _messageCard(
              icon: Icons.info_outline_rounded,
              message: _errorMessage!,
              isError: true,
            ),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 18),
            _resultCard(result),
          ],
        ],
      ),
    ),
  );

  Widget _resultCard(LogisticsWaybillLookup result) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.waybill,
                  key: const ValueKey('logistics-waybill-result'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _detail('Shipment', result.shipmentReference),
          _detail('Shipment status', _statusLabel(result.shipmentStatus)),
          _detail('Logistics provider', result.logisticsProvider),
          _detail('Destination', _destinationLabel(result.destination)),
          if (result.currentSortingCenter != null)
            _detail(
              'Current Sorting Center',
              '${result.currentSortingCenter!.name} (${result.currentSortingCenter!.code})',
            ),
          if (result.handoff case final handoff?) ...[
            const SizedBox(height: 8),
            Text(
              'Logistics handoff',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _detail('Status', _statusLabel(handoff.status)),
            if (handoff.fromProvider.isNotEmpty)
              _detail('From', handoff.fromProvider),
            if (handoff.toProvider.isNotEmpty)
              _detail('To', handoff.toProvider),
          ],
          const SizedBox(height: 12),
          Text('Parcels', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ...result.parcels.map(_parcelTile),
          const SizedBox(height: 12),
          _messageCard(
            icon: result.terminal
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            message: result.guidance,
            isError: false,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('logistics-scan-another'),
              onPressed: _isLoading ? null : _scanAnother,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan another parcel'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _parcelTile(LogisticsLookupParcel parcel) {
    final intakeRecorded = parcel.centerIntakeRecordedAt.isNotEmpty;
    final lastCenter = parcel.lastRecordedCenter;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.local_mall_outlined),
      title: Text(parcel.reference),
      subtitle: Text(
        [
          'Current status: ${_statusLabel(parcel.status)}',
          if (parcel.currentSortingCenter != null)
            'Currently at ${parcel.currentSortingCenter!.name}',
          if (lastCenter != null && parcel.currentSortingCenter == null)
            'Last recorded at ${lastCenter.name}',
          if (intakeRecorded) 'Center intake is historical',
        ].join(' · '),
      ),
      trailing: parcel.terminal
          ? const Icon(Icons.check_circle_outline_rounded)
          : null,
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? 'Not available' : value)),
      ],
    ),
  );

  Widget _messageCard({
    required IconData icon,
    required String message,
    required bool isError,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError
          ? Colors.red.withValues(alpha: 0.06)
          : Colors.brown.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isError ? Colors.red.shade700 : BearlyColors.brown700,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );

  String _destinationLabel(LogisticsDestination destination) => [
    destination.barangay,
    destination.city,
    destination.province,
  ].where((part) => part.isNotEmpty).join(', ');

  String _statusLabel(String value) => value
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
