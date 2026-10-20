import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/config/api_config.dart';
import 'package:eal_scanner/controllers/loginController.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';

/// Sign-in. Fields carry real labels rather than placeholder-only hints,
/// failures appear inline instead of in a modal dialog, and the footer names
/// the server and build so a field report can be specific.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LoginController _controller = Get.put(LoginController());
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const _BrandBand(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xxl,
                AppSpace.xxl,
                AppSpace.xxl,
                AppSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(() {
                    final message = _controller.message.value;
                    if (message.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xl),
                      child: NoticeBanner(
                        level: NoticeLevel.error,
                        title: 'Could not sign in',
                        message: message,
                      ),
                    );
                  }),

                  const Text('Email or mobile', style: AppText.label),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _controller.emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _controller.message.value = '',
                    decoration: const InputDecoration(
                      hintText: 'you@plant.co',
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                        size: 19,
                        color: AppColors.ink500,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpace.xl),
                  const Text('Password', style: AppText.label),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _controller.passwordController,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => _controller.message.value = '',
                    onSubmitted: (_) => _controller.login(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 19,
                        color: AppColors.ink500,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.ink500,
                        ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: AppSpace.sm),
                  Obx(
                    () => ElevatedButton(
                      onPressed: _controller.isLoading.value
                          ? null
                          : () => _controller.login(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: _controller.isLoading.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                  ),

                  const SizedBox(height: AppSpace.xxl),
                  const _BuildStrip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPassword() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            0,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Forgot password?', style: AppText.title),
              const SizedBox(height: AppSpace.md),
              Text(
                'Accounts are created and reset by the plant administrator — '
                'there is no self-service reset. Ask them to issue a new '
                'password for your email or mobile.',
                style: AppText.bodyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBand extends StatelessWidget {
  const _BrandBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xxl,
            AppSpace.xxl,
            AppSpace.xxl,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  AppBrand.logo,
                  fit: BoxFit.cover,
                  semanticLabel: '${AppBrand.name} logo',
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.qr_code_2_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                AppBrand.name,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.54,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                AppBrand.tagline,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.onNavyMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Names the server being signed in to.
///
/// It says which server, and nothing about the data: a test server may still
/// be pointed at the live database, so promising otherwise would be worse
/// than saying nothing.
class _BuildStrip extends StatelessWidget {
  const _BuildStrip();

  @override
  Widget build(BuildContext context) {
    final live = ApiConfig.isProduction;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      background: live ? AppColors.surface : AppColors.cautionTint,
      borderColor: live ? AppColors.line : AppColors.cautionLine,
      child: Row(
        children: [
          Icon(
            live ? Icons.dns_outlined : Icons.science_outlined,
            size: 18,
            color: live ? AppColors.ink500 : AppColors.caution,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live
                      ? 'Signing in to the live server'
                      : 'Signing in to a test server',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: live ? AppColors.ink900 : AppColors.cautionDeep,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${ApiConfig.label} · build ${AppBrand.version}',
                  style: AppText.mono(size: 11, color: AppColors.ink500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
