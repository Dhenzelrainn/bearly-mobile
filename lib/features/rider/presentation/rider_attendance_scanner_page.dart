import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_client.dart';
import '../models/rider_attendance_result.dart';

typedef RiderAttendanceSubmit =
    Future<RiderAttendanceResult> Function(String qrPayload);
typedef RiderAttendancePreviewBuilder =
    Widget Function(
      BuildContext context,
      RiderAttendanceScannerCallbacks callbacks,
    );

class RiderAttendanceScannerCallbacks {
  const RiderAttendanceScannerCallbacks({
    required this.onQrDetected,
    required this.onCameraError,
  });

  final ValueChanged<String?> onQrDetected;
  final ValueChanged<String> onCameraError;
}

class RiderAttendanceScannerPage extends StatefulWidget {
  const RiderAttendanceScannerPage({
    super.key,
    required this.onSubmit,
    this.previewBuilder,
  });

  final RiderAttendanceSubmit onSubmit;
  final RiderAttendancePreviewBuilder? previewBuilder;

  @override
  State<RiderAttendanceScannerPage> createState() =>
      _RiderAttendanceScannerPageState();
}

class _RiderAttendanceScannerPageState
    extends State<RiderAttendanceScannerPage> {
  static final _attendanceQr = RegExp(
    r'^bearly-attendance:v1:\d+:\d+:[a-f0-9]{64}$',
  );

  MobileScannerController? _controller;
  final Set<String> _attemptedPayloads = <String>{};
  String? _cameraError;
  String? _scanMessage;
  RiderAttendanceResult? _result;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.previewBuilder == null) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _onQrDetected(String? rawValue) async {
    if (_result != null || _submitting) return;
    final payload = rawValue?.trim();
    if (payload == null ||
        payload.isEmpty ||
        !_attendanceQr.hasMatch(payload)) {
      const message =
          'That is not a Bearly attendance QR. Scan the current QR displayed by your Logistics provider.';
      if (_scanMessage != message) setState(() => _scanMessage = message);
      return;
    }
    if (!_attemptedPayloads.add(payload)) return;

    setState(() {
      _submitting = true;
      _scanMessage = null;
    });
    try {
      final result = await widget.onSubmit(payload);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _scanMessage = _serverErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onCapture(BarcodeCapture capture) {
    if (_result != null || _submitting) return;
    for (final barcode in capture.barcodes) {
      if (barcode.format == BarcodeFormat.qrCode) {
        unawaited(_onQrDetected(barcode.rawValue));
        return;
      }
    }
    if (capture.barcodes.isNotEmpty) {
      unawaited(_onQrDetected(capture.barcodes.first.rawValue));
    }
  }

  void _onCameraError(String message) {
    if (!mounted || _result != null) return;
    setState(() => _cameraError = message);
  }

  String _cameraErrorMessage(
    MobileScannerException error,
  ) => switch (error.errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'Camera permission was denied. Allow camera access in device settings, then return and scan again.',
    MobileScannerErrorCode.unsupported =>
      'A camera is unavailable on this device. Return to the Rider dashboard and try another device.',
    _ =>
      'The camera could not start. Close other camera apps, then return and try again.',
  };

  String _serverErrorMessage(Object error) {
    if (error is ApiHttpException && error.responseData is Map) {
      final body = Map<String, Object?>.from(error.responseData as Map);
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      final errors = body['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is String && value.trim().isNotEmpty) return value;
          if (value is Iterable) {
            for (final item in value) {
              if (item is String && item.trim().isNotEmpty) return item;
            }
          }
        }
      }
    }
    if (error is ApiException) return error.message;
    return 'Attendance could not be recorded. Scan a fresh QR or try again.';
  }

  String _phtTimestamp(DateTime? value) {
    if (value == null) return 'Time unavailable';
    final pht = value.toUtc().add(const Duration(hours: 8));
    final hour = pht.hour % 12 == 0 ? 12 : pht.hour % 12;
    final minute = pht.minute.toString().padLeft(2, '0');
    final period = pht.hour >= 12 ? 'PM' : 'AM';
    return '${pht.year}-${pht.month.toString().padLeft(2, '0')}-${pht.day.toString().padLeft(2, '0')}  $hour:$minute $period PHT';
  }

  void _returnToDashboard() => Navigator.of(context).pop(_result != null);

  Widget _cameraErrorView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _returnToDashboard,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to dashboard'),
          ),
        ],
      ),
    ),
  );

  Widget _scannerPreview() {
    if (_cameraError != null) return _cameraErrorView(_cameraError!);
    final callbacks = RiderAttendanceScannerCallbacks(
      onQrDetected: (value) => unawaited(_onQrDetected(value)),
      onCameraError: _onCameraError,
    );
    final previewBuilder = widget.previewBuilder;
    if (previewBuilder != null) return previewBuilder(context, callbacks);

    return MobileScanner(
      controller: _controller!,
      useAppLifecycleState: true,
      onDetect: _onCapture,
      errorBuilder: (_, error) => _cameraErrorView(_cameraErrorMessage(error)),
      overlayBuilder: (_, constraints) => IgnorePointer(
        child: Center(
          child: Container(
            width: constraints.maxWidth * 0.78,
            height: constraints.maxWidth * 0.78,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView(RiderAttendanceResult result) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            result.checkedIn ? Icons.login_rounded : Icons.logout_rounded,
            size: 56,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 14),
          Text(
            result.checkedIn ? 'Shift checked in' : 'Shift checked out',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(result.message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Text('Work date: ${result.workDate}'),
          const SizedBox(height: 6),
          Text('Recorded: ${_phtTimestamp(result.scannedAt)}'),
          const SizedBox(height: 6),
          Text('Attendance evidence: QR scan ${result.evidenceGeneration}'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _returnToDashboard,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Return to dashboard'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan attendance QR'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        leading: IconButton(
          tooltip: 'Back to dashboard',
          onPressed: _returnToDashboard,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: result == null
            ? Column(
                children: [
                  Expanded(child: _scannerPreview()),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Text(
                      'Scan the current attendance QR displayed by your Logistics provider to check in or check out.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_submitting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: CircularProgressIndicator(),
                    ),
                  if (_scanMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Text(
                        _scanMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.amberAccent),
                      ),
                    ),
                ],
              )
            : DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: _successView(result),
              ),
      ),
    );
  }
}
