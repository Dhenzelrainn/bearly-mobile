import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/rider_repository.dart';
import '../models/rider_assignment.dart';
import '../widgets/rider_shared_widgets.dart';
import 'rider_waybill_scanner_page.dart';

typedef RiderProofPhotoPicker = Future<XFile?> Function(ImageSource source);

class RiderAssignmentListPage extends StatefulWidget {
  const RiderAssignmentListPage({
    super.key,
    required this.repository,
    required this.kind,
  });

  final RiderRepository repository;
  final RiderAssignmentKind kind;

  @override
  State<RiderAssignmentListPage> createState() =>
      _RiderAssignmentListPageState();
}

class _RiderAssignmentListPageState extends State<RiderAssignmentListPage> {
  late Future<List<RiderAssignment>> _jobs;

  bool get _isPickup => widget.kind == RiderAssignmentKind.pickup;

  @override
  void initState() {
    super.initState();
    _jobs = _load();
  }

  Future<List<RiderAssignment>> _load() => _isPickup
      ? widget.repository.pickupJobs()
      : widget.repository.deliveryJobs();

  void _retry() => setState(() => _jobs = _load());

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: _isPickup ? 'Assigned Pickups' : 'Assigned Deliveries',
    subtitle: _isPickup
        ? 'Pickup assignments selected by your Logistics provider.'
        : 'Delivery assignments dispatched to your Rider account.',
    child: FutureBuilder<List<RiderAssignment>>(
      future: _jobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _LoadMessage(
            message:
                'Could not load assigned jobs. Check your connection and retry.',
            onRetry: _retry,
          );
        }

        final jobs = snapshot.data ?? const <RiderAssignment>[];
        if (jobs.isEmpty) {
          return _LoadMessage(
            icon: Icons.inbox_outlined,
            message: _isPickup
                ? 'There are no pickup assignments for you right now.'
                : 'There are no delivery assignments for you right now.',
          );
        }

        return Column(
          children: [
            riderSummary(
              context,
              _isPickup
                  ? Icons.storefront_outlined
                  : Icons.local_shipping_outlined,
              '${jobs.length}',
              _isPickup ? 'Assigned pickups' : 'Assigned deliveries',
            ),
            const SizedBox(height: 12),
            ...jobs.map((job) => _jobCard(context, job)),
          ],
        );
      },
    ),
  );

  Widget _jobCard(BuildContext context, RiderAssignment job) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: CircleAvatar(
        backgroundColor: BearlyColors.cream200,
        foregroundColor: BearlyColors.brown700,
        child: Icon(
          _isPickup ? Icons.storefront_outlined : Icons.local_shipping_outlined,
        ),
      ),
      title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.id, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(job.address, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${job.parcelCount} parcel(s) · ${job.status}'),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.pushNamed(
        context,
        _isPickup
            ? AppRouteNames.riderPickupDetail
            : AppRouteNames.riderDeliveryDetail,
        arguments: job.id,
      ),
    ),
  );
}

class RiderJobDetailPage extends StatefulWidget {
  const RiderJobDetailPage({
    super.key,
    required this.repository,
    required this.kind,
    required this.jobId,
    this.scannerPreviewBuilder,
    this.proofPhotoPicker,
  });

  final RiderRepository repository;
  final RiderAssignmentKind kind;
  final String jobId;
  final WaybillScannerPreviewBuilder? scannerPreviewBuilder;
  final RiderProofPhotoPicker? proofPhotoPicker;

  @override
  State<RiderJobDetailPage> createState() => _RiderJobDetailPageState();
}

class _RiderJobDetailPageState extends State<RiderJobDetailPage> {
  late Future<RiderAssignment> _job;
  final _waybillFormKey = GlobalKey<FormState>();
  final _deliveryCompletionFormKey = GlobalKey<FormState>();
  final _waybillController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _codCollectedAmountController = TextEditingController();
  XFile? _proofPhoto;
  Uint8List? _proofPhotoBytes;
  String _waybillScanMethod = 'manual';
  bool _actionPending = false;
  bool _deliveryRefreshRequired = false;
  bool _completionFormVisible = false;
  bool _completionRefreshRequired = false;
  String? _proofPhotoError;
  String? _actionError;
  String? _actionNotice;

  bool get _isPickup => widget.kind == RiderAssignmentKind.pickup;

  @override
  void initState() {
    super.initState();
    _job = _load();
  }

  Future<RiderAssignment> _load() => _isPickup
      ? widget.repository.pickupDetail(widget.jobId)
      : widget.repository.deliveryDetail(widget.jobId);

