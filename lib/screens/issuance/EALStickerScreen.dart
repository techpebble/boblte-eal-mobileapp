import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/screens/issuance/EALScanScreen.dart';
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
  String? selectedMarket;
  Company? selectedCompany;
  PackSize? selectedPack;
  bool _disableInputField = false;

  final controller = Get.find<Issuancecontroller>();
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

  void _showBottomSheet({
    required List options,
    required String title,
    required String Function(dynamic) label,
    required ValueChanged<dynamic> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...options.map((opt) => ListTile(
                  title: Text(label(opt)),
                  onTap: () {
                    onSelected(opt);
                    Navigator.pop(context);
                  },
                ))
          ],
        ),
      ),
    );
  }

  void _navigateToAddStickers() {
    if (selectedCompany == null || selectedMarket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Company and Market before proceeding.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final packs = controller.packs;

    _showBottomSheet(
      options: packs,
      title: 'Select Pack Size',
      label: (p) => p.name,
      onSelected: (pack) async {
        setState(() => selectedPack = pack);
        // Navigate only after pack is selected
        Future.delayed(const Duration(milliseconds: 200), () {
          _disableInputField = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EALLinkScannerScreen(company: selectedCompany, pack: selectedPack, market: selectedMarket ,date: selectedDate),
            ),
          );
        });
      },
    );
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
        trailing: Icon(icon, color: Colors.indigo),
        onTap: onTap,
      ),
    );
  }

  String get _formattedDate => DateFormat('dd-MMM-yyyy').format(selectedDate);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.currentEalIssuance.clear();
      if (controller.companies.isEmpty || controller.packs.isEmpty) {
        controller.fetchCompanies();
        controller.fetchPackSizes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentEalIssuance = controller.currentEalIssuance;
    final companies = controller.companies;

    return Obx(() {
      return Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(
              title: const Text('EAL Issuance Entry', style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.indigo,
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
                  _fieldTile(
                    label: 'Company',
                    value: selectedCompany?.name,
                    icon: Icons.arrow_drop_down,
                    onTap: () => 
                    !_disableInputField ?
                      _showBottomSheet(
                        options: companies,
                        title: 'Select Company',
                        label: (c) => c.name,
                        onSelected: (c) => setState(() => selectedCompany = c),
                      ) : "",
                  ),
                  _fieldTile(
                    label: 'Market',
                    value: selectedMarket != null ? "${selectedMarket?[0].toUpperCase()}${selectedMarket?.substring(1)}" : "Select",
                    icon: Icons.arrow_drop_down,
                    onTap: () => 
                    !_disableInputField ?
                      _showBottomSheet(
                        options: markets,
                        title: 'Select Market',
                        label: (m) => "${m?[0].toUpperCase()}${m?.substring(1)}",
                        onSelected: (m) => setState(() => selectedMarket = m),
                      ) : "",
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.qr_code, color: Colors.white,),
                      label: const Text("Add EAL Stickers", style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: _navigateToAddStickers,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'EAL Issued',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: currentEalIssuance.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, index) {
                        final range = currentEalIssuance[index];
                        final from = range.serialFrom;
                        final to = range.serialTo;

                        return ListTile(
                          tileColor: Colors.white,
                          leading: const Icon(Icons.qr_code_2, color: Colors.indigoAccent),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From: ${currentEalIssuance[index].prefix}${from.toString().padLeft(10, '0')}'),
                              const SizedBox(height: 6),
                              Text('To:      ${currentEalIssuance[index].prefix}${to.toString().padLeft(10, '0')}'),
                            ],
                          ),
                          trailing: Chip(
                            label: Text((int.parse(to) - int.parse(from) + 1).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.indigo.shade100,
                            side: BorderSide.none,
                          ),
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
