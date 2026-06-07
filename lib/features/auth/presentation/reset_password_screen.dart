import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      
      // Update password di Supabase
      await authService.updatePassword(_passwordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password berhasil diperbarui! Silakan masuk dengan password baru Anda.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      // Reset status mode pemulihan password
      ref.read(passwordRecoveryModeProvider.notifier).state = false;
      
      // Sign out untuk menghapus sesi pemulihan sementara dan memaksa masuk ulang secara bersih
      await authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal merubah password: ${e.toString().replaceAll('Exception:', '')}',
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
        title: const Text('Reset Password'),
        automaticallyImplyLeading: false, // User tidak boleh kembali sebelum merubah password karena status sesi sedang pemulihan
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Buat Password Baru',
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
                  'Silakan masukkan password baru Anda. Pastikan password baru Anda aman dan mudah diingat.',
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
                        controller: _passwordController,
                        label: 'Password Baru',
                        hintText: 'Masukkan kata sandi baru Anda (minimal 6 karakter)',
                        prefixIcon: LucideIcons.lock,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password baru tidak boleh kosong';
                          }
                          if (value.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      CustomTextField(
                        controller: _confirmPasswordController,
                        label: 'Konfirmasi Password Baru',
                        hintText: 'Konfirmasi kata sandi baru Anda',
                        prefixIcon: LucideIcons.shieldCheck,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Konfirmasi password tidak boleh kosong';
                          }
                          if (value != _passwordController.text) {
                            return 'Password konfirmasi tidak cocok';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 36),
                      CustomButton(
                        text: 'Simpan Password Baru',
                        isLoading: _isLoading,
                        onPressed: _handleUpdatePassword,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () async {
                          // Batal ganti password: reset state dan signout
                          ref.read(passwordRecoveryModeProvider.notifier).state = false;
                          await ref.read(authServiceProvider).signOut();
                        },
                        child: const Text(
                          'Batalkan',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.1, end: 0, duration: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