  void _retry() => setState(() {
    _job = _load();
    _deliveryRefreshRequired = false;
    _actionError = null;
  });

  @override
  void dispose() {
    _waybillController.dispose();
    _recipientNameController.dispose();
    _codCollectedAmountController.dispose();
    super.dispose();
  }

  Future<void> _acceptPickup() => _performPickupAction(
    action: () => widget.repository.acceptPickup(widget.jobId),
    isCommitted: (job) => const {
      'accepted',
      'arrived',
      'picked_up',
      'completed',
    }.contains(job.statusRaw),
    successMessage: 'The server confirmed that this pickup is accepted.',
  );

  Future<void> _confirmPickup() async {
    if (_waybillFormKey.currentState?.validate() != true) return;
    await _performPickupAction(
      action: () => widget.repository.confirmPickup(
        widget.jobId,
        waybillIdentifier: _waybillController.text,
        scanMethod: _waybillScanMethod,
      ),
      isCommitted: (job) =>
          const {'picked_up', 'completed'}.contains(job.statusRaw),
      successMessage: 'The server confirmed collection of this pickup.',
    );
  }

  Future<void> _startDelivery() async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
      _deliveryRefreshRequired = false;
    });

    try {
      final response = await widget.repository.startDelivery(widget.jobId);
      RiderAssignment latest;
      try {
        latest = await widget.repository.deliveryDetail(widget.jobId);
      } catch (_) {
        // The mutation response is server-confirmed; a later refresh remains available.
        latest = response;
      }
      if (!mounted) return;
      final confirmed = latest.statusRaw == 'out_for_delivery';
      setState(() {
        _job = Future.value(latest);
        _actionNotice = confirmed
            ? 'The server confirmed this delivery is out for delivery.'
            : null;
        if (!confirmed) {
          _deliveryRefreshRequired = true;
          _actionError =
              'Refresh delivery status before trying this action again.';
        }
      });
    } catch (error) {
      RiderAssignment? latest;
      try {
        latest = await widget.repository.deliveryDetail(widget.jobId);
      } catch (_) {
        // Require an explicit successful refresh before another mutation attempt.
      }
      if (!mounted) return;
      final confirmed = latest?.statusRaw == 'out_for_delivery';
      setState(() {
        if (latest != null) _job = Future.value(latest);
        if (confirmed) {
          _actionNotice =
              'The server confirmed this delivery is out for delivery.';
        } else {
          _deliveryRefreshRequired = latest == null;
          _actionError = latest == null
              ? 'Could not verify the delivery state. Refresh before trying again.'
              : _deliveryActionErrorMessage(error);
        }
      });
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _chooseProofPhoto(ImageSource source) async {
    if (_actionPending) return;
    try {
      final photo = await (widget.proofPhotoPicker ?? _pickProofPhoto)(source);
      if (photo == null || !mounted) return;

      final extension = photo.name.contains('.')
          ? photo.name.split('.').last.toLowerCase()
          : '';
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        setState(() => _proofPhotoError = 'Choose a JPG, PNG, or WebP photo.');
        return;
      }
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _proofPhotoError = 'The selected photo is empty.');
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        setState(
          () => _proofPhotoError = 'The photo must be 10 MB or smaller.',
        );
        return;
      }
      setState(() {
        _proofPhoto = photo;
        _proofPhotoBytes = bytes;
        _proofPhotoError = null;
        _actionError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _proofPhotoError = 'Could not select a proof photo. Try again.',
      );
    }
  }

  Future<XFile?> _pickProofPhoto(ImageSource source) => ImagePicker().pickImage(
    source: source,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );

  void _openDeliveryCompletionForm() {
    setState(() {
      _completionFormVisible = true;
      _completionRefreshRequired = false;
      _proofPhoto = null;
      _proofPhotoBytes = null;
      _proofPhotoError = null;
      _actionError = null;
      _actionNotice = null;
    });
  }

  void _clearDeliveryCompletionForm() {
    _recipientNameController.clear();
    _codCollectedAmountController.clear();
    _proofPhoto = null;
    _proofPhotoBytes = null;
    _proofPhotoError = null;
  }

  Future<void> _refreshCompletionState() async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
    });
    try {
      final latest = await widget.repository.deliveryCompletionStatus(
        widget.jobId,
      );
      if (!mounted) return;
      final delivered = latest.assignment.statusRaw == 'delivered';
      final stillOutForDelivery =
          latest.assignment.statusRaw == 'out_for_delivery';
      setState(() {
        _job = Future.value(latest.assignment);
        _completionRefreshRequired = !delivered && !stillOutForDelivery;
        _completionFormVisible = stillOutForDelivery;
        _actionNotice = delivered
            ? 'The server confirmed that your assigned parcels are delivered.'
            : null;
        _actionError = delivered
            ? null
            : stillOutForDelivery
            ? 'The server confirms this delivery is still active. Review the form before retrying.'
            : 'The current delivery state prevents a safe retry.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _completionRefreshRequired = true;
        _actionError = _deliveryActionErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _completeDelivery(RiderAssignment job) async {
    if (_actionPending || !_completionFormVisible) return;
    final formValid =
        _deliveryCompletionFormKey.currentState?.validate() ?? false;
    if (!formValid) return;
    if (_proofPhoto == null || _proofPhotoBytes == null) {
      setState(
        () => _proofPhotoError =
            'Add a proof-of-delivery photo before confirming.',
      );
      return;
    }

    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
      _proofPhotoError = null;
      _completionRefreshRequired = false;
    });

    try {
      final submitted = await widget.repository.completeDelivery(
        widget.jobId,
        recipientName: _recipientNameController.text,
        proofPhotoBytes: _proofPhotoBytes!,
        proofPhotoName: _proofPhoto!.name,
        codCollectedAmount: job.requiresCodCollection
            ? _codCollectedAmountController.text
            : null,
      );
      RiderDeliveryCompletion latest;
      try {
        latest = await widget.repository.deliveryCompletionStatus(widget.jobId);
      } catch (_) {
        // The multipart response itself is a server-confirmed completion.
        latest = submitted;
      }
      if (!mounted) return;
      final delivered = latest.assignment.statusRaw == 'delivered';
      setState(() {
        _job = Future.value(latest.assignment);
        _completionFormVisible = !delivered;
        _completionRefreshRequired = !delivered;
        _actionNotice = delivered
            ? (latest.codCollection?.status == 'disputed'
                  ? 'Delivery completed. The COD difference was recorded for review.'
                  : 'The server confirmed that your assigned parcels are delivered.')
            : null;
        _actionError = delivered
            ? null
            : 'The completion response and refreshed state do not match. Refresh before retrying.';
      });
      if (delivered) _clearDeliveryCompletionForm();
    } catch (error) {
      if (!_isUncertainDeliveryCompletion(error)) {
        if (!mounted) return;
        setState(() => _actionError = _deliveryActionErrorMessage(error));
        return;
      }

      try {
        final latest = await widget.repository.deliveryCompletionStatus(
          widget.jobId,
        );
        if (!mounted) return;
        final delivered = latest.assignment.statusRaw == 'delivered';
        final stillOutForDelivery =
            latest.assignment.statusRaw == 'out_for_delivery';
        setState(() {
          _job = Future.value(latest.assignment);
          _completionRefreshRequired = !delivered && !stillOutForDelivery;
          _completionFormVisible = !delivered && stillOutForDelivery;
          _actionNotice = delivered
              ? 'The server confirmed that your assigned parcels are delivered.'
              : null;
          _actionError = delivered
              ? null
              : stillOutForDelivery
              ? 'The server confirms the delivery is still active. Review the form before retrying.'
              : 'The current delivery state prevents a safe retry. Refresh before continuing.';
        });
        if (delivered) _clearDeliveryCompletionForm();
      } catch (refreshError) {
        if (!mounted) return;
        setState(() {
          _completionRefreshRequired = true;
          _actionError =
              'The upload result is uncertain. Refresh server state before retrying.';
        });
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  bool _isUncertainDeliveryCompletion(Object error) =>
      error is ApiTimeoutException ||
      error is ApiTransportException ||
      error is ApiFormatException ||
      (error is ApiHttpException && error.statusCode >= 500) ||
      (error is AuthSessionChangedException &&
          error.requestMayHaveReachedServer);

  String _deliveryActionErrorMessage(Object error) {
    if (error is ApiHttpException && error.responseData is Map) {
      final message = (error.responseData as Map)['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    if (error is ApiException) return error.message;
    return 'Delivery could not be started. Review the job state and retry.';
  }

  Future<void> _scanWaybill() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RiderWaybillScannerPage(
          previewBuilder: widget.scannerPreviewBuilder,
        ),
      ),
    );
    if (!mounted || value == null) return;

    _waybillController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {
      _waybillScanMethod = 'camera';
      _actionError = null;
      _actionNotice = null;
    });
  }

  Future<void> _performPickupAction({
    required Future<RiderAssignment> Function() action,
    required bool Function(RiderAssignment) isCommitted,
    required String successMessage,
  }) async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
    });

    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _job = Future.value(updated);
        _actionNotice = successMessage;
      });
    } catch (error) {
      RiderAssignment? latest;
      try {
        latest = await widget.repository.pickupDetail(widget.jobId);
      } catch (_) {
        // Keep the action error when a refresh cannot reach the server.
      }
      if (!mounted) return;
      setState(() {
        if (latest != null) _job = Future.value(latest);
        if (latest != null && isCommitted(latest)) {
          _actionNotice = successMessage;
        } else {
          _actionError = _actionErrorMessage(error);
        }
      });
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  String _actionErrorMessage(Object error) {
    if (error is ApiHttpException && error.responseData is Map) {
      final message = (error.responseData as Map)['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    if (error is ApiException) return error.message;
    return 'The pickup action could not be confirmed. Review the job state and retry.';
  }

  @override
  Widget build(BuildContext context) => RiderPageScaffold(
    title: _isPickup ? 'Pickup Details' : 'Delivery Details',
    subtitle: 'Assignment ${widget.jobId}',
    child: FutureBuilder<RiderAssignment>(
      future: _job,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _LoadMessage(
            message:
                'Could not load this assigned job. Check your connection and retry.',
            onRetry: _retry,
          );
        }

        final job = snapshot.data;
        if (job == null) {
          return const _LoadMessage(message: 'This job is unavailable.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('${job.id} · ${job.status}'),
                    const SizedBox(height: 14),
                    riderRouteRow(
                      context,
                      _isPickup
                          ? Icons.storefront_outlined
                          : Icons.location_on_outlined,
                      _isPickup ? 'Pickup location' : 'Delivery address',
                      job.address,
                    ),
                    if (job.contactName.isNotEmpty ||
                        job.contactPhone.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        [
                          job.contactName,
                          job.contactPhone,
                        ].where((value) => value.isNotEmpty).join(' · '),
                      ),
                    ],
                    if (job.window.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Pickup window: ${job.window}'),
                    ],
                    if (job.waybill.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Waybill: ${job.waybill}'),
                    ],
                    if (job.batchNumber.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Dispatch batch: ${job.batchNumber}'),
                    ],
                    if (job.zone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Zone: ${job.zone}'),
                    ],
                    if (job.instructions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Instructions',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(job.instructions),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Parcels (${job.parcelCount})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (job.parcels.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Parcel details are not available.'),
                ),
              )
            else
              ...job.parcels.map(
                (parcel) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(parcel.parcelNumber),
                    subtitle: Text(
                      [
                        parcel.waybill,
                        parcel.size,
                        parcel.status,
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                  ),
                ),
              ),
            if (job.products.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Order contents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...job.products.map(
                (product) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.inventory_outlined),
                    title: Text(product),
                  ),
                ),
              ),
            ],
            if (_isPickup) ...[
              const SizedBox(height: 12),
              _pickupActions(job),
            ] else ...[
              const SizedBox(height: 12),
              _deliveryActions(job),
            ],
          ],
        );
      },
    ),
  );

  Widget _pickupActions(RiderAssignment job) {
    final status = job.statusRaw;
    final showAccept = status == 'assigned';
    final showWaybillEntry = status == 'accepted';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_actionNotice != null) ...[
          _ActionMessage(message: _actionNotice!, isError: false),
          const SizedBox(height: 10),
        ],
        if (_actionError != null) ...[
          _ActionMessage(message: _actionError!, isError: true),
          const SizedBox(height: 10),
        ],
        if (showAccept)
          FilledButton.icon(
            onPressed: _actionPending ? null : _acceptPickup,
            icon: _actionPending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_actionPending ? 'Accepting…' : 'Accept pickup'),
          )
        else if (showWaybillEntry) ...[
          Form(
            key: _waybillFormKey,
            child: TextFormField(
              controller: _waybillController,
              enabled: !_actionPending,
              textInputAction: TextInputAction.done,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Waybill number or barcode value',
                hintText: 'Enter the value printed on the parcel',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the waybill value to confirm collection.'
                  : null,
              onChanged: (_) => setState(() {
                _waybillScanMethod = 'manual';
                _actionError = null;
                _actionNotice = null;
              }),
              onFieldSubmitted: (_) => _confirmPickup(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _actionPending ? null : _scanWaybill,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan Barcode'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _actionPending ? null : _confirmPickup,
            icon: _actionPending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.inventory_2_outlined),
            label: Text(
              _actionPending
                  ? 'Confirming…'
                  : 'Verify waybill and confirm pickup',
            ),
          ),
        ] else if (status == 'picked_up' || status == 'completed')
          const _ActionMessage(
            message: 'Pickup collection is confirmed by the server.',
            isError: false,
          ),
      ],
    );
  }

  Widget _deliveryActions(RiderAssignment job) {
    final showStart =
        job.canStartDelivery &&
        job.statusRaw == 'assigned' &&
        !_deliveryRefreshRequired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_actionNotice != null) ...[
          _ActionMessage(message: _actionNotice!, isError: false),
          const SizedBox(height: 10),
        ],
        if (_actionError != null) ...[
          _ActionMessage(message: _actionError!, isError: true),
          const SizedBox(height: 10),
        ],
        if (_completionRefreshRequired)
          OutlinedButton.icon(
            onPressed: _actionPending ? null : _refreshCompletionState,
            icon: _actionPending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Refresh delivery state'),
          )
        else if (_deliveryRefreshRequired)
          OutlinedButton.icon(
            onPressed: _actionPending ? null : _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh delivery status'),
          )
        else if (_completionFormVisible)
          _deliveryCompletionForm(job)
        else if (showStart)
          FilledButton.icon(
            onPressed: _actionPending ? null : _startDelivery,
            icon: _actionPending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_shipping_outlined),
            label: Text(
              _actionPending ? 'Starting delivery…' : 'Start Delivery',
            ),
          )
        else if (job.statusRaw == 'out_for_delivery')
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ActionMessage(
                message: 'This delivery is out for delivery.',
                isError: false,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _actionPending ? null : _openDeliveryCompletionForm,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Complete Delivery'),
              ),
            ],
          )
        else if (job.statusRaw == 'delivered' && _actionNotice == null)
          const _ActionMessage(
            message:
                'The server confirmed that your assigned parcels are delivered.',
            isError: false,
          ),
      ],
    );
  }

  Widget _deliveryCompletionForm(RiderAssignment job) => Form(
    key: _deliveryCompletionFormKey,
    child: Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm delivery',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _recipientNameController,
              enabled: !_actionPending,
              maxLength: 160,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Recipient name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the recipient name.'
                  : value.trim().length > 160
                  ? 'Recipient name must be 160 characters or fewer.'
                  : null,
            ),
            if (job.requiresCodCollection) ...[
              const SizedBox(height: 8),
              Text(
                'COD amount due: ${_formatPeso(job.codDueMinor)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codCollectedAmountController,
                enabled: !_actionPending,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Actual COD cash collected',
                  prefixText: '₱ ',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = value?.trim() ?? '';
                  if (amount.isEmpty) return 'Enter the actual cash collected.';
                  if (!RegExp(r'^\d{1,8}(?:\.\d{1,2})?$').hasMatch(amount)) {
                    return 'Enter an amount with up to 2 decimal places.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 10),
            if (_proofPhotoBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _proofPhotoBytes!,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 72,
                    child: Center(child: Text('Photo preview unavailable.')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _actionPending
                      ? null
                      : () => _chooseProofPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _proofPhoto == null
                        ? 'Capture proof photo'
                        : 'Retake photo',
                  ),
                ),
                TextButton.icon(
                  onPressed: _actionPending
                      ? null
                      : () => _chooseProofPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ],
            ),
            if (_proofPhoto != null) ...[
              const SizedBox(height: 4),
              Text('Selected: ${_proofPhoto!.name}'),
            ],
            if (_proofPhotoError != null) ...[
              const SizedBox(height: 4),
              Text(
                _proofPhotoError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _actionPending ? null : () => _completeDelivery(job),
              icon: _actionPending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _actionPending
                    ? 'Uploading proof and confirming…'
                    : 'Confirm delivery',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _formatPeso(int amountMinor) =>
      '₱${(amountMinor / 100).toStringAsFixed(2)}';
}

class _ActionMessage extends StatelessWidget {
  const _ActionMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? Colors.red.shade50 : BearlyColors.cream100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isError ? Colors.red.shade200 : BearlyColors.cream300,
      ),
    ),
    child: Text(
      message,
      style: TextStyle(color: isError ? Colors.red.shade900 : null),
    ),
  );
}

class _LoadMessage extends StatelessWidget {
  const _LoadMessage({
    required this.message,
    this.icon = Icons.cloud_off_outlined,
    this.onRetry,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 36, color: BearlyColors.muted),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ],
    ),
  );
}
