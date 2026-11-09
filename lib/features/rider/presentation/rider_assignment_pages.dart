import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/product_thumbnail.dart';
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
    currentRoute: _isPickup
        ? AppRouteNames.riderRequests
        : AppRouteNames.riderTransit,
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
      leading: job.productItems.isNotEmpty
          ? ProductThumbnail(
              imageUrl: job.productItems.first.imageUrl,
              size: 52,
              semanticLabel: job.productItems.first.name,
            )
          : CircleAvatar(
              backgroundColor: BearlyColors.cream200,
              foregroundColor: BearlyColors.brown700,
              child: Icon(
                _isPickup
                    ? Icons.storefront_outlined
                    : Icons.local_shipping_outlined,
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
  final _deliveryFailureFormKey = GlobalKey<FormState>();
  final _waybillController = TextEditingController();
  final _parcelBarcodeController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _codCollectedAmountController = TextEditingController();
  final _failureReasonController = TextEditingController();
  XFile? _proofPhoto;
  Uint8List? _proofPhotoBytes;
  String _waybillScanMethod = 'manual';
  RiderDeliveryVerificationProgress? _verificationProgress;
  bool _actionPending = false;
  bool _verificationLoading = false;
  bool _deliveryRefreshRequired = false;
  bool _retryRefreshRequired = false;
  bool _completionFormVisible = false;
  bool _completionRefreshRequired = false;
  bool _failureFormVisible = false;
  bool _failureRefreshRequired = false;
  String? _proofPhotoError;
  String? _actionError;
  String? _actionNotice;
  String? _verificationError;

  bool get _isPickup => widget.kind == RiderAssignmentKind.pickup;

  @override
  void initState() {
    super.initState();
    _job = _load();
  }

  Future<RiderAssignment> _load() async {
    final job = _isPickup
        ? await widget.repository.pickupDetail(widget.jobId)
        : await widget.repository.deliveryDetail(widget.jobId);
    _verificationProgress = null;
    _verificationError = null;
    if (!_isPickup && job.statusRaw == 'out_for_delivery') {
      try {
        _verificationProgress = await widget.repository
            .deliveryVerificationProgress(widget.jobId);
      } catch (error) {
        _verificationError = _deliveryActionErrorMessage(error);
      }
    }
    return job;
  }

  void _retry() => setState(() {
    _job = _load();
    _deliveryRefreshRequired = false;
    _retryRefreshRequired = false;
    _failureRefreshRequired = false;
    _actionError = null;
  });

  @override
  void dispose() {
    _waybillController.dispose();
    _parcelBarcodeController.dispose();
    _recipientNameController.dispose();
    _codCollectedAmountController.dispose();
    _failureReasonController.dispose();
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
      if (confirmed) await _refreshParcelVerification(latest);
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
      if (confirmed && latest != null) {
        await _refreshParcelVerification(latest);
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  void _openDeliveryFailureForm() {
    setState(() {
      _failureFormVisible = true;
      _failureRefreshRequired = false;
      _failureReasonController.clear();
      _actionError = null;
      _actionNotice = null;
    });
  }

  Future<void> _refreshFailureState() async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
    });
    try {
      final latest = await widget.repository.deliveryDetail(widget.jobId);
      if (!mounted) return;
      final failed = latest.statusRaw == 'delivery_failed';
      final stillOutForDelivery = latest.statusRaw == 'out_for_delivery';
      setState(() {
        _job = Future.value(latest);
        _failureRefreshRequired = false;
        _failureFormVisible = stillOutForDelivery;
        _actionNotice = failed
            ? 'The server confirmed this delivery attempt was recorded as failed.'
            : null;
        _actionError = failed
            ? null
            : stillOutForDelivery
            ? 'The server confirms this delivery is still active. Review the failure reason before submitting.'
            : 'This delivery is no longer eligible for failure reporting.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failureRefreshRequired = true;
        _actionError = _deliveryActionErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _reportDeliveryFailure(RiderAssignment job) async {
    if (_actionPending ||
        !_failureFormVisible ||
        job.statusRaw != 'out_for_delivery') {
      return;
    }
    if (_deliveryFailureFormKey.currentState?.validate() != true) return;

    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
      _failureRefreshRequired = false;
    });

    try {
      final submitted = await widget.repository.failDelivery(
        widget.jobId,
        failureReason: _failureReasonController.text,
      );
      RiderAssignment latest;
      var refreshFailed = false;
      try {
        latest = await widget.repository.deliveryDetail(widget.jobId);
      } catch (_) {
        // The mutation response is server-confirmed; refresh remains available.
        latest = submitted;
        refreshFailed = true;
      }
      if (!mounted) return;

      final failed = latest.statusRaw == 'delivery_failed';
      final stillOutForDelivery = latest.statusRaw == 'out_for_delivery';
      setState(() {
        _job = Future.value(latest);
        _failureFormVisible = false;
        _failureRefreshRequired = refreshFailed || !failed;
        _actionNotice = failed
            ? 'The server confirmed this delivery attempt was recorded as failed.'
            : null;
        _actionError = failed
            ? refreshFailed
                  ? 'The failure was confirmed by the server. Refresh delivery state when the connection is available.'
                  : null
            : stillOutForDelivery
            ? 'The server still reports this delivery as active. Refresh before submitting again.'
            : 'The failure response and refreshed delivery state do not match. Refresh before continuing.';
      });
      if (failed) _failureReasonController.clear();
    } catch (error) {
      RiderAssignment? latest;
      try {
        latest = await widget.repository.deliveryDetail(widget.jobId);
      } catch (_) {
        // An explicit successful refresh is required before another submission.
      }
      if (!mounted) return;

      final failed = latest?.statusRaw == 'delivery_failed';
      final stillOutForDelivery = latest?.statusRaw == 'out_for_delivery';
      final uncertain = _isUncertainDeliveryFailure(error);
      setState(() {
        if (latest != null) _job = Future.value(latest);
        if (failed) {
          _failureFormVisible = false;
          _failureRefreshRequired = false;
          _actionNotice =
              'The server confirmed this delivery attempt was recorded as failed.';
          _actionError = null;
        } else if (stillOutForDelivery && !uncertain) {
          _failureFormVisible = true;
          _failureRefreshRequired = false;
          _actionError = _deliveryActionErrorMessage(error);
        } else {
          _failureFormVisible = false;
          _failureRefreshRequired = true;
          _actionError = uncertain
              ? 'The result is uncertain. Refresh server state before submitting another failure report.'
              : latest == null
              ? 'Could not verify the delivery state. Refresh before trying again.'
              : 'This delivery is no longer eligible for failure reporting.';
        }
      });
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _retryDelivery(RiderAssignment job) async {
    if (_actionPending || job.statusRaw != 'delivery_failed' || !job.canRetry) {
      return;
    }

    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
      _retryRefreshRequired = false;
    });

    try {
      final response = await widget.repository.retryDelivery(widget.jobId);
      RiderAssignment latest;
      var refreshFailed = false;
      try {
        latest = await widget.repository.deliveryDetail(widget.jobId);
      } catch (_) {
        latest = response;
        refreshFailed = true;
      }
      if (!mounted) return;

      final retried = latest.statusRaw == 'out_for_delivery';
      setState(() {
        _job = Future.value(latest);
        _retryRefreshRequired = refreshFailed || !retried;
        _actionNotice = retried
            ? 'The server confirmed this delivery is out for delivery again.'
            : null;
        _actionError = retried
            ? refreshFailed
                  ? 'The retry was confirmed. Refresh delivery state when the connection is available.'
                  : null
            : 'The retry response and refreshed delivery state do not match. Refresh before continuing.';
      });
      if (retried) await _refreshParcelVerification(latest);
    } catch (error) {
      RiderAssignment? latest;
      try {
        latest = await widget.repository.deliveryDetail(widget.jobId);
      } catch (_) {
        // Require a successful state refresh before another retry submission.
      }
      if (!mounted) return;

      final retried = latest?.statusRaw == 'out_for_delivery';
      setState(() {
        if (latest != null) _job = Future.value(latest);
        if (retried) {
          _retryRefreshRequired = false;
          _actionNotice =
              'The server confirmed this delivery is out for delivery again.';
          _actionError = null;
        } else if (latest == null) {
          _retryRefreshRequired = true;
          _actionError =
              'The retry result is uncertain. Refresh server state before trying again.';
        } else if (latest.statusRaw == 'delivery_failed') {
          // The refreshed state confirms the retry did not commit. The button
          // remains governed by the server's current can_retry value.
          _retryRefreshRequired = false;
          _actionError = _deliveryActionErrorMessage(error);
        } else {
          _retryRefreshRequired = true;
          _actionError =
              'This delivery is no longer eligible for retry. Refresh before continuing.';
        }
      });
      if (retried && latest != null) {
        await _refreshParcelVerification(latest);
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _refreshRetryState() async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
    });
    try {
      final latest = await widget.repository.deliveryDetail(widget.jobId);
      if (!mounted) return;
      final retried = latest.statusRaw == 'out_for_delivery';
      setState(() {
        _job = Future.value(latest);
        _retryRefreshRequired = false;
        _actionNotice = retried
            ? 'The server confirmed this delivery is out for delivery again.'
            : latest.canRetry
            ? 'The server confirms this delivery is ready to retry.'
            : null;
        _actionError = retried || latest.canRetry
            ? null
            : latest.retryUnavailableReason.isNotEmpty
            ? latest.retryUnavailableReason
            : 'The current delivery state does not allow a retry.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _retryRefreshRequired = true;
        _actionError = _deliveryActionErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  String _retryAvailabilityLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(local);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date at $time';
  }

  bool _isUncertainDeliveryFailure(Object error) =>
      error is ApiTimeoutException ||
      error is ApiTransportException ||
      error is ApiFormatException ||
      (error is ApiHttpException && error.statusCode >= 500) ||
      (error is AuthSessionChangedException &&
          error.requestMayHaveReachedServer);

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
      _failureFormVisible = false;
      _failureRefreshRequired = false;
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
      if (stillOutForDelivery) {
        await _refreshParcelVerification(latest.assignment);
      }
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
    if (_verificationProgress?.allVerified != true) {
      setState(() {
        _actionError =
            'Verify every assigned Parcel barcode before confirming delivery.';
      });
      return;
    }
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

  Future<void> _refreshParcelVerification(RiderAssignment job) async {
    if (job.statusRaw != 'out_for_delivery') {
      if (mounted) {
        setState(() {
          _verificationProgress = null;
          _verificationError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _verificationLoading = true;
        _verificationError = null;
      });
    }
    try {
      final progress = await widget.repository.deliveryVerificationProgress(
        widget.jobId,
      );
      if (mounted) {
        setState(() {
          _verificationProgress = progress;
          _verificationError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _verificationProgress = null;
          _verificationError = _deliveryActionErrorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _verificationLoading = false);
    }
  }

  Future<void> _scanParcelBarcode(RiderAssignment job) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RiderWaybillScannerPage(
          previewBuilder: widget.scannerPreviewBuilder,
          title: 'Scan Parcel barcode',
        ),
      ),
    );
    if (!mounted || value == null) return;
    _parcelBarcodeController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    await _verifyParcelBarcode(job, scanMethod: 'camera');
  }

  Future<void> _verifyParcelBarcode(
    RiderAssignment job, {
    required String scanMethod,
  }) async {
    final barcode = _parcelBarcodeController.text.trim();
    if (barcode.isEmpty || _actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
      _actionNotice = null;
      _verificationError = null;
    });
    try {
      final progress = await widget.repository.verifyDeliveryParcel(
        widget.jobId,
        barcode: barcode,
        scanMethod: scanMethod,
      );
      if (!mounted) return;
      setState(() {
        _verificationProgress = progress;
        _parcelBarcodeController.clear();
        _actionNotice = progress.newlyVerified
            ? 'Parcel ${progress.parcelNumber} verified by the server.'
            : 'Parcel ${progress.parcelNumber} was already verified.';
        _actionError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = _deliveryActionErrorMessage(error));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
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
    currentRoute: _isPickup
        ? AppRouteNames.riderRequests
        : AppRouteNames.riderTransit,
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
            if (job.productItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Order contents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...job.productItems.map(
                (product) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: ProductThumbnail(
                      imageUrl: product.imageUrl,
                      size: 52,
                      semanticLabel: product.name,
                    ),
                    title: Text(
                      product.name.isEmpty ? 'Purchased item' : product.name,
                    ),
                    subtitle: Text(
                      [
                        if (product.variant.isNotEmpty) product.variant,
                        'Qty ${product.quantity}',
                      ].join(' · '),
                    ),
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
        if (job.statusRaw == 'out_for_delivery') ...[
          _deliveryParcelVerification(job),
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
        else if (_retryRefreshRequired)
          OutlinedButton.icon(
            onPressed: _actionPending ? null : _refreshRetryState,
            icon: _actionPending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Refresh delivery state'),
          )
        else if (_failureRefreshRequired)
          OutlinedButton.icon(
            onPressed: _actionPending ? null : _refreshFailureState,
            icon: _actionPending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Refresh delivery state'),
          )
        else if (_completionFormVisible)
          _deliveryCompletionForm(job)
        else if (_failureFormVisible)
          _deliveryFailureForm(job)
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
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _actionPending ? null : _openDeliveryFailureForm,
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Report Failed Delivery'),
              ),
            ],
          )
        else if (job.statusRaw == 'delivery_failed')
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActionMessage(
                message: job.canRetry
                    ? 'The latest delivery attempt failed. Another attempt is available.'
                    : job.retryAvailableAt != null
                    ? 'The latest delivery attempt failed. Retry is scheduled for ${_retryAvailabilityLabel(job.retryAvailableAt!)}.'
                    : job.retryUnavailableReason.isNotEmpty
                    ? job.retryUnavailableReason
                    : 'The latest delivery attempt failed. Retry is unavailable for the current server state.',
                isError: false,
              ),
              if (job.canRetry) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _actionPending ? null : () => _retryDelivery(job),
                  icon: _actionPending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _actionPending ? 'Retrying delivery…' : 'Retry Delivery',
                  ),
                ),
              ] else if (job.retryAvailableAt != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _actionPending ? null : _refreshRetryState,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh delivery state'),
                ),
              ],
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

  Widget _deliveryParcelVerification(RiderAssignment job) {
    final progress = _verificationProgress;
    final assigned =
        progress?.assignedParcelNumbers ??
        job.parcels.map((parcel) => parcel.parcelNumber).toList();
    final allVerified = progress?.allVerified == true;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Parcel scan verification',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              progress == null
                  ? 'Scan each assigned Parcel before confirming delivery.'
                  : '${progress.verifiedCount} of ${progress.totalCount} Parcels verified',
            ),
            if (assigned.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...assigned.map((parcelNumber) {
                final verified = progress?.isVerified(parcelNumber) == true;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    verified ? Icons.verified_rounded : Icons.qr_code_2_rounded,
                    color: verified
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(parcelNumber),
                  subtitle: Text(
                    verified ? 'Verified by Bearly' : 'Not scanned',
                  ),
                );
              }),
            ],
            if (_verificationError != null) ...[
              const SizedBox(height: 4),
              _ActionMessage(message: _verificationError!, isError: true),
            ],
            if (progress == null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _verificationLoading || _actionPending
                    ? null
                    : () => _refreshParcelVerification(job),
                icon: _verificationLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Refresh Parcel scan progress'),
              ),
            ] else if (!allVerified) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _parcelBarcodeController,
                enabled: !_actionPending,
                maxLength: 120,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Parcel barcode',
                  hintText: 'Enter the exact code printed on one Parcel',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_actionError != null) {
                    setState(() => _actionError = null);
                  }
                },
                onSubmitted: (_) =>
                    _verifyParcelBarcode(job, scanMethod: 'manual'),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _actionPending
                    ? null
                    : () => _scanParcelBarcode(job),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan Parcel barcode'),
              ),
              FilledButton.icon(
                onPressed: _actionPending
                    ? null
                    : () => _verifyParcelBarcode(job, scanMethod: 'manual'),
                icon: _actionPending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(_actionPending ? 'Verifying…' : 'Verify Parcel'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const _ActionMessage(
                message:
                    'The server confirms every assigned Parcel is verified. Delivery completion is available.',
                isError: false,
              ),
            ],
          ],
        ),
      ),
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
              onPressed:
                  _actionPending || _verificationProgress?.allVerified != true
                  ? null
                  : () => _completeDelivery(job),
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

  Widget _deliveryFailureForm(RiderAssignment job) => Form(
    key: _deliveryFailureFormKey,
    child: Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Report failed delivery',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _failureReasonController,
              enabled: !_actionPending,
              maxLength: 100,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Failure reason',
                hintText:
                    'Explain why the recipient could not receive the parcel',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final reason = value?.trim() ?? '';
                if (reason.isEmpty) return 'Enter a failure reason.';
                if (reason.length > 100) {
                  return 'Failure reason must be 100 characters or fewer.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _actionPending
                  ? null
                  : () => setState(() {
                      _failureFormVisible = false;
                      _failureReasonController.clear();
                      _actionError = null;
                      _actionNotice = null;
                    }),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _actionPending
                  ? null
                  : () => _reportDeliveryFailure(job),
              icon: _actionPending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.report_outlined),
              label: Text(
                _actionPending ? 'Submitting report…' : 'Submit failure report',
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
