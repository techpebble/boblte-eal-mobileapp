import 'dart:typed_data';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scannerView.dart';

class EALLinkScannerScreen extends StatefulWidget {
  final String dispatchItemId;
  final String dispatchId;

  const EALLinkScannerScreen({super.key, required this.dispatchItemId, required this.dispatchId});

  @override
  State<EALLinkScannerScreen> createState() => _EALLinkScannerScreenState();
}

class _EALLinkScannerScreenState extends State<EALLinkScannerScreen> {
  final List<FocusNode> _focusNodes = List.generate(3, (_) => FocusNode());
  final List<TextEditingController> _prefixControllers = List.generate(3, (_) => TextEditingController());

  bool _disableInputField = false;
  String qrRawFrom = '';
  String qrRawTo = '';
  String serialFrom = '';
  String serialTo = '';
  Uint8List? imageFrom;
  Uint8List? imageTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disableInputField && getPrefix().length < 3) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _prefixControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> startScan(bool from) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerView(
          controller: MobileScannerController(),
          onDetect: (capture) => Navigator.pop(context, capture),
        ),
      ),
    );

    FocusScope.of(context).unfocus();

    if (!_disableInputField && getPrefix().length == 3) {
      setState(() {
        _disableInputField = true;
      });
    }

    if (result is BarcodeCapture) {
      handleScan(result, from);
    }
  }

  void handleScan(BarcodeCapture result, bool from) {
    if (result.barcodes.isEmpty) return;

    final raw = result.barcodes.first.rawValue;
    final image = result.image;

    final _pattern = RegExp(r'^([A-Z0-9]+)\|(\d{10})\|(\d{10})\|(\d{10})\|(\d+)\|(\d+)$');

    if (raw == null || !_pattern.hasMatch(raw)) {
      Get.snackbar('Invalid QR', 'QR Code format is incorrect.');
      return;
    }

    final parts = raw.split('|');
    final scannedValue = int.tryParse(parts[1]);

    if (scannedValue == null) {
      Get.snackbar('Error', 'Invalid serial number in QR');
      return;
    }

    setState(() {
      final DispatchController controller = Get.find();
      final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == widget.dispatchId);
      final item = dispatch?.items.firstWhereOrNull((i) => i.id == widget.dispatchItemId);
      final  bottlesPerCase = item?.bottlesPerCase ?? 0;
      if (from) {
        qrRawFrom = raw;
        serialFrom = (scannedValue - bottlesPerCase + 1).toString().padLeft(10, '0');
        imageFrom = image;
      } else {
        qrRawTo = raw;
        serialTo = scannedValue.toString().padLeft(10, '0');
        imageTo = image;
      }
    });
  }

  int calculateCases() {
    final DispatchController controller = Get.find();
    final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == widget.dispatchId);
    final item = dispatch?.items.firstWhereOrNull((i) => i.id == widget.dispatchItemId);
    
    if (serialFrom.isEmpty || serialTo.isEmpty || item == null) return 0;
    final from = int.parse(serialFrom);
    final to = int.parse(serialTo);
    return ((to - from + 1) / item.bottlesPerCase).round();
  }

  String getPrefix() {
    return _prefixControllers.map((c) => c.text.toUpperCase()).join();
  }

  Widget buildPrefixInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 60,
          height: 70,
          child: TextField(
            controller: _prefixControllers[index],
            readOnly: _disableInputField,
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.blue.shade50,
            ),
            onChanged: (value) {
              final upper = value.toUpperCase();
              _prefixControllers[index].text = upper;
              _prefixControllers[index].selection = TextSelection.collapsed(offset: 1);

              if (upper.isNotEmpty) {
                if (index < 2) {
                  FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                } else {
                  FocusScope.of(context).unfocus();
                  setState(() => _disableInputField = true);
                }
              }
              setState(() {});
            },
          ),
        );
      }),
    );
  }

  Widget buildStep(String stepTitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.blue[900]),
          const SizedBox(width: 8),
          Text(stepTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DispatchController controller = Get.find();

    return Obx(() {
      return Stack(
        children: [
          Scaffold(backgroundColor: Colors.grey[50],
            appBar: AppBar(
              title: const Text('Link EAL', 
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),),
              backgroundColor: Colors.grey[50],
              foregroundColor: Colors.deepOrange,
              elevation: 0,
            ),
            body: Obx(() {
              final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == widget.dispatchId);
              final item = dispatch?.items.firstWhereOrNull((i) => i.id == widget.dispatchItemId);
              if (item == null) return const Text("No item found");
            
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildStep("Step 1: Enter Prefix"),
                    buildPrefixInput(),
                    const SizedBox(height: 16),

                    buildStep("Step 2: Scan 'From' QR"),
                    GestureDetector(
                      onTap: () => startScan(true),
                      child: Card(
                        elevation: 2,
                        color: Colors.blue[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Icon(Icons.qr_code_2, color: Colors.blue[900]),
                          title: const Text("Scan 'From' QR"),
                          subtitle: qrRawFrom.isNotEmpty ? Text(qrRawFrom) : const Text("No QR scanned yet"),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    buildStep("Step 3: Scan 'To' QR"),
                    GestureDetector(
                      onTap: () => startScan(false),
                      child: Card(
                        elevation: 2,
                        color: Colors.blue[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Icon(Icons.qr_code_2, color: Colors.blue[900]),
                          title: const Text("Scan 'To' QR"),
                          subtitle: qrRawTo.isNotEmpty ? Text(qrRawTo) : const Text("No QR scanned yet"),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (serialFrom.isNotEmpty || serialTo.isNotEmpty)
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.receipt_long, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text("Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              buildSummaryRow("Prefix", getPrefix()),
                              buildSummaryRow("Serial From", serialFrom),
                              buildSummaryRow("Serial To", serialTo),
                              buildSummaryRow("Quantity", "${calculateCases()} case(s)"),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final prefix = getPrefix();

                  if (prefix.length != 3 || serialFrom.isEmpty || serialTo.isEmpty) {
                    Get.snackbar('Missing fields', 'Please complete all fields');
                    return;
                  }

                  final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == widget.dispatchId);
                  final item = dispatch?.items.firstWhereOrNull((i) => i.id == widget.dispatchItemId);

                  if (item == null) {
                    Get.snackbar('Error', 'Item not found in dispatch');
                    return;
                  }
                  
                  // SEND THE DATA TO THE SERVER
                  final ok = await Get.find<DispatchController>().submitEALLink(
                    dispatchId: widget.dispatchId,
                    itemId: item.itemId,
                    prefix: prefix,
                    serialFrom: serialFrom,
                    serialTo: serialTo,
                  );

                  if (ok) {
                    Get.back();
                  }
                },
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                label: const Text('Submit', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          // 🔄 Fullscreen Loading Overlay (covers AppBar too)
          if (controller.isLoading.value)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.indigo),
              ),
            ),
        ]
      );
    });
  }

  Widget buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
