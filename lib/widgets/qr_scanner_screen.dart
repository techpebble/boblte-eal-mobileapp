import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String? scannedText;
  BarcodeCapture? lastCapture;
  bool isTorchOn = false;

  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: true,
    facing: CameraFacing.back,
  );

  // Regex to match the required QR code format
  final RegExp validFormat =
      RegExp(r'^IML\d{4}KRN\d{4}\|\d+\|\d+\|\d+\|\d+\|\d+$');

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;

    if (rawValue == null || scannedText != null) return;

    final cleaned = rawValue.trim();

    print('Scanned QR: $cleaned');

    if (!validFormat.hasMatch(cleaned)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid QR format. Please scan again."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      scannedText = cleaned;
      lastCapture = capture;
    });
  }

  void _toggleTorch() {
    controller.toggleTorch();
    setState(() => isTorchOn = !isTorchOn);
  }

  void _resetScan() {
    setState(() {
      scannedText = null;
      lastCapture = null;
    });
  }

  void _submitScannedData() {
    if (scannedText != null) {
      // TODO: Replace this with actual submission logic (e.g., API call)
      print("📤 Submitting QR data: $scannedText");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QR data submitted")),
      );
    }
  }

  Widget _buildCapturedImage() {
    final image = lastCapture?.image;
    if (image == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      height: 300,
      width: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          image,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Code Scanner"),
        actions: [
          IconButton(
            icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: scannedText == null
                ? MobileScanner(
                    controller: controller,
                    onDetect: _onDetect,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCapturedImage(),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          scannedText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
          ),
          if (scannedText != null)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text("Submit"),
                      onPressed: _submitScannedData,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Scan Again"),
                      onPressed: _resetScan,
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
