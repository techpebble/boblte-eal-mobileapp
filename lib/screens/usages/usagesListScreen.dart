import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/screens/usages/EALStickerScreen.dart';
import 'package:eal_scanner/screens/usages/usageDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class UsagesListScreen extends StatelessWidget {
  const UsagesListScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UsageController>();

    // Run fetch only when widget is loaded first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.ealUsages.isEmpty) {
        controller.fetchEALUsage();
      }
    });

    return Obx(() {
      return Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: const Text('EAL Usages', style: TextStyle(
                fontWeight: FontWeight.w600,
              ),),
              backgroundColor: Colors.grey.shade50,
              foregroundColor: Colors.teal,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: controller.pickDate,
                  tooltip: 'Pick Date',
                ),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: controller.ealUsages.isEmpty && !controller.isLoading.value
                    ? Center(
                      child: Text(
                        "No issuance found on ${DateFormat('dd-MMM-yyyy').format(controller.selectedDate.value)}")
                      )
                      : RefreshIndicator(
                        onRefresh: () async => controller.fetchEALUsage(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: controller.ealUsages.length,
                          itemBuilder: (context, index) {
                            final UsageModel usage = controller.ealUsages[index];

                            return GestureDetector(
                              onTap: () => Get.to(() => EALUsageDetailScreen(usage: usage)),
                              child: Card(
                                  color: Colors.teal.shade50,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
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
                                                usage.itemName,
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
                                                color: Colors.teal.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                DateFormat('dd-MMM-yyyy').format(usage.dateUsed).toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('From: ${usage.prefix + usage.serialFrom.toString().padLeft(10, '0')}'),
                                        const SizedBox(height: 4),
                                        Text('To: ${usage.prefix + usage.serialTo.toString().padLeft(10, '0')}'),
                                        const SizedBox(height: 4),
                                        Text('Company: ${usage.companyName}'),
                                        const SizedBox(height: 4),
                                        const Divider(height: 15, color: Colors.grey),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Issued Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text("${_formatNumber(usage.usedQuantityInCases)} Cs"),
                                            const Text("Balance Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text("${_formatNumber(usage.balanceQuantityInCases)} Cs"),
                                          ],
                                        )
                                      ],
                                    ),
                                  )
                              )
                            );
                          })
                      )
                    ),
                  ],
                ),

                // Floating Add Button (Bottom Left)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: () {
                      Get.to(() => EALStickerScreen());
                    },
                    backgroundColor: Colors.teal,
                    shape: const CircleBorder(),
                    elevation: 5,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                )
              ],
            )
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

String _formatNumber(int number) {
  return NumberFormat.decimalPattern().format(number); // e.g., 48,000
}