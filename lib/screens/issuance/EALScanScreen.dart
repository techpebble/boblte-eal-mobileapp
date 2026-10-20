import 'dart:typed_data';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scannerView.dart';

class EALLinkScannerScreen extends StatefulWidget {
  final Company? company;
  final PackSize? pack;
  final String? market;
  final DateTime date;

  const EALLinkScannerScreen({super.key,  required this.company, required this.pack, required this.market, required this.date});

  @override
  State<EALLinkScannerScreen> createState() => _EALLinkScannerScreenState();
}

class _EALLinkScannerScreenState extends State<EALLinkScannerScreen> {
  final List<FocusNode> _focusNodes = List.generate(3, (_) => FocusNode());
  final List<TextEditingController> _prefixControllers = List.generate(3, (_) => TextEditingController());

  bool showQRFromTo = false;

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

    // Pattern 1: pipe-separated official QR format
    final pattern1 = RegExp(r'^([A-Z0-9]+)\|(\d{10})\|(\d{10})\|(\d{10})\|(\d+)\|(\d+)$');

    // Pattern 2: underscore-separated range format
    final pattern2 = RegExp(r'^(\d{10})_(\d{10})_.*[|~]\d*\|?$');
    
    if (raw == null) {
      Get.snackbar('Error', 'QR content is empty.');
      return;
    }

    if (pattern1.hasMatch(raw)) {
      final parts = raw.split('|');
      final scannedValue = int.tryParse(parts[1]);

      if (scannedValue == null) {
        Get.snackbar('Error', 'Invalid serial number in QR');
        return;
      }


      if (!showQRFromTo) {
        setState(() {
          serialTo = '';
        });
      }
      
      setState(() {
        showQRFromTo = true;
        if (from) {
          qrRawFrom = raw;
          serialFrom = (scannedValue - widget.pack!.bottlesPerCase + 1).toString().padLeft(10, '0');
        } else {
          qrRawTo = raw;
          serialTo = scannedValue.toString().padLeft(10, '0');
        }
      });
    } else if (pattern2.hasMatch(raw)) {
      final match = pattern2.firstMatch(raw);
      if (match == null) {
        Get.snackbar('Error', 'Unable to parse range QR.');
        return;
      }

      final fromSerial = match.group(1);
      final toSerial = match.group(2);

      if (fromSerial == null || toSerial == null) {
        Get.snackbar('Error', 'Invalid serial range in QR');
        return;
      }

      setState(() {
        showQRFromTo = false;
        qrRawFrom = raw;
        serialFrom = fromSerial;
        serialTo = toSerial;
        imageFrom = image;
        imageTo = image;
      });
    } else {
      Get.snackbar('Invalid QR', 'QR Code format is incorrect.');
    }
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

  int? calculateStickerCount(String? serialFrom, String? serialTo) {
    if (serialFrom == null || serialTo == null) return null;

    final from = int.tryParse(serialFrom);
    final to = int.tryParse(serialTo);

    if (from == null || to == null) return null;

    return (to - from + 1);
  }

  @override
  Widget build(BuildContext context) {
  final controller = Get.find<Issuancecontroller>();

    return Obx(() {
      return Stack(
        children: [
          Scaffold(backgroundColor: Colors.grey[50],
            appBar: AppBar(
              title: Text('Link ${widget.pack!.name} EAL',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),),
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.indigo,
              elevation: 0,
            ),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildStep("Step 1: Enter Prefix"),
                    buildPrefixInput(),
                    const SizedBox(height: 16),

                    buildStep(showQRFromTo ? "Step 2: Scan 'From' QR" : "Step 2: Scan QR"),
                    GestureDetector(
                      onTap: () => startScan(true),
                      child: Card(
                        elevation: 2,
                        color: Colors.indigo[50],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Icon(Icons.qr_code_2, color: Colors.indigo[900]),
                          title: Text(showQRFromTo ? "Scan 'From' QR" : "Scan QR"),
                          subtitle: qrRawFrom.isNotEmpty ? Text(qrRawFrom) : const Text("No QR scanned yet"),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    if(showQRFromTo) 
                      buildStep("Step 3: Scan 'To' QR"),
                    if(showQRFromTo) 
                      GestureDetector(
                        onTap: () => startScan(false),
                        child: Card(
                          elevation: 2,
                          color: Colors.indigo[50],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(Icons.qr_code_2, color: Colors.indigo[900]),
                            title: const Text("Scan 'To' QR"),
                            subtitle: qrRawTo.isNotEmpty ? Text(qrRawTo) : const Text("No QR scanned yet"),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),

                    if (serialFrom.isNotEmpty || serialTo.isNotEmpty)
                      buildStep("Step 4: Review Summary"),
                    if (serialFrom.isNotEmpty || serialTo.isNotEmpty)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.yellow.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.visibility, color: Colors.black87),
                                  SizedBox(width: 8),
                                  Text("Please verify before submitting", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              buildSummaryRow("Company", widget.company!.name),
                              buildSummaryRow("Market", widget.market ?? ''),
                              buildSummaryRow("Pack", widget.pack!.name),
                              buildSummaryRow("Prefix", getPrefix()),
                              buildSummaryRow("Serial From", serialFrom),
                              buildSummaryRow("Serial To", serialTo),
                              if (calculateStickerCount(serialFrom, serialTo) != null)
                                buildSummaryRow("Quantity", calculateStickerCount(serialFrom, serialTo)!.toString()),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final prefix = getPrefix();

                            if (prefix.length != 3 || serialFrom.isEmpty || serialTo.isEmpty) {
                              Get.snackbar('Missing fields', 'Please complete all fields');
                              return;
                            }

                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Submission'),
                                content: const Text('Are you sure all values are correct?'),
                                actions: [
                                  TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
                                  ElevatedButton(child: const Text('Confirm'), onPressed: () => Navigator.pop(context, true)),
                                ],
                              ),
                            );

                            if (confirmed != true) return;
                            
                            // SEND THE DATA TO THE SERVER
                            final ok = await Get.find<Issuancecontroller>().addEALIssuance(
                              company: widget.company,
                              dateIssued: widget.date,
                              market: widget.market ?? '',
                              pack: widget.pack,
                              prefix: prefix,
                              serialFrom: serialFrom,
                              serialTo: serialTo,
                              issuedQuantity: calculateStickerCount(serialFrom, serialTo) ?? 0,
                            );

                            if (ok) {
                              Get.back();
                            }
                          },
                          icon: const Icon(Icons.cloud_upload, color: Colors.white),
                          label: const Text('Submit', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
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


}

