import 'package:eal_scanner/models/usage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EALUsageDetailScreen extends StatelessWidget {
  final UsageModel usage;

  const EALUsageDetailScreen({super.key, required this.usage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('EAL Issuance Detail', style: TextStyle(
          fontWeight: FontWeight.w600,
        ),),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
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
              itemCount: usage.usedSerialRanges.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final range = usage.usedSerialRanges[index];
                final from = range.serialFrom;
                final to = range.serialTo;

                return ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.qr_code_2, color: Colors.teal),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: ${usage.prefix}${from.toString().padLeft(10, '0')}'),
                      const SizedBox(height: 6),
                      Text('To:      ${usage.prefix}${to.toString().padLeft(10, '0')}'),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(_formatNumber(range.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.teal.shade100,
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