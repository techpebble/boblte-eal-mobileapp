import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/screens/login.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/widgets/ui/app_shell.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;

  /// Surfaced inline on the sign-in screen. The old build raised a
  /// `CupertinoAlertDialog`, which had to be dismissed before the field in
  /// question could be corrected.
  final message = ''.obs;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    message.value = '';

    if (!AuthService.validateCredentials(email, password, message)) {
      return;
    }

    isLoading.value = true;
    final success = await AuthService.login(email, password, message);
    isLoading.value = false;

    if (success) {
      message.value = '';
      passwordController.clear();
      Get.offAll(() => const AppShell()); // clears back stack
    }
  }

  /// Clears the session and returns to sign-in.
  Future<void> logout() async {
    await AuthService.clearSession();
    emailController.clear();
    passwordController.clear();
    message.value = '';
    Get.offAll(() => const LoginScreen());
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
