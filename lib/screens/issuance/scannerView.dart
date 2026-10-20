import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerView extends StatefulWidget {
  final Function(BarcodeCapture) onDetect;
  final MobileScannerController controller;

  const ScannerView({
    super.key,
    required this.onDetect,
    required this.controller,
  });

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  bool torchOn = false;
  bool scanned = false;

  void toggleTorch() {
    widget.controller.toggleTorch();
    setState(() {
      torchOn = !torchOn;
    });
  }

  void handleCapture(BarcodeCapture capture) {
    if (scanned) return;

    setState(() {
      scanned = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      Navigator.pop(context, capture);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: widget.controller,
            onDetect: handleCapture,
          ),

          // QR Guide Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Top Buttons (torch + close)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                  IconButton(
                    onPressed: toggleTorch,
                    icon: Icon(
                      torchOn ? Icons.flashlight_off : Icons.flashlight_on,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instruction Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white70, size: 28),
                  SizedBox(height: 8),
                  Text(
                    'Place the QR code inside the white box',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'It will scan automatically',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}