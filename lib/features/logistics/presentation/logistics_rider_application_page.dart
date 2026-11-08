import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/logistics_repository.dart';
import '../models/logistics_rider_application.dart';

class LogisticsRiderApplicationPage extends StatefulWidget {
  const LogisticsRiderApplicationPage({
    super.key,
    required this.repository,
    required this.applicationId,
  });

  final LogisticsRepository repository;
  final int applicationId;

  @override
  State<LogisticsRiderApplicationPage> createState() =>
      _LogisticsRiderApplicationPageState();
}

class _LogisticsRiderApplicationPageState
    extends State<LogisticsRiderApplicationPage> {
  late Future<LogisticsRiderApplication> _application;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _application = widget.repository.riderApplication(widget.applicationId);
  }

  Future<void> _refresh() async {
    final next = widget.repository.riderApplication(widget.applicationId);
    setState(() {
      _application = next;
    });
    try {
      await next;
    } catch (_) {
      // The FutureBuilder keeps the request error visible with a retry action.
    }
  }

  Future<void> _reviewDocument(
    LogisticsRiderApplicationDocument document,
    String status,
  ) async {
    String? reason;
    if (status == 'rejected') {
      reason = await _reasonDialog(
        title: 'Reject document',
        label: 'Reason for rejection',
        saveLabel: 'Reject document',
      );
      if (reason == null) return;
    }
    await _runAction(
      () => widget.repository.reviewRiderApplicationDocument(
        applicationId: widget.applicationId,
        documentId: document.id,
        verificationStatus: status,
        rejectionReason: reason,
      ),
      success: status == 'verified'
          ? 'Document marked as verified.'
          : 'Document rejection recorded.',
    );
  }

  Future<void> _approve(LogisticsRiderApplication application) async {
    int? capacity;
    if (application.isCourier) {
      capacity = await _courierCapacityDialog();
      if (capacity == null) return;
    } else {
      final confirm = await _confirm(
        title: 'Approve Local Rider?',
        message:
            'This uses the existing approval workflow and activates the applicant account.',
        action: 'Approve',
      );
      if (confirm != true) return;
    }
    await _runAction(
      () => widget.repository.approveRiderApplication(
        applicationId: application.id,
        linehaulCapacity: capacity,
      ),
      success: 'Rider application approved.',
    );
  }

  Future<void> _reject(LogisticsRiderApplication application) async {
    final reason = await _reasonDialog(
      title: 'Reject application',
      label: 'Reason for rejection',
      saveLabel: 'Reject application',
    );
    if (reason == null) return;
    await _runAction(
      () => widget.repository.rejectRiderApplication(
        applicationId: application.id,
        reason: reason,
      ),
      success: 'Rider application rejected.',
    );
  }

  Future<String?> _reasonDialog({
    required String title,
    required String label,
    required String saveLabel,
  }) async {
    final formKey = GlobalKey<FormState>();
    var result = '';
    final response = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(labelText: label),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a reason.'
                : null,
            onSaved: (value) => result = value!.trim(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(dialogContext, result);
            },
            child: Text(saveLabel),
          ),
        ],
      ),
    );
    if (response == null || response.trim().isEmpty) return null;
    return response.trim();
  }

  Future<int?> _courierCapacityDialog() async {
    final formKey = GlobalKey<FormState>();
    var value = '';
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Courier'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const ValueKey('rider-application-linehaul-capacity'),
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Line-haul parcel capacity',
              helperText: 'Enter a whole number from 1 to 1000.',
            ),
            validator: (text) {
              final parsed = int.tryParse(text?.trim() ?? '');
              if (parsed == null || parsed < 1 || parsed > 1000) {
                return 'Enter a whole number from 1 to 1000.';
              }
              return null;
            },
            onSaved: (text) => value = text!.trim(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('rider-application-approve-courier'),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(dialogContext, int.parse(value));
            },
            child: const Text('Approve Courier'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(action),
        ),
      ],
    ),
  );

  Future<void> _runAction(
    Future<LogisticsRiderApplication> Function() action, {
    required String success,
  }) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _application = Future.value(updated);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      await _refresh();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openDocument(LogisticsRiderApplicationDocument document) async {
    try {
      final content = await widget.repository.downloadRiderApplicationDocument(
        applicationId: widget.applicationId,
        documentId: document.id,
      );
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
                  child: Text('This document image could not be previewed.'),
                ),
              ),
            ),
          ),
        );
      } else {
        final path = await FilePicker.saveFile(
          fileName: document.filename,
          bytes: Uint8List.fromList(content.bytes),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                path == null ? 'File save was cancelled.' : 'Document saved.',
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiHttpException) {
      final validation = error.validationErrors.values
          .expand((messages) => messages)
          .firstOrNull;
      if (validation != null && validation.isNotEmpty) return validation;
      return switch (error.statusCode) {
        401 || 403 => 'This Logistics account cannot review this application.',
        404 => 'This application or document is no longer available.',
        409 => 'Application eligibility changed. Refresh and review again.',
        _ => 'The application request failed. Try again.',
      };
    }
    if (error is ApiException) return error.message;
    return 'The application request failed. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rider Application'),
      actions: [
        IconButton(
          key: const ValueKey('rider-application-refresh'),
          onPressed: _refresh,
          tooltip: 'Refresh application',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LogisticsRiderApplication>(
      future: _application,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _loadError();
        }
        final application = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _summary(application),
              const SizedBox(height: 12),
              _applicant(application),
              const SizedBox(height: 12),
              _documents(application),
              const SizedBox(height: 12),
              _decisionPanel(application),
              if (_working) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _loadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Could not load this provider-owned Rider application.',
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _summary(LogisticsRiderApplication application) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.assignment_ind_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.applicant.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(application.requestedWorkTypeLabel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(application.statusLabel),
              _statusChip('Account ${_label(application.accountStatus)}'),
            ],
          ),
          const SizedBox(height: 8),
          Text('Application ${application.applicationNumber}'),
          if (application.submittedAt != null)
            Text('Submitted ${_dateTime(application.submittedAt)}'),
          if (application.reviewStartedAt != null)
            Text('Review started ${_dateTime(application.reviewStartedAt)}'),
          if (application.decidedAt != null)
            Text('Decision recorded ${_dateTime(application.decidedAt)}'),
          if (application.vehicle != null)
            Text(
              'Vehicle: ${application.vehicle}${application.vehicleModel == null ? '' : ' · ${application.vehicleModel}'}',
            ),
          if (application.plateNumber != null)
            Text('Plate number: ${application.plateNumber}'),
          if (application.revisionNotes != null) ...[
            const SizedBox(height: 8),
            Text('Revision notes: ${application.revisionNotes}'),
          ],
          if (application.decisionReason != null) ...[
            const SizedBox(height: 8),
            Text('Decision reason: ${application.decisionReason}'),
          ],
        ],
      ),
    ),
  );

  Widget _applicant(LogisticsRiderApplication application) {
    final applicant = application.applicant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Applicant details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (applicant.email != null)
              _detailLine(Icons.email_outlined, applicant.email!),
            if (applicant.phone != null)
              _detailLine(Icons.phone_outlined, applicant.phone!),
            if (applicant.birthday != null)
              _detailLine(Icons.cake_outlined, _date(applicant.birthday)),
            if (applicant.sex != null)
              _detailLine(Icons.person_outline, applicant.sex!),
            if (applicant.formattedAddress.isNotEmpty)
              _detailLine(
                Icons.location_on_outlined,
                applicant.formattedAddress,
              ),
            if (applicant.formattedAddress.isEmpty && applicant.area != null)
              _detailLine(Icons.location_on_outlined, applicant.area!),
          ],
        ),
      ),
    );
  }

  Widget _documents(LogisticsRiderApplication application) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application documents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Required for approval: Driver’s License / ID and OR/CR.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
          ),
          const SizedBox(height: 8),
          if (application.documents.isEmpty)
            const Text('No documents were submitted with this application.')
          else
            ...application.documents.map(
              (document) => _documentCard(
                document,
                canReview: application.canReviewDocuments,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _documentCard(
    LogisticsRiderApplicationDocument document, {
    required bool canReview,
  }) => Card(
    key: ValueKey('rider-application-document-${document.id}'),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      document.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('${document.mimeType} · ${_size(document.sizeBytes)}'),
                  ],
                ),
              ),
              _statusChip(_label(document.status)),
            ],
          ),
          if (document.verifiedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Reviewed ${_dateTime(document.verifiedAt)}'),
            ),
          if (document.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Rejection reason: ${document.rejectionReason}'),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: ValueKey('rider-application-document-open-${document.id}'),
                onPressed: _working ? null : () => _openDocument(document),
                icon: Icon(
                  document.mimeType.startsWith('image/')
                      ? Icons.visibility_outlined
                      : Icons.download_outlined,
                ),
                label: Text(
                  document.mimeType.startsWith('image/')
                      ? 'Preview'
                      : 'Open / save',
                ),
              ),
              if (canReview && document.status != 'verified')
                TextButton.icon(
                  key: ValueKey(
                    'rider-application-document-verify-${document.id}',
                  ),
                  onPressed: _working
                      ? null
                      : () => _reviewDocument(document, 'verified'),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verify'),
                ),
              if (canReview && document.status != 'rejected')
                TextButton.icon(
                  key: ValueKey(
                    'rider-application-document-reject-${document.id}',
                  ),
                  onPressed: _working
                      ? null
                      : () => _reviewDocument(document, 'rejected'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _decisionPanel(LogisticsRiderApplication application) {
    final missingRequired = !application.requiredDocumentsVerified;
    final mismatch = !application.ownershipConsistent;
    final canDecide = application.canDecide && !missingRequired && !mismatch;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application decision',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (mismatch)
              const Text(
                'The provider ownership records do not match. Contact an administrator before making a decision.',
              )
            else if (missingRequired)
              const Text(
                'Verify the required Driver’s License / ID and OR/CR documents before approval.',
              )
            else if (!application.canDecide)
              const Text(
                'This application is not currently available for a decision.',
              ),
            if (application.canDecide)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('rider-application-approve'),
                      onPressed: _working || !canDecide
                          ? null
                          : () => _approve(application),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        application.isCourier
                            ? 'Approve Courier'
                            : 'Approve Local Rider',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('rider-application-reject'),
                      onPressed: _working ? null : () => _reject(application),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject application'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _statusChip(String label) =>
      Chip(visualDensity: VisualDensity.compact, label: Text(label));
}

String _label(String? value) => value == null || value.trim().isEmpty
    ? 'Not provided'
    : value
          .replaceAll('_', ' ')
          .split(' ')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' ');

String _date(DateTime? value) => value == null
    ? 'Not provided'
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateTime(DateTime? value) {
  if (value == null) return 'Not recorded';
  final local = value.toLocal();
  return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';
