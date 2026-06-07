import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      // Kirim email dengan skema deep link mcdwallet://reset
      await authService.sendPasswordResetEmail(
        _emailController.text.trim(),
        'mcdwallet://reset',
      );

      setState(() {
        _isSuccess = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim email: ${e.toString().replaceAll('Exception:', '')}',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lupa Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: _isSuccess
                ? _buildSuccessState()
                : _buildRequestForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Atur Ulang\nKata Sandi Anda',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
        const SizedBox(height: 8),
        const Text(
          'Masukkan alamat email yang terdaftar. Kami akan mengirimkan instruksi untuk mengatur ulang kata sandi Anda.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
        const SizedBox(height: 36),
        Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'Masukkan alamat email Anda',
                prefixIcon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Kirim Link Pemulihan',
                isLoading: _isLoading,
                onPressed: _handleResetPassword,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.1, end: 0, duration: 500.ms),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.mailCheck,
              color: AppColors.success,
              size: 56,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          const Text(
            'Email Terkirim!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Kami telah mengirimkan tautan pemulihan kata sandi ke alamat email '),
                TextSpan(
                  text: _emailController.text.trim(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: '. Silakan periksa kotak masuk atau folder spam Anda.'),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
          const SizedBox(height: 48),
          CustomButton(
            text: 'Kembali ke Login',
            onPressed: () => Navigator.pop(context),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
        ],
      ),
    );
  }
}
