import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/screens/usages/EALScanScreen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class EALStickerScreen extends StatefulWidget {
  const EALStickerScreen({super.key});

  @override
  State<EALStickerScreen> createState() => _EALStickerScreenState();
}

class _EALStickerScreenState extends State<EALStickerScreen> {
  DateTime selectedDate = DateTime.now();
  Item? selectedItem;
  bool _disableInputField = false;
  final controller = Get.find<UsageController>();
  final List<String> markets = ['local', 'export'];
  final List<String> stickers = [];

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _navigateToAddStickers() async {
    final items = controller.items;

    final selected = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _ItemSearchBottomSheet(
          items: items,
          onSelected: (value) {
            Navigator.pop(context, value);
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        selectedItem = selected;
        _disableInputField = true;
      });

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EALLinkScannerScreen(
            item: selected,
            date: selectedDate,
          ),
        ),
      );

      if (result == true) {
        // ✅ optionally refresh state
        controller.fetchItems(); // or reload list if needed
        setState(() {});
      }
    }

  }

  Widget _fieldTile({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _disableInputField ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(value ?? 'Select', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        trailing: Icon(icon, color: Colors.teal),
        onTap: onTap,
      ),
    );
  }

  String get _formattedDate => DateFormat('dd-MMM-yyyy').format(selectedDate);

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.currentProduction.clear();
      if (controller.companies.isEmpty || controller.packs.isEmpty) {
        controller.fetchItems();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProduction = controller.currentProduction;

    return Obx(() {
      return Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(
              title: const Text('Production Entry', style: TextStyle(fontWeight: FontWeight.w600)),
              centerTitle: true,
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.teal,
              elevation: 0,
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _fieldTile(
                    label: 'Date',
                    value: _formattedDate,
                    icon: Icons.date_range,
                    onTap: () => !_disableInputField ? _pickDate() : "",
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.qr_code, color: Colors.white,),
                      label: const Text("Add Production", style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: _navigateToAddStickers,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'EAL Used',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: currentProduction.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, index) {
                        final range = currentProduction[index];
                        final from = range.serialFrom;
                        final to = range.serialTo;

                        return ListTile(
                          tileColor: Colors.white,
                          leading: const Icon(Icons.qr_code_2, color: Colors.indigoAccent),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From: ${currentProduction[index].prefix}${from.toString().padLeft(10, '0')}'),
                              const SizedBox(height: 6),
                              Text('To:      ${currentProduction[index].prefix}${to.toString().padLeft(10, '0')}'),
                            ],
                          ),
                          // trailing: Chip(
                          //   label: Text((int.parse(to) - int.parse(from) + 1).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          //   backgroundColor: Colors.indigo.shade100,
                          //   side: BorderSide.none,
                          // ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        );
                      },
                    );
                  })
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


class _ItemSearchBottomSheet extends StatefulWidget {
  final List<Item> items;
  final ValueChanged<Item> onSelected;

  const _ItemSearchBottomSheet({
    required this.items,
    required this.onSelected
  });

  @override
  State<_ItemSearchBottomSheet> createState() => _ItemSearchBottomSheetState();
}

class _ItemSearchBottomSheetState extends State<_ItemSearchBottomSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      final lowerQuery = query.toLowerCase();
      return item.name.toLowerCase().contains(lowerQuery) ||
            item.itemCode.toLowerCase().contains(lowerQuery);
    }).toList();

    return Container(
      color: Colors.grey.shade50,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Item',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: filteredItems.isEmpty
                  ? const Text('No items found.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredItems.length,
                      separatorBuilder: (context, index) => const Divider(height: 0),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          title: Text(item.name),
                          onTap: () {
                            Navigator.pop(context, item);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
