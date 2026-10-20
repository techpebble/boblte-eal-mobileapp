import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/screens/dispatches/EALDetailScreen.dart';

class DispatchDetailScreen extends StatelessWidget {
  final String dispatchId;

  const DispatchDetailScreen({super.key, required this.dispatchId});

  @override
  Widget build(BuildContext context) {
    final DispatchController controller = Get.find();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Dispatch Details', 
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: Obx(() {
        final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == dispatchId);

        if (dispatch == null) {
          return const Center(child: Text("Dispatch not found"));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(dispatchId, context),
              const SizedBox(height: 24),
              const Text(
                'Items',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...dispatch.items.map((item) => _buildItemCard(item, dispatch.id)).toList(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader(String dispatchId, BuildContext context) {
    final controller = Get.find<DispatchController>();

    return Obx(() {
      final dispatch = controller.dispatches.firstWhereOrNull((d) => d.id == dispatchId);

      if (dispatch == null) {
        return const Center(child: Text("Dispatch not found"));
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: controller.getStatusColor(dispatch.status),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title + Edit Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        dispatch.depotName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white70,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, size: 20, color: controller.getStatusChipColor(dispatch.status)),
                        tooltip: 'Edit',
                        onPressed: () => _showEditBottomSheet(context, dispatch),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Vehicle', dispatch.vehicleNumber, Icons.local_shipping, controller.getStatusChipColor(dispatch.status)),
                _infoRow('Driver', '${dispatch.driverName} (${dispatch.driverContact})', Icons.person, controller.getStatusChipColor(dispatch.status)),
                _infoRow('Date', DateFormat('dd MMM yyyy').format(dispatch.dateDispatched), Icons.date_range, controller.getStatusChipColor(dispatch.status)),
                const SizedBox(height: 24), // spacing to avoid overlap with the chip
              ],
            ),

            /// Positioned Status Chip at Bottom Right
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: controller.getStatusChipColor(dispatch.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dispatch.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        )

      );
    });
  }

  void _showEditBottomSheet(BuildContext context, DispatchModel dispatch) {
    final vehicleController = TextEditingController(text: dispatch.vehicleNumber);
    final driverNameController = TextEditingController(text: dispatch.driverName);
    final driverContactController = TextEditingController(text: dispatch.driverContact);
    final formKey = GlobalKey<FormState>();

    final statusOrder = ['draft', 'final', 'loaded', 'dispatched', 'delivered'];
    final currentIndex = statusOrder.indexOf(dispatch.status.toLowerCase());
    final allowedNextStatuses = currentIndex < statusOrder.length - 1
        ? [dispatch.status.toLowerCase(), statusOrder[currentIndex + 1]]
        : [dispatch.status.toLowerCase()];
    String selectedStatus = dispatch.status.toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag indicator
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Edit Dispatch Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          // VEHICLE
                          TextFormField(
                            controller: vehicleController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle Number',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Vehicle number is required';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              vehicleController.value = vehicleController.value.copyWith(
                                text: val.toUpperCase(),
                                selection: TextSelection.collapsed(offset: val.length),
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // DRIVER
                          TextFormField(
                            controller: driverNameController,
                            decoration: const InputDecoration(
                              labelText: 'Driver Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Driver name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // MOBILE
                          TextFormField(
                            controller: driverContactController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'Driver Contact',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || !RegExp(r'^\d{10}$').hasMatch(val)) {
                                return 'Enter valid 10-digit number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // STATUS - better UX
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (_) {
                                  return SafeArea(
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: allowedNextStatuses.map((status) {
                                        return ListTile(
                                          title: Text(status.toUpperCase()),
                                          trailing: status == selectedStatus
                                              ? const Icon(Icons.check, color: Colors.blue)
                                              : null,
                                          onTap: () {
                                            if (status == 'loaded' && dispatch.totalQuantity != dispatch.issuedQty) {
                                              Get.snackbar(
                                                'Error',
                                                'Cannot mark as "Loaded" until all items are issued.',
                                                backgroundColor: Colors.red[100],
                                                colorText: Colors.red[900],
                                                icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                              );
                                              Navigator.pop(context); // Close if already selected
                                              return;
                                            } else {
                                              setState(() {
                                                selectedStatus = status;
                                              });
                                              Navigator.pop(context);
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedStatus.toUpperCase(),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Icon(Icons.expand_more),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    // SAVE BUTTON
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            // Perform update
                            await Get.find<DispatchController>().updateVehicleDetails(
                              dispatchId: dispatch.id,
                              vehicleNumber: vehicleController.text,
                              driverName: driverNameController.text,
                              driverContact: driverContactController.text,
                              status: selectedStatus,
                            );
                            Navigator.pop(context); // Close the sheet
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, IconData icon, Color chipColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: chipColor),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
            Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildItemCard(DispatchItemModel item, String dispatchId) {
    final hasMismatch = item.quantityInCases != item.issuedQty || item.links.isEmpty;

    return GestureDetector(
      onTap: () => Get.to(() => EALDetailScreen(dispatchItemId: item.id, dispatchId: dispatchId)),
      child: Container(
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
            color: hasMismatch ? Colors.red.shade200 : Colors.green.shade200,
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
                  hasMismatch ? Icons.warning_amber : Icons.check_circle,
                  size: 18,
                  color: hasMismatch ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasMismatch ? 'Mismatch or missing EAL links' : 'EAL linked successfully',
                    style: TextStyle(
                      color: hasMismatch ? Colors.red : Colors.green,
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
                Text("${item.quantityInCases} cases"),
                const Text("EAL Linked", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${item.issuedQty} cases", style: TextStyle(color: hasMismatch ? Colors.red : Colors.green),),
              ],
            )
          ],
        ),
      ),
    );
  }

}