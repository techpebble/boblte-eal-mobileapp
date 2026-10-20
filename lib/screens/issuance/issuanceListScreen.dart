import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/screens/issuance/EALStickerScreen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'issuanceDetailScreen.dart';

class IssuanceListScreen extends StatelessWidget {
  const IssuanceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<Issuancecontroller>();

    // Fetch only on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.ealIssuance.isEmpty) {
        controller.fetchEALIssuance();
      }
    });

    return Obx(() {
      return Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: const Text(
                'EAL Issuance',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.grey.shade50,
              foregroundColor: Colors.indigo,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: controller.pickDate,
                  tooltip: 'Pick Date',
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: controller.ealIssuance.isEmpty && !controller.isLoading.value
                      ? Center(
                          child: Text(
                            "No issuance found on ${DateFormat('dd-MMM-yyyy').format(controller.selectedDate.value)}",
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => controller.fetchEALIssuance(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: controller.ealIssuance.length,
                            itemBuilder: (context, index) {
                              final IssuanceModel d = controller.ealIssuance[index];
                              return GestureDetector(
                                onTap: () => Get.to(() => EALIssuanceDetailScreen(issuance: d)),
                                child: Card(
                                  color: Colors.indigo.shade50,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 6,
                                  margin: const EdgeInsets.symmetric(vertical: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${d.packName.toUpperCase()} | ${d.market.toUpperCase()}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.indigo.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                DateFormat('dd-MMM-yyyy').format(d.dateIssued).toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.indigo,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('From: ${d.prefix + d.serialFrom.toString().padLeft(10, '0')}'),
                                        const SizedBox(height: 4),
                                        Text('To: ${d.prefix + d.serialTo.toString().padLeft(10, '0')}'),
                                        const SizedBox(height: 4),
                                        Text('Company: ${d.companyName}'),
                                        const SizedBox(height: 4),
                                        const Divider(height: 15, color: Colors.grey),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Issued Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text(_formatNumber(d.issuedQuantity)),
                                            const Text("Balance Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text(_formatNumber(d.balanceQuantity)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Get.to(() => const EALStickerScreen()),
              backgroundColor: Colors.indigo,
              shape: const CircleBorder(),
              elevation: 5,
              child: const Icon(Icons.add, color: Colors.white),
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
        ],
      );
    });
  }

}

String _formatNumber(int number) {
  return NumberFormat.decimalPattern().format(number); // e.g., 48,000
}