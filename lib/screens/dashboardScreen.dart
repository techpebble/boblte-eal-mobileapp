import 'package:eal_scanner/controllers/loginController.dart';
import 'package:eal_scanner/screens/dispatches/dispatchListScreen.dart';
import 'package:eal_scanner/screens/issuance/issuanceListScreen.dart';
import 'package:eal_scanner/screens/usages/usagesListScreen.dart';
import 'package:flutter/material.dart';
import 'package:eal_scanner/branding.dart';
import 'package:get/get.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_DashboardItem> items = [
      _DashboardItem(
        title: 'EAL Issuance',
        icon: Icons.assignment_turned_in_outlined,
        color: Colors.indigo,
        onTap: () => Get.to(() => IssuanceListScreen()),
      ),
      _DashboardItem(
        title: 'EAL Usage',
        icon: Icons.fact_check_outlined,
        color: Colors.teal,
        onTap: () => Get.to(() => UsagesListScreen()),
      ),
      _DashboardItem(
        title: 'EAL Dispatch',
        icon: Icons.local_shipping_outlined,
        color: Colors.deepOrange,
        onTap: () => Get.to(() => const DispatchListScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(AppBrand.logo, width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Text(
              AppBrand.name,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppBrand.navy),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.find<LoginController>().logout(); // <-- Call the logout
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Logout', style: TextStyle(color: Colors.white),),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: item.color.withOpacity(0.2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 40, color: item.color),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: item.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
