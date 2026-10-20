import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/loginController.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/screens/login.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/theme/app_theme.dart';
import 'package:eal_scanner/widgets/ui/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.lazyPut(() => DispatchController(), fenix: true);
  Get.lazyPut(() => Issuancecontroller(), fenix: true);
  Get.lazyPut(() => UsageController(), fenix: true);
  Get.lazyPut(() => LoginController(), fenix: true);
  Get.lazyPut(() => DashboardController(), fenix: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppBrand.name,
      theme: AppTheme.light,
      home: AuthService.isLoggedIn() ? const AppShell() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
