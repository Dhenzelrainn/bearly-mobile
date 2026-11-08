import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_pickup_request.dart';

class LogisticsPickupRequestsPage extends StatefulWidget {
  const LogisticsPickupRequestsPage({super.key, required this.repository});

  final LogisticsRepository repository;

  @override
  State<LogisticsPickupRequestsPage> createState() =>
      _LogisticsPickupRequestsPageState();
}

class _LogisticsPickupRequestsPageState
    extends State<LogisticsPickupRequestsPage> {
  List<LogisticsPickupRequest> _requests = const [];
  String? _status;
  String? _error;
  int _page = 0;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({bool reset = false, bool append = false}) async {
    if (_loadingMore || (_loading && !reset)) return;
    final nextPage = append ? _page + 1 : 1;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
      _error = null;
    });

    try {
      final result = await widget.repository.pickupRequests(
        status: _status,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _requests = append
            ? [..._requests, ...result.requests]
            : result.requests;
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiHttpException &&
        (error.statusCode == 401 || error.statusCode == 403)) {
      return 'Your Logistics session is no longer authorized.';
    }
    return 'Could not load pickup requests. Check your connection and retry.';
  }

  Future<void> _openPickup(LogisticsPickupRequest pickup) async {
    await Navigator.of(context).pushNamed(
      AppRouteNames.logisticsPickupRequestDetails,
      arguments: pickup.id,
    );
    if (!mounted) return;
    await _load(reset: true);
  }

  void _changeStatus(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pickup Requests'),
      actions: [
        IconButton(
          key: const ValueKey('logistics-pickup-requests-refresh'),
          tooltip: 'Refresh pickup requests',
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('logistics-pickup-status-filter'),
            initialValue: _status ?? '',
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.filter_list_rounded),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('All statuses')),
              DropdownMenuItem(value: 'requested', child: Text('Pending')),
              DropdownMenuItem(value: 'verified', child: Text('Verified')),
              DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
              DropdownMenuItem(value: 'completed', child: Text('Collected')),
              DropdownMenuItem(value: 'cancelled', child: Text('Rejected')),
            ],
            onChanged: (value) =>
                _changeStatus(value == null || value.isEmpty ? null : value),
          ),
        ),
        if (_error != null && _requests.isNotEmpty)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(
                onPressed: () => _load(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_loading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _requests.isEmpty) {
      return _emptyScroll(
        Center(
          child: _ProblemState(
            message: _error!,
            onRetry: () => _load(reset: true),
          ),
        ),
      );
    }
    if (_requests.isEmpty) {
      return _emptyScroll(
        const Center(
          child: _EmptyState(message: 'No pickup requests match this status.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        key: const ValueKey('logistics-pickup-requests-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _requests.length + (_page < _lastPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _requests.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                key: const ValueKey('logistics-pickup-load-more'),
                onPressed: _loadingMore ? null : () => _load(append: true),
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_loadingMore ? 'Loading…' : 'Load more requests'),
              ),
            );
          }
          final pickup = _requests[index];
          return _PickupRequestCard(
            pickup: pickup,
            onTap: () => _openPickup(pickup),
          );
        },
      ),
    );
  }

  Widget _emptyScroll(Widget child) => RefreshIndicator(
    onRefresh: () => _load(reset: true),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: 340, child: child)],
    ),
  );
}

class _PickupRequestCard extends StatelessWidget {
  const _PickupRequestCard({required this.pickup, required this.onTap});

  final LogisticsPickupRequest pickup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pickup.reference,
                    key: const ValueKey('logistics-pickup-reference'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(label: pickup.statusLabel),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              pickup.isReturnPickup ? 'Buyer return pickup' : pickup.storeName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            _IconText(
              icon: Icons.location_on_outlined,
              text: pickup.pickupLocation,
            ),
            const SizedBox(height: 6),
            _IconText(
              icon: Icons.inventory_2_outlined,
              text:
                  '${pickup.parcelCount} ${pickup.parcelCount == 1 ? 'parcel' : 'parcels'}'
                  '${pickup.sellerOrderReferences.isEmpty ? '' : ' · ${pickup.sellerOrderReferences.join(', ')}'}',
            ),
            if (pickup.requestedDate != null) ...[
              const SizedBox(height: 6),
              _IconText(
                icon: Icons.schedule_rounded,
                text: _dateLabel(pickup.requestedDate!),
              ),
            ],
            if (pickup.assignedRider != null) ...[
              const SizedBox(height: 8),
              _IconText(
                icon: Icons.delivery_dining_rounded,
                text:
                    '${pickup.assignedRider!.name} · ${_headline(pickup.assignedRider!.assignmentStatus)}',
              ),
            ],
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.chevron_right_rounded,
                color: BearlyColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    side: BorderSide.none,
    backgroundColor: BearlyColors.cream200,
  );
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: BearlyColors.muted),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

class _ProblemState extends StatelessWidget {
  const _ProblemState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String _headline(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
