import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) async {
          if (_isProcessing) return;
          final barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String? scannedValue = barcode.rawValue;
            if (scannedValue != null) {
              _isProcessing = true;
              // Short delay to avoid navigator conflicts
              await Future.delayed(const Duration(milliseconds: 50));
              if (mounted) {
                Navigator.pop(context, scannedValue);
              }
              return;
            }
          }
        },
      ),
    );
  }
}