import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/screens/dispatches/EALScanScreen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EALDetailScreen extends StatelessWidget {
  final String dispatchItemId;
  final String dispatchId;

  const EALDetailScreen({super.key, required this.dispatchItemId, required this.dispatchId});

  @override
  Widget build(BuildContext context) {
    final DispatchController controller = Get.find();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('EAL Details', 
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: Obx(() {
        final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == dispatchId);
        final item = dispatch?.items.firstWhereOrNull((i) => i.id == dispatchItemId);

        if (item == null) {
          return const Center(child: Text("Dispatch not found"));
        }

        final isMismatch = item.quantityInCases != item.issuedQty || item.links.isEmpty;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                  border: Border.all(
                    color: isMismatch ? Colors.red.shade200 : Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          isMismatch ? Icons.warning_amber : Icons.check_circle,
                          size: 18,
                          color: isMismatch ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isMismatch ? 'Mismatch or missing EAL links' : 'EAL linked successfully',
                            style: TextStyle(
                              color: isMismatch ? Colors.red : Colors.green,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Colors.grey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${item.quantityInCases} Cases"),
                        const Text("EAL Linked", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${item.issuedQty} Cases", style: TextStyle(color: isMismatch ? Colors.red : Colors.green),),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Linked EAL Ranges',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              item.links.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.warning_amber, color: Colors.red),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No EAL linked for this item',
                              style: TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          )
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: item.links.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, index) {
                        final eal = item.links[index];
                        final from = eal.serialFrom;
                        final to = eal.serialTo;
                        final cases = ((to - from + 1) / item.bottlesPerCase).round();
                        final isFinal = dispatch?.status.toLowerCase() == 'final';

                        final listTile = ListTile(
                          tileColor: Colors.white,
                          leading: const Icon(Icons.qr_code_2, color: Colors.blue),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From: ${eal.prefix}${from.toString().padLeft(10, '0')}'),
                              const SizedBox(height: 6),
                              Text('To:      ${eal.prefix}${to.toString().padLeft(10, '0')}'),
                            ],
                          ),
                          trailing: Chip(
                            label: Text('$cases Cases', style: const TextStyle(fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.green.shade100,
                            side: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        );

                        return isFinal
                            ? Dismissible(
                                key: Key(eal.id),
                                background: Container(
                                  color: Colors.red.shade400,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                secondaryBackground: Container(
                                  color: Colors.red.shade400,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                confirmDismiss: (_) async {
                                  return await Get.dialog(
                                    AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Row(
                                        children: const [
                                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text("Remove EAL Link", style: TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      content: const Text(
                                        "Are you sure you want to remove this EAL link?",
                                        style: TextStyle(fontSize: 15),
                                      ),
                                      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      actionsAlignment: MainAxisAlignment.spaceBetween,
                                      actions: [
                                        TextButton(
                                          onPressed: () => Get.back(result: false),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.grey[700],
                                          ),
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Get.back(result: true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[600],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text("Remove"),
                                        ),
                                      ],
                                    )

                                  );
                                },
                                onDismissed: (_) async {
                                  await controller.removeEALLink(
                                    dispatchId: dispatchId,
                                    itemId: item.itemId,
                                    prefix: eal.prefix,
                                    serialFrom: eal.serialFrom.toString(),
                                    serialTo: eal.serialTo.toString(),
                                  );

                                  Get.snackbar(
                                    "Deleted",
                                    "EAL link removed",
                                    backgroundColor: Colors.white,
                                    colorText: Colors.black,
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                                child: listTile,
                              )
                            : listTile;
                      },
                    )
,

              const SizedBox(height: 20),

              Row(
                children: [
                  Icon(
                    isMismatch ? Icons.warning : Icons.check_circle,
                    color: isMismatch ? Colors.red : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMismatch
                        ? 'Mismatch: Quantity and EALs not aligned'
                        : 'EAL linked and verified',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: isMismatch ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == dispatchId);
        final item = dispatch?.items.firstWhereOrNull((i) => i.id == dispatchItemId);
        final disableLinkBtn = dispatch?.status.toLowerCase() != 'final' ||
            (item != null && item.quantityInCases == item.issuedQty);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: disableLinkBtn
                ? null
                : () {
                    Get.to(() => EALLinkScannerScreen(
                          dispatchItemId: dispatchItemId,
                          dispatchId: dispatchId,
                        ));
                  },
            icon: const Icon(Icons.link, color: Colors.white),
            label: const Text('Link EAL', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: disableLinkBtn ? Colors.grey : Colors.blue[900],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }),
    );
  }
}