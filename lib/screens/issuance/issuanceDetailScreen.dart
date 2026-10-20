import 'package:eal_scanner/models/issuance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EALIssuanceDetailScreen extends StatelessWidget {
  final IssuanceModel issuance;

  const EALIssuanceDetailScreen({super.key, required this.issuance});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('EAL Issuance Detail', style: TextStyle(
          fontWeight: FontWeight.w600,
        ),),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.indigo.shade50,
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
                            '${issuance.packName.toUpperCase()} | ${issuance.market.toUpperCase()}',
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
                            DateFormat('dd-MMM-yyyy').format(issuance.dateIssued).toUpperCase(),
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
                    Text('From: ${issuance.prefix + issuance.serialFrom.toString().padLeft(10, '0')}'),
                    const SizedBox(height: 4),
                    Text('To: ${issuance.prefix + issuance.serialTo.toString().padLeft(10, '0')}'),
                    const SizedBox(height: 4),
                    Text('Company: ${issuance.companyName}'),
                    const SizedBox(height: 4),
                    const Divider(height: 15, color: Colors.grey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Issued Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_formatNumber(issuance.issuedQuantity)),
                        const Text("Balance Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_formatNumber(issuance.balanceQuantity)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Used EAL Ranges',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: issuance.usedSerialRanges.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final range = issuance.usedSerialRanges[index];
                final from = range.serialFrom;
                final to = range.serialTo;

                return ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.qr_code_2, color: Colors.indigo),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: ${issuance.prefix}${from.toString().padLeft(10, '0')}'),
                      const SizedBox(height: 6),
                      Text('To:      ${issuance.prefix}${to.toString().padLeft(10, '0')}'),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(_formatNumber(range.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.indigo.shade100,
                    side: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

String _formatNumber(int number) {
  return NumberFormat.decimalPattern().format(number); // e.g., 48,000
}