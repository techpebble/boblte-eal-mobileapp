import 'package:eal_scanner/screens/login.dart';
import 'package:flutter/cupertino.dart';
import 'package:eal_scanner/screens/dashboardScreen.dart';
import 'package:get/get.dart';
import 'package:eal_scanner/services/authService.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final message = ''.obs;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!AuthService.validateCredentials(email, password, message)) {
      _showMessage('Error', message.value);
      return;
    }

    isLoading.value = true;

    final success = await AuthService.login(email, password, message);

    isLoading.value = false;

    if (!success) {
      _showMessage('Error', message.value);
    } else {
      Get.offAll(() => const DashboardScreen()); // clears back stack
    }
  }

  /// Call this to perform logout and reset the session
  Future<void> logout() async {
    await AuthService.clearSession(); // Clear session, tokens, etc. if implemented
    emailController.clear();
    passwordController.clear();
    Get.offAll(
      () => const LoginScreen(),
    ); // Navigate to login and reset navigation
  }

  void _showMessage(String title, String content) {
    showCupertinoDialog(
      context: Get.context!,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }
}
