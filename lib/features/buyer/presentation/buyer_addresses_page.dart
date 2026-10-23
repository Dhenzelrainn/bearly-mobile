import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/buyer_address_controller.dart';
import '../data/buyer_location_repository.dart';
import '../models/buyer_shopping_models.dart';
import 'buyer_address_form_page.dart';

class BuyerAddressesPage extends StatefulWidget {
  const BuyerAddressesPage({
    super.key,
    required this.controller,
    required this.locationRepository,
    this.onSignInAgain,
  });

  final BuyerAddressController controller;
  final BuyerLocationRepository locationRepository;
  final VoidCallback? onSignInAgain;

  @override
  State<BuyerAddressesPage> createState() => _BuyerAddressesPageState();
}

class _BuyerAddressesPageState extends State<BuyerAddressesPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.synchronizeSession();
    unawaited(widget.controller.refresh(force: true));
  }

  Future<void> _openForm({BuyerAddress? address}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BuyerAddressFormPage(
          controller: widget.controller,
          locationRepository: widget.locationRepository,
          address: address,
        ),
      ),
    );
    if (!mounted) return;
    await widget.controller.refresh(force: true);
    if (saved == true && mounted) {
      _showMessage(address == null ? 'Address saved.' : 'Address updated.');
    }
  }

  Future<void> _setDefault(BuyerAddress address) async {
    try {
      await widget.controller.setDefaultAddress(address.id);
      if (mounted) _showMessage('Default address updated.');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _delete(BuyerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: const Text(
          'This saved delivery address will be removed from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: ValueKey('buyer-address-delete-confirm-${address.id}'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.deleteAddress(address.id);
      if (mounted) _showMessage('Address deleted.');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _showError(Object error) {
    final needsSignIn =
        error is AuthException ||
        (error is ApiHttpException &&
            (error.statusCode == 401 || error.statusCode == 403));
    final refreshRequired =
        error is ApiHttpException && error.statusCode == 404;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(buyerAddressErrorMessage(error)),
        action: needsSignIn && widget.onSignInAgain != null
            ? SnackBarAction(label: 'Sign in', onPressed: widget.onSignInAgain!)
            : refreshRequired
            ? SnackBarAction(
                label: 'Refresh',
                onPressed: () => widget.controller.refresh(force: true),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delivery addresses')),
    floatingActionButton: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => FloatingActionButton.extended(
        key: const ValueKey('buyer-address-add'),
        onPressed: widget.controller.isMutating || widget.controller.isLoading
            ? null
            : () => _openForm(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
    ),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final addresses = widget.controller.addresses;
        if (widget.controller.isLoading && addresses == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.controller.loadError != null && addresses == null) {
          return _failureState(widget.controller.loadError!);
        }
        if (addresses == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (addresses.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => widget.controller.refresh(force: true),
            child: ListView(
              key: const ValueKey('buyer-address-empty'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 70, 22, 110),
              children: const [
                Icon(
                  Icons.location_on_outlined,
                  size: 54,
                  color: BearlyColors.brown500,
                ),
                SizedBox(height: 16),
                Text(
                  'No saved delivery addresses',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Add an address so it is ready when you need it.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => widget.controller.refresh(force: true),
          child: ListView.separated(
            key: const ValueKey('buyer-address-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 104),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _addressCard(addresses[index]),
          ),
        );
      },
    ),
  );

  Widget _failureState(Object error) {
    final needsSignIn =
        error is AuthException ||
        (error is ApiHttpException &&
            (error.statusCode == 401 || error.statusCode == 403));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(buyerAddressErrorMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('buyer-address-retry'),
              onPressed: needsSignIn && widget.onSignInAgain != null
                  ? widget.onSignInAgain
                  : () => widget.controller.refresh(force: true),
              icon: Icon(needsSignIn ? Icons.login : Icons.refresh),
              label: Text(needsSignIn ? 'Sign in' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressCard(BuyerAddress address) {
    final pending = widget.controller.pendingAddressId == address.id;
    final busy = widget.controller.isMutating;
    return Card(
      key: ValueKey('buyer-address-${address.id}'),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (address.isDefault)
                  Container(
                    key: ValueKey('buyer-address-default-${address.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: BearlyColors.cream200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        color: BearlyColors.brown900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  key: ValueKey('buyer-address-menu-${address.id}'),
                  enabled: !busy && !widget.controller.isLoading,
                  tooltip: 'Address actions',
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _openForm(address: address);
                        break;
                      case 'default':
                        _setDefault(address);
                        break;
                      case 'delete':
                        _delete(address);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (!address.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Text('Set as default'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            Text(
              address.phone,
              key: ValueKey('buyer-address-phone-${address.id}'),
            ),
            const SizedBox(height: 8),
            Text(
              address.label,
              style: const TextStyle(
                color: BearlyColors.brown700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(address.street),
            Text('${address.barangay}, ${address.city}'),
            Text('${address.province} ${address.postal}'),
            if (pending)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
