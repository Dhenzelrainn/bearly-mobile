import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef WaybillScannerPreviewBuilder =
    Widget Function(BuildContext context, WaybillScannerCallbacks callbacks);

class WaybillScannerCallbacks {
  const WaybillScannerCallbacks({
    required this.onBarcodeDetected,
    required this.onCameraError,
  });

  final ValueChanged<String?> onBarcodeDetected;
  final ValueChanged<String> onCameraError;
}

class RiderWaybillScannerPage extends StatefulWidget {
  const RiderWaybillScannerPage({
    super.key,
    this.previewBuilder,
    this.title = 'Scan waybill barcode',
  });

  /// Lets widget tests exercise scan results and camera failures without a device.
  final WaybillScannerPreviewBuilder? previewBuilder;
  final String title;

  @override
  State<RiderWaybillScannerPage> createState() =>
      _RiderWaybillScannerPageState();
}

class _RiderWaybillScannerPageState extends State<RiderWaybillScannerPage> {
  MobileScannerController? _controller;
  String? _cameraError;
  String? _scanMessage;
  bool _didReturnValue = false;

  @override
  void initState() {
    super.initState();
    if (widget.previewBuilder == null) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.code128],
      );
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  void _onBarcodeDetected(String? rawValue) {
    if (_didReturnValue) return;
    if (rawValue == null || rawValue.trim().isEmpty) {
      const message =
          'No readable Code 128 value was found. Try again or cancel to enter the waybill manually.';
      if (_scanMessage != message) setState(() => _scanMessage = message);
      return;
    }

    _didReturnValue = true;
    Navigator.of(context).pop(rawValue);
  }

  void _onCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      if (barcode.format == BarcodeFormat.code128) {
        _onBarcodeDetected(barcode.rawValue);
        return;
      }
    }
    if (capture.barcodes.isNotEmpty) _onBarcodeDetected(null);
  }

  void _onCameraError(String message) {
    if (!mounted || _didReturnValue) return;
    setState(() => _cameraError = message);
  }

  String _cameraErrorMessage(
    MobileScannerException error,
  ) => switch (error.errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'Camera permission was denied. Allow camera access in device settings, or return to enter the waybill manually.',
    MobileScannerErrorCode.unsupported =>
      'A camera is unavailable on this device. Return to enter the waybill manually.',
    _ =>
      'The camera could not start. Close other camera apps or return to enter the waybill manually.',
  };

  void _cancel() => Navigator.of(context).maybePop();

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
            onPressed: _cancel,
            icon: const Icon(Icons.keyboard_alt_outlined),
            label: const Text('Return to manual entry'),
          ),
        ],
      ),
    ),
  );

  Widget _scannerPreview() {
    if (_cameraError != null) return _cameraErrorView(_cameraError!);

    final callbacks = WaybillScannerCallbacks(
      onBarcodeDetected: _onBarcodeDetected,
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
            width: constraints.maxWidth * 0.84,
            height: 104,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: Text(widget.title),
      foregroundColor: Colors.white,
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          tooltip: 'Cancel scan',
          onPressed: _cancel,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(child: _scannerPreview()),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Text(
              'Align the printed Code 128 waybill barcode within the frame.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
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
      ),
    ),
  );
}
