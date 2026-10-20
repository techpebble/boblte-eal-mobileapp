import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/screens/dispatches/DispatchDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../controllers/dispatchController.dart';

class DispatchListScreen extends StatelessWidget {
  const DispatchListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DispatchController>();

    // Run fetch only when widget is loaded first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.dispatches.isEmpty) {
        controller.fetchDispatches();
      }
    });

    return Obx(() {
      return Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              title: const Text('Dispatches', style: TextStyle(
                fontWeight: FontWeight.w600,
              ),),
              backgroundColor: Colors.grey[50],
              foregroundColor: Colors.deepOrange,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) => controller.searchQuery.value = val,
                      decoration: InputDecoration(
                        hintText: 'Search by Delivery Location',
                        hintStyle: const TextStyle(color: Colors.black54),
                        prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                Obx(() => Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  child: Text(
                    'Showing dispatches for: ${DateFormat('dd MMM yyyy').format(controller.selectedDate.value)}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                )),
                Expanded(
                  child: Obx(() {
                    final results = controller.filteredDispatches;

                    if (results.isEmpty) {
                      return const Center(child: Text("No dispatches found."));
                    }

                    return RefreshIndicator(
                      onRefresh: () async => controller.fetchDispatches(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final DispatchModel d = results[index];

                          return GestureDetector(
                            onTap: () => Get.to(() => DispatchDetailScreen(dispatchId: d.id)),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 6,
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              color: controller.getStatusColor(d.status),
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
                                            d.depotName,
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
                                            color: controller.getStatusChipColor(d.status),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            d.status.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Market: ${d.market[0].toUpperCase()}${d.market.substring(1)}'),
                                    Text('Date: ${DateFormat('dd-MMM-yyyy').format(d.dateDispatched)}'),
                                    Text('Company: ${d.companyName}'),
                                    const Divider(height: 20, color: Colors.grey),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Total Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text("${d.totalQuantity} cases"),
                                        const Text("EAL Linked", style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text("${d.issuedQty} cases"),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ),
              ],
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
