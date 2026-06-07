import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? authError;
  const LoginScreen({Key? key, this.authError}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingGoogle = false;

  @override
  void initState() {
    super.initState();
    if (widget.authError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        String message = widget.authError!;
        if (message.contains('Email link is invalid') || message.contains('otp_expired')) {
          message = 'Tautan reset email sudah kedaluwarsa atau telah digunakan. Silakan minta tautan baru.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login berhasil! Selamat datang kembali.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login gagal: ${e.toString().replaceAll('Exception:', '')}',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoadingGoogle = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login Google berhasil! Selamat datang.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal login Google: ${e.toString().replaceAll('Exception:', '')}',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // ── App Logo ──
                Image.asset(
                  'assets/images/logo.png',
                  width: 110,
                  fit: BoxFit.contain,
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: 12),

                // ── Title ──
                const Text(
                      'Masuk ke Akun',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: 8),

                const Text(
                  'Kelola keuangan anda secara cerdas',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 28),

                // ── Login Form ──
                Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hintText: 'Masukkan kata sandi Anda',
                            prefixIcon: LucideIcons.lock,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              if (value.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Lupa Password?',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          CustomButton(
                            text: 'Masuk',
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.2))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'atau',
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.2))),
                            ],
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton(
                            onPressed: (_isLoading || _isLoadingGoogle) ? null : _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(color: AppColors.textMuted.withOpacity(0.3), width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.surface,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _isLoadingGoogle
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/google.png',
                                        width: 18,
                                        height: 18,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Masuk dengan Google',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 500.ms,
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: 24),

                // ── Register Link ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun?  ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Daftar',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                const SizedBox(height: 12),
              ],
            ),         // Column
          ),           // Padding
        ),             // SingleChildScrollView
      ),               // SafeArea
    );                 // Scaffold
  }
}