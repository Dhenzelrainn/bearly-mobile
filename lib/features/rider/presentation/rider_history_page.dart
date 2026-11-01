import 'package:flutter/material.dart';

import '../../../core/routes/app_route_names.dart';
import '../data/rider_repository.dart';
import '../models/rider_history.dart';
import '../widgets/rider_shared_widgets.dart';

class RiderHistoryPage extends StatefulWidget {
  const RiderHistoryPage({super.key, required this.repository});

  final RiderRepository repository;

  @override
  State<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends State<RiderHistoryPage> {
  final _search = TextEditingController();
  late Future<RiderHistory> _history;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _history = widget.repository.history();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch([String? value]) {
    if (value != null) _search.text = value;
    setState(() => _history = widget.repository.history(search: _search.text));
  }

  Future<void> _loadMore(RiderHistory current) async {
    setState(() => _loadingMore = true);
    try {
      final next = await widget.repository.history(
        search: _search.text,
        page: current.currentPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _history = Future.value(
          RiderHistory(
            entries: [...current.entries, ...next.entries],
            currentPage: next.currentPage,
            lastPage: next.lastPage,
            total: next.total,
          ),
        );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load more history.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    currentRoute: AppRouteNames.riderHistory,
    title: 'Delivery History',
    subtitle: 'Completed, canceled, returned, and failed Rider assignments.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: _runSearch,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search shipment, parcel, or area',
            suffixIcon: IconButton(
              tooltip: 'Search history',
              onPressed: _runSearch,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<RiderHistory>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _message(
                context,
                'Could not load delivery history. Check your connection and retry.',
                onRetry: _runSearch,
              );
            }

            final history = snapshot.data;
            if (history == null || history.entries.isEmpty) {
              return _message(
                context,
                'No delivery history is available for this Rider account.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Showing ${history.entries.length} of ${history.total} records',
                ),
                const SizedBox(height: 8),
                ...history.entries.map((entry) => _entry(context, entry)),
                if (history.currentPage < history.lastPage)
                  Center(
                    child: TextButton.icon(
                      onPressed: _loadingMore ? null : () => _loadMore(history),
                      icon: _loadingMore
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(_loadingMore ? 'Loading' : 'Load more'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _entry(BuildContext context, RiderHistoryEntry entry) => Card(
    color: Colors.white,
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
      title: Text(entry.shipmentNumber),
      subtitle: Text(
        [
          entry.parcelNumber,
          entry.area,
          entry.date,
        ].where((value) => value.isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(entry.statusLabel),
          Text(entry.earning, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );

  Widget _message(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
        ],
      ),
    ),
  );
}
