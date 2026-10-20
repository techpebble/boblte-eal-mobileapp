import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/loginController.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:eal_scanner/screens/dashboardScreen.dart';
import 'package:eal_scanner/screens/login.dart';
import 'package:eal_scanner/services/authService.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.lazyPut(() => DispatchController(), fenix: true);
  Get.lazyPut(() => Issuancecontroller(), fenix: true);
  Get.lazyPut(() => UsageController(), fenix: true);
  Get.lazyPut(() => LoginController(), fenix: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'EAL App',
      theme: ThemeData(primarySwatch: Colors.grey),
      home: AuthService.isLoggedIn()
          ? const DashboardScreen()
          : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
