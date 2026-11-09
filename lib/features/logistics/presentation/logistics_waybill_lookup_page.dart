import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../rider/presentation/rider_waybill_scanner_page.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_dashboard.dart';

class LogisticsWaybillLookupPage extends StatefulWidget {
  const LogisticsWaybillLookupPage({
    super.key,
    required this.repository,
    this.scannerPreviewBuilder,
    this.initialIdentifier,
    this.receiptEnabled = false,
    this.handoffEnabled = false,
  });

  final LogisticsRepository repository;
  final WaybillScannerPreviewBuilder? scannerPreviewBuilder;
  final String? initialIdentifier;
  final bool receiptEnabled;
  final bool handoffEnabled;

  @override
  State<LogisticsWaybillLookupPage> createState() =>
      _LogisticsWaybillLookupPageState();
}

class _LogisticsWaybillLookupPageState
    extends State<LogisticsWaybillLookupPage> {
  final _identifierController = TextEditingController();
  LogisticsWaybillLookup? _result;
  String? _errorMessage;
  String? _receiptMessage;
  bool _isLoading = false;
  bool _isReceiving = false;
  bool _isConfirmingHandoff = false;
  bool _isAcceptingHandoff = false;
  bool _needsReconciliation = false;
  bool _receiptBlocked = false;
  bool _handoffBlocked = false;
  String _scanMethod = 'manual';

  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.initialIdentifier ?? '';
  }

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
      _receiptMessage = null;
      _receiptBlocked = false;
      _handoffBlocked = false;
      _scanMethod = 'camera';
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
    if (_isLoading || _isReceiving || _isAcceptingHandoff) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.repository.lookupWaybill(identifier);
      if (mounted) {
        setState(() {
          _result = result;
          if (_needsReconciliation) {
            _needsReconciliation = false;
            final eligible = widget.handoffEnabled
                ? result.handoffAcceptanceEligibility.eligible
                : result.receiptEligibility.eligible;
            final message = widget.handoffEnabled
                ? result.handoffAcceptanceEligibility.message
                : result.receiptEligibility.message;
            _receiptMessage = eligible
                ? 'The server confirms this parcel is still eligible. Review its current details before confirming again.'
                : 'Server state refreshed: $message';
          }
        });
      }
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

  Future<void> _confirmReceipt() async {
    final result = _result;
    if (!widget.receiptEnabled ||
        result == null ||
        !result.receiptEligibility.eligible ||
        _isReceiving ||
        _needsReconciliation) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm incoming parcel receipt'),
        content: Text(
          'Confirm that ${result.waybill} physically arrived at '
          '${result.receivingSortingCenter?.name ?? 'your Sorting Center'}?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('logistics-receipt-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-receipt-confirm-dialog'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm receipt'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) await _receive(result);
  }

  Future<void> _receive(LogisticsWaybillLookup result) async {
    if (_isReceiving || _needsReconciliation) return;
    setState(() {
      _isReceiving = true;
      _errorMessage = null;
      _receiptMessage = 'Sending receipt confirmation to Bearly…';
    });

    try {
      await widget.repository.receiveWaybill(
        result.waybill,
        scanMethod: _scanMethod,
      );

      // A successful POST is followed by a read-only lookup so the screen
      // displays the server-confirmed state, not a locally assumed transition.
      try {
        final refreshed = await widget.repository.lookupWaybill(result.waybill);
        if (mounted) {
          setState(() {
            _result = refreshed;
            _needsReconciliation = false;
            _receiptMessage =
                refreshed.receiptEligibility.code == 'already_received'
                ? 'The server confirms this parcel was received at the Sorting Center.'
                : 'Receipt was accepted. Current state: ${refreshed.receiptEligibility.message}';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _needsReconciliation = true;
            _receiptMessage =
                'Receipt was accepted, but the state refresh failed. Refresh server state before processing this waybill again.';
          });
        }
      }
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409 || error.statusCode >= 500) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage = error.statusCode == 409
              ? 'The server reports a parcel state conflict. Refresh server state before trying again.'
              : 'The result is uncertain. Refresh server state before trying again.';
        });
      } else {
        setState(() {
          _receiptBlocked = const [401, 403, 404].contains(error.statusCode);
          _errorMessage = switch (error.statusCode) {
            401 => 'Your session expired. Sign in again to continue.',
            403 => 'This Logistics account cannot receive parcels right now.',
            404 =>
              'No parcel with that waybill is available to your Logistics account.',
            422 =>
              'The receipt request was invalid. Review the waybill and try again.',
            429 =>
              'Too many receipt requests. Wait a moment before trying again.',
            _ => 'The server rejected the receipt request.',
          };
        });
      }
    } on ApiTimeoutException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain. Refresh server state before trying again.';
        });
      }
    } on ApiTransportException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain because the connection was lost. Refresh server state before trying again.';
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain. Refresh server state before trying again.';
        });
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'Bearly returned an unreadable receipt result. Refresh server state before trying again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain. Refresh server state before trying again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isReceiving = false);
    }
  }

  Future<void> _confirmHandoff() async {
    final result = _result;
    if (!widget.handoffEnabled ||
        result == null ||
        !result.handoffAcceptanceEligibility.eligible ||
        _isConfirmingHandoff ||
        _isAcceptingHandoff ||
        _needsReconciliation ||
        _handoffBlocked) {
      return;
    }

    setState(() => _isConfirmingHandoff = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept incoming city handoff'),
        content: Text(
          'Accept ${result.waybill} from ${result.logisticsProvider} into '
          '${result.receivingSortingCenter?.name ?? result.receivingProvider} '
          'for ${result.receivingProvider}?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('logistics-handoff-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logistics-handoff-confirm-dialog'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Accept handoff'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _isConfirmingHandoff = false);
    if (confirmed == true) await _acceptHandoff(result);
  }

  Future<void> _acceptHandoff(LogisticsWaybillLookup result) async {
    if (_isAcceptingHandoff || _needsReconciliation || _handoffBlocked) return;
    setState(() {
      _isAcceptingHandoff = true;
      _errorMessage = null;
      _receiptMessage = 'Sending acceptance to Bearly…';
    });

    try {
      await widget.repository.acceptHandoff(
        result.waybill,
        scanMethod: _scanMethod,
      );

      try {
        final refreshed = await widget.repository.lookupWaybill(result.waybill);
        if (mounted) {
          setState(() {
            _result = refreshed;
            _needsReconciliation = false;
            _receiptMessage =
                refreshed.handoffAcceptanceEligibility.code ==
                    'already_accepted'
                ? 'The server confirms this handoff was accepted into the destination Sorting Center.'
                : 'Handoff was accepted. Current state: ${refreshed.handoffAcceptanceEligibility.message}';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _needsReconciliation = true;
            _receiptMessage =
                'Handoff was accepted, but the state refresh failed. Refresh server state before processing this waybill again.';
          });
        }
      }
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409 || error.statusCode >= 500) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage = error.statusCode == 409
              ? 'The server reports a handoff state conflict. Refresh server state before trying again.'
              : 'The result is uncertain. Refresh server state before trying again.';
        });
      } else {
        setState(() {
          _handoffBlocked = const [401, 403, 404].contains(error.statusCode);
          _errorMessage = switch (error.statusCode) {
            401 => 'Your session expired. Sign in again to continue.',
            403 => 'This Logistics account cannot accept handoffs right now.',
            404 => 'This waybill is not available to your Logistics account.',
            422 =>
              'The handoff request was invalid. Review the waybill and try again.',
            429 =>
              'Too many handoff requests. Wait a moment before trying again.',
            _ => 'The server rejected the handoff request.',
          };
        });
      }
    } on ApiTimeoutException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain. Refresh server state before trying again.';
        });
      }
    } on ApiTransportException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain because the connection was lost. Refresh server state before trying again.';
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain. Refresh server state before trying again.';
        });
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'Bearly returned an unreadable handoff result. Refresh server state before trying again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _needsReconciliation = true;
          _receiptMessage =
              'The result is uncertain. Refresh server state before trying again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isAcceptingHandoff = false);
    }
  }

  Future<void> _scanAnother() async {
    setState(() {
      _identifierController.clear();
      _result = null;
      _errorMessage = null;
      _receiptMessage = null;
      _receiptBlocked = false;
      _handoffBlocked = false;
      _needsReconciliation = false;
      _scanMethod = 'manual';
    });
    await _scan();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.handoffEnabled
            ? 'Incoming city handoff'
            : widget.receiptEnabled
            ? 'Incoming parcel receipt'
            : 'Waybill lookup',
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.handoffEnabled
                ? 'Incoming City Handoff'
                : widget.receiptEnabled
                ? 'Incoming Parcel Receipt'
                : 'Read-only parcel lookup',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            widget.handoffEnabled
                ? 'Scan or enter a waybill, review the sending and receiving providers, and accept only a handoff addressed to your active Sorting Center.'
                : widget.receiptEnabled
                ? 'Scan or enter a waybill, review the server state, and confirm only after the parcel physically arrives at your Sorting Center.'
                : 'Scan a Code 128 waybill or enter it manually. Looking up a parcel never changes its status or custody.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('logistics-waybill-input'),
            controller: _identifierController,
            maxLength: 120,
            enabled:
                !_isLoading &&
                !_isReceiving &&
                !_isConfirmingHandoff &&
                !_isAcceptingHandoff &&
                !_needsReconciliation,
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
                  _receiptMessage = null;
                  _receiptBlocked = false;
                  _handoffBlocked = false;
                  _needsReconciliation = false;
                  _scanMethod = 'manual';
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
                  onPressed:
                      _isLoading ||
                          _isReceiving ||
                          _isConfirmingHandoff ||
                          _isAcceptingHandoff ||
                          _needsReconciliation
                      ? null
                      : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan with camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('logistics-lookup-waybill'),
                  onPressed:
                      _isLoading ||
                          _isReceiving ||
                          _isConfirmingHandoff ||
                          _isAcceptingHandoff
                      ? null
                      : _lookup,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(
                    _isLoading
                        ? 'Looking up'
                        : _needsReconciliation
                        ? 'Refresh server state'
                        : 'Look up',
                  ),
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
          if (_receiptMessage != null && !widget.handoffEnabled) ...[
            const SizedBox(height: 12),
            _messageCard(
              icon: _needsReconciliation
                  ? Icons.sync_problem_rounded
                  : Icons.info_outline_rounded,
              message: _receiptMessage!,
              isError: _needsReconciliation,
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
          _detail(
            widget.handoffEnabled
                ? 'Source Logistics provider'
                : 'Logistics provider',
            result.logisticsProvider,
          ),
          if (widget.receiptEnabled) ...[
            _detail('Receiving provider', result.receivingProvider),
            if (result.receivingSortingCenter != null)
              _detail(
                'Receiving Sorting Center',
                '${result.receivingSortingCenter!.name} (${result.receivingSortingCenter!.code})',
              ),
          ],
          if (widget.handoffEnabled) ...[
            _detail('Destination Logistics provider', result.receivingProvider),
            if (result.receivingSortingCenter != null)
              _detail(
                'Intended Sorting Center',
                '${result.receivingSortingCenter!.name} (${result.receivingSortingCenter!.code})',
              ),
          ],
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
            message: widget.handoffEnabled
                ? result.handoffAcceptanceEligibility.message
                : widget.receiptEnabled
                ? result.receiptEligibility.message
                : result.guidance,
            isError: false,
          ),
          if (widget.handoffEnabled && _receiptMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _messageCard(
                icon: _needsReconciliation
                    ? Icons.sync_problem_rounded
                    : Icons.info_outline_rounded,
                message: _receiptMessage!,
                isError: _needsReconciliation,
              ),
            ),
          if (widget.receiptEnabled &&
              result.receiptEligibility.eligible &&
              !_needsReconciliation &&
              !_receiptBlocked)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('logistics-confirm-receipt'),
                  onPressed: _isReceiving ? null : _confirmReceipt,
                  icon: _isReceiving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    _isReceiving ? 'Confirming receipt' : 'Confirm Receipt',
                  ),
                ),
              ),
            ),
          if (widget.handoffEnabled &&
              result.handoffAcceptanceEligibility.eligible &&
              !_needsReconciliation &&
              !_handoffBlocked)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('logistics-confirm-handoff'),
                  onPressed: _isConfirmingHandoff || _isAcceptingHandoff
                      ? null
                      : _confirmHandoff,
                  icon: _isAcceptingHandoff
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_rounded),
                  label: Text(
                    _isConfirmingHandoff || _isAcceptingHandoff
                        ? 'Accepting handoff'
                        : 'Accept Handoff',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('logistics-scan-another'),
              onPressed:
                  _isLoading ||
                      _isReceiving ||
                      _isConfirmingHandoff ||
                      _isAcceptingHandoff ||
                      _needsReconciliation
                  ? null
                  : _scanAnother,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                widget.handoffEnabled
                    ? 'Process another incoming handoff'
                    : widget.receiptEnabled
                    ? 'Process another incoming parcel'
                    : 'Scan another parcel',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _parcelTile(LogisticsLookupParcel parcel) {
    final intakeRecorded = parcel.centerIntakeRecordedAt.isNotEmpty;
    final lastCenter = parcel.lastRecordedCenter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
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
        ),
        for (final product in parcel.products)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 12),
            leading: ProductThumbnail(
              imageUrl: product.imageUrl,
              size: 48,
              semanticLabel: product.name,
            ),
            title: Text(product.name.isEmpty ? 'Purchased item' : product.name),
            subtitle: Text(
              [
                if (product.variant.isNotEmpty) product.variant,
                'Qty ${product.quantity}',
              ].join(' / '),
            ),
          ),
      ],
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
