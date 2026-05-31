import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../providers/auth_provider.dart';

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedType = 'saran'; // 'bug' atau 'saran'
  String _selectedPriority = 'normal'; // 'rendah', 'normal', 'tinggi'
  bool _isLoading = false;
  String? _errorLogContent;
  String _appVersion = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _prefillUserEmail();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _prefillUserEmail() {
    // Ambil email dari pengguna aktif jika ada
    final user = ref.read(authStateProvider).value;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    } catch (_) {}
  }

  Future<String?> _loadLastLinesOfLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/errors.log');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        if (lines.length > 50) {
          return lines.sublist(lines.length - 50).join('\n');
        }
        return lines.join('\n');
      }
    } catch (_) {}
    return null;
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      AppHaptics.lightImpact();

      // Membaca log error jika tipenya adalah bug
      String? errorLog;
      if (_selectedType == 'bug') {
        errorLog = await _loadLastLinesOfLog();
      }

      final supabase = ref.read(supabaseClientProvider);
      
      // Mengumpulkan informasi sistem operasi
      final deviceInfo = {
        'os': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'model': Platform.localHostname,
      };

      await supabase.from('feedbacks').insert({
        'user_email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'type': _selectedType,
        'priority': _selectedPriority,
        'description': _descriptionController.text.trim(),
        'device_info': deviceInfo,
        'app_version': _appVersion,
        'error_log': errorLog,
        'status': 'open',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _selectedType == 'bug' ? LucideIcons.bug : LucideIcons.lightbulb,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedType == 'bug'
                        ? 'Laporan bug berhasil dikirim. Terima kasih!'
                        : 'Saran Anda berhasil dikirim. Terima kasih atas masukannya!',
                    style: const TextStyle(fontFamily: 'Outfit'),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim laporan: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32.0,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: const [
                  Icon(LucideIcons.messageSquarePlus, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Kirim Bug & Saran',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Masukan Anda sangat berharga bagi kami untuk terus menyempurnakan McdWallet.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Tipe Laporan (Bug vs Saran)
              const Text(
                'TIPE LAPORAN',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeChip('saran', 'Saran Fitur'),
                  const SizedBox(width: 12),
                  _buildTypeChip('bug', 'Bug / Error'),
                ],
              ),
              const SizedBox(height: 20),

              // Email Pelapor
              const Text(
                'EMAIL',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.5,
                child: TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Tidak ada akun yang login',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.normal),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Deskripsi Laporan
              const Text(
                'DESKRIPSI LAPORAN',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Deskripsi wajib diisi';
                  }
                  if (val.trim().length < 10) {
                    return 'Deskripsi terlalu singkat (minimal 10 karakter)';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: _selectedType == 'bug'
                      ? 'Jelaskan kapan error terjadi dan apa yang Anda lakukan sebelum error muncul...'
                      : 'Tuliskan usulan fitur baru atau penyempurnaan yang Anda harapkan...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.normal, height: 1.4),
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border, width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Note about log attachment if bug is selected
              if (_selectedType == 'bug')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withOpacity(0.15), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shieldAlert, size: 14, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sistem secara otomatis akan melampirkan berkas log error (${_appVersion}) terbaru dari perangkat Anda untuk mempermudah perbaikan.',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms),

              const SizedBox(height: 28),

              // Submit Button
              CustomButton(
                text: 'Kirim Laporan',
                isLoading: _isLoading,
                onPressed: _submitFeedback,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppHaptics.lightImpact();
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
