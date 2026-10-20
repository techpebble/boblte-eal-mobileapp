import 'package:flutter/material.dart';
import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/controllers/loginController.dart';
import 'package:get/get.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    LoginController loginController = Get.put(LoginController());

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: Get.height,
            width: Get.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      AppBrand.logo,
                      width: 88,
                      height: 88,
                      semanticLabel: '${AppBrand.name} logo',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppBrand.name,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppBrand.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign in to manage your labels',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // Email Input
                  InputBox(
                    hintText: 'Email/Mobile',
                    icon: Icons.email_outlined,
                    controller: loginController.emailController,
                    isPassword: false,
                  ),
                  const SizedBox(height: 20),

                  // Password Input
                  InputBox(
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    controller: loginController.passwordController,
                    isPassword: true,
                  ),
                  const SizedBox(height: 10),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Forgot password action
                      },
                      child: Text(
                        "Forgot Password?",
                        style: const TextStyle(color: AppBrand.navy),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Login Button
                  Obx(() {
                    return loginController.isLoading.value
                        ? const CircularProgressIndicator(color: AppBrand.navy)
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                await loginController.login();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppBrand.navy,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                          );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


Widget InputBox({
  required String hintText,
  required TextEditingController? controller,
  required bool isPassword,
  required IconData icon,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade100,
          spreadRadius: 2,
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppBrand.navy),
        hintText: hintText,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
  );
}
