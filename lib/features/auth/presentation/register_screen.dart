import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingGoogle = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim().toLowerCase(),
        fullName: _fullNameController.text.trim(),
      );

      if (mounted) {
        final hasSession = response.session != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasSession 
              ? 'Registrasi sukses! Selamat datang.' 
              : 'Registrasi sukses! Silakan masuk dengan akun Anda.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        if (!hasSession) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registrasi gagal: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _handleGoogleRegister() async {
    setState(() {
      _isLoadingGoogle = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registrasi Google berhasil! Selamat datang.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context); // Kembali ke login screen (atau authState otomatis mengarahkan ke home)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal registrasi Google: ${e.toString().replaceAll('Exception:', '')}',
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Buat Akun'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // ── Header ──
              const Text(
                'Mulai Perjalanan\nFinansialmu',
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
                'Isi formulir untuk mendaftarkan akun baru',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 36),
              
              // ── Form ──
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _fullNameController,
                      label: 'Nama Lengkap',
                      hintText: 'Masukkan nama lengkap Anda',
                      prefixIcon: LucideIcons.user,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama lengkap tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),

                    CustomTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hintText: 'Masukkan nama pengguna Anda',
                      prefixIcon: LucideIcons.atSign,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username tidak boleh kosong';
                        }
                        if (value.trim().contains(' ')) {
                          return 'Username tidak boleh mengandung spasi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),

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
                    const SizedBox(height: 22),

                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'Masukkan kata sandi Anda (minimal 6 karakter)',
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
                    const SizedBox(height: 22),

                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Konfirmasi Password',
                      hintText: 'Konfirmasi kata sandi Anda',
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
                      text: 'Daftar',
                      isLoading: _isLoading,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: (_isLoading || _isLoadingGoogle) ? null : _handleGoogleRegister,
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
                                  'Daftar dengan Google',
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
                  .fadeIn(delay: 200.ms, duration: 500.ms)
                  .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),

              const SizedBox(height: 32),

              // ── Login Link ──
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun?  ',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Masuk',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: 20),
            ],
          ),
         ),
        ),
      ),
    );
  }
}
