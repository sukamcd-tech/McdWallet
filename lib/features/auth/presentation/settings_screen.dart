import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/providers/privacy_provider.dart';
import '../../../core/providers/security_provider.dart';
import '../../../core/providers/budget_settings_provider.dart';
import '../../../core/providers/haptic_provider.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/services/notification_service.dart';
import 'pin_setup_screen.dart';
import '../providers/auth_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _appVersionSettingsProvider = FutureProvider<String>((ref) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'v${packageInfo.version}';
  } catch (_) {
    return 'v1.0.0';
  }
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Cache/Storage variables
  String _cacheSize = 'Menghitung...';
  bool _isClearingCache = false;

  // FCM Diagnostics variables
  bool _isFCMDiagnosing = false;
  bool _fcmDiagnosed = false;
  String _fcmInitStatus = 'Belum diperiksa';
  String _fcmPermissionStatus = 'Belum diperiksa';
  String _fcmToken = '';
  bool _isBudgetAlertExpanded = false;

  @override
  void initState() {
    super.initState();
    _calculateCache();
  }

  Future<void> _calculateCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final size = await _getDirSize(tempDir);
      final sizeMb = size / (1024 * 1024);
      if (mounted) {
        setState(() {
          _cacheSize = '${sizeMb.toStringAsFixed(2)} MB';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSize = '0.00 MB';
        });
      }
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (final file in dir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting directory size: $e');
    }
    return totalSize;
  }

  Future<void> _clearCache() async {
    if (_isClearingCache) return;
    setState(() {
      _isClearingCache = true;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final List<FileSystemEntity> entities = await tempDir.list().toList();
        for (final entity in entities) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            debugPrint('Failed to delete: ${entity.path} ($e)');
          }
        }
      }
      
      // Delay premium experience
      await Future.delayed(const Duration(milliseconds: 1000));
      
      await _calculateCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache aplikasi berhasil dibersihkan!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membersihkan cache: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  Future<void> _runFcmDiagnostics() async {
    if (_isFCMDiagnosing) return;
    setState(() {
      _isFCMDiagnosing = true;
      _fcmDiagnosed = false;
    });

    // Premium scanning animation delay
    await Future.delayed(const Duration(milliseconds: 1200));

    try {
      if (Firebase.apps.isNotEmpty) {
        _fcmInitStatus = 'Terhubung (Firebase Aktif)';
        
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.getNotificationSettings();
        
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          _fcmPermissionStatus = 'Diizinkan (Granted)';
        } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
          _fcmPermissionStatus = 'Sementara (Provisional)';
        } else {
          _fcmPermissionStatus = 'Ditolak (Denied)';
        }

        final token = await messaging.getToken();
        _fcmToken = token ?? 'Tidak dapat mengambil token';

        // Auto trigger push notification as requested!
        await NotificationService().showNotification(
          'Uji Coba Notifikasi FCM',
          'Notifikasi push lokal berhasil terkirim dan diterima di perangkat Anda!',
        );
      } else {
        _fcmInitStatus = 'Firebase Belum Terinisialisasi';
        _fcmPermissionStatus = 'Ditolak / Belum Diaktifkan';
        _fcmToken = '-';
      }
    } catch (e) {
      _fcmInitStatus = 'Gagal: $e';
      _fcmPermissionStatus = 'Tidak Diketahui';
      _fcmToken = '-';
    }

    if (mounted) {
      setState(() {
        _isFCMDiagnosing = false;
        _fcmDiagnosed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideBalance = ref.watch(privacyProvider);
    final securityState = ref.watch(securityProvider);
    final activeThresholds = ref.watch(budgetSettingsProvider);
    final hapticEnabled = ref.watch(hapticProvider);
    final versionAsync = ref.watch(_appVersionSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PRIVASI & TAMPILAN ──
            const Text(
              'PRIVASI & TAMPILAN',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.eyeOff, color: AppColors.textSecondary, size: 16),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Sembunyikan Saldo',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Masking nominal saldo di semua halaman',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: hideBalance,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            ref.read(privacyProvider.notifier).toggleHideBalance();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1, thickness: 0.5),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.smartphone, color: AppColors.textSecondary, size: 16),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Getaran Taktil (Haptic)',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Efek getaran ringan saat menekan tombol & interaksi',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: hapticEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            ref.read(hapticProvider.notifier).toggleHaptic();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.05, end: 0, duration: 350.ms),

            const SizedBox(height: 28),

            // ── KEAMANAN ──
            const Text(
              'KEAMANAN APLIKASI',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Master Switch Keamanan & Privasi
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.shield, color: AppColors.textSecondary, size: 16),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Kunci & Privasi Latar Belakang',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Gunakan PIN & samarkan layar di app switcher',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: securityState.isSecurityEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            AppHaptics.lightImpact();
                            ref.read(securityProvider.notifier).toggleSecurityEnabled(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1, thickness: 0.5),
                  // Opsi Setel/Ubah PIN (Hanya aktif jika Master Switch menyala)
                  Opacity(
                    opacity: securityState.isSecurityEnabled ? 1.0 : 0.4,
                    child: InkWell(
                      onTap: securityState.isSecurityEnabled
                          ? () {
                              AppHaptics.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                              );
                            }
                          : null,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.shieldAlert, color: AppColors.textSecondary, size: 16),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    securityState.hasPin ? 'Ganti PIN Pengaman' : 'Aktifkan PIN Pengaman',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    securityState.hasPin
                                        ? 'Ubah kode PIN pengunci aplikasi Anda'
                                        : 'Amankan data finansial dengan kunci PIN 6-digit',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.05, end: 0, duration: 350.ms),

            const SizedBox(height: 28),

            // ── NOTIFIKASI ALARM ANGGARAN ──
            const Text(
              'NOTIFIKASI ALARM ANGGARAN',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      AppHaptics.lightImpact();
                      setState(() {
                        _isBudgetAlertExpanded = !_isBudgetAlertExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.bellRing, color: AppColors.textSecondary, size: 16),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Peringatan Batas Anggaran',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Picu alarm saat pengeluaran melampaui batas terpilih',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _isBudgetAlertExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_isBudgetAlertExpanded) ...[
                    const Divider(color: AppColors.border, height: 1, thickness: 0.5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [50, 70, 90].map((tVal) {
                          final isSelected = activeThresholds.contains(tVal);
                          return InkWell(
                            onTap: () {
                              AppHaptics.lightImpact();
                              ref.read(budgetSettingsProvider.notifier).toggleThreshold(tVal);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : AppColors.border,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    'Peringatan saat terpakai $tVal%',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 240.ms, duration: 350.ms).slideY(begin: 0.05, end: 0, duration: 350.ms),

            const SizedBox(height: 28),

            // ── DIAGNOSIS SISTEM ──
            const Text(
              'DIAGNOSIS SISTEM',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DIAGNOSIS & TES FCM
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.bell, color: AppColors.textSecondary, size: 16),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Diagnosis FCM & Tes Notifikasi',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tes integrasi FCM & kirim push notifikasi',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isFCMDiagnosing ? null : _runFcmDiagnostics,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isFCMDiagnosing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Uji Coba', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  
                  if (_isFCMDiagnosing) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.border,
                      minHeight: 2,
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1, thickness: 0.5),
                  const SizedBox(height: 16),

                  // 2. BERSIHKAN CACHE APLIKASI
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.hardDrive, color: AppColors.textSecondary, size: 16),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bersihkan Cache',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Penyimpanan sementara: $_cacheSize',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isClearingCache ? null : _clearCache,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger.withOpacity(0.1),
                          foregroundColor: AppColors.danger,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isClearingCache
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: AppColors.danger,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Hapus Cache', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 350.ms).slideY(begin: 0.05, end: 0, duration: 350.ms),

            const SizedBox(height: 28),

            // ── ZONA BAHAYA ──
            const Text(
              'ZONA BAHAYA',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
            const SizedBox(height: 8),
            AppCard(
              child: InkWell(
                onTap: () => _showDeleteAccountBottomSheet(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.userX, color: AppColors.danger, size: 16),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Hapus Akun Permanen',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hapus akun Anda dan seluruh data keuangan secara permanen',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.danger),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 350.ms).slideY(begin: 0.05, end: 0, duration: 350.ms),

            const SizedBox(height: 36),
            
            // Footer Info
            Center(
              child: Column(
                children: [
                  Icon(LucideIcons.settings, size: 20, color: AppColors.textMuted.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text(
                    versionAsync.maybeWhen(
                      data: (version) => 'McdWallet Settings $version',
                      orElse: () => 'McdWallet Settings v1.0.0',
                    ),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticReportItem({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> metrics,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...metrics.map((m) {
          final isSuccess = m['success'] as bool;
          final VoidCallback? onActionTap = m['action'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSuccess ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                  size: 14,
                  color: isSuccess ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, fontFamily: 'Outfit'),
                      children: [
                        TextSpan(
                          text: '${m['label']}: ',
                          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: m['value'].toString(),
                          style: TextStyle(
                            color: isSuccess ? AppColors.textPrimary : AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onActionTap != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onActionTap,
                    child: const Icon(LucideIcons.copy, size: 12, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showDeleteAccountBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isChecked = false; // Declared outside StatefulBuilder builder to persist state!
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: 36.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 24),
                  
                  // Warning Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.alertTriangle,
                          color: AppColors.danger,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Hapus Akun Permanen',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Warning Details
                  const Text(
                    'Anda akan menghapus akun McdWallet secara permanen. Tindakan ini memiliki konsekuensi sebagai berikut:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildWarningBullet('Semua data mutasi pengeluaran, pemasukan, dan transfer Anda akan terhapus selamanya.'),
                  _buildWarningBullet('Seluruh daftar dompet/wallet dan batas anggaran bulanan akan dihancurkan.'),
                  _buildWarningBullet('Tindakan ini bersifat final dan data yang terhapus tidak dapat dipulihkan dengan cara apa pun.'),
                  
                  const SizedBox(height: 24),

                  // Recommendation banner (Keluar/Logout instead)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Rekomendasi Kami: Keluar Saja',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Jika Anda hanya ingin keluar sementara dan mengamankan data finansial Anda agar tetap dapat diakses di lain waktu, kami sangat menyarankan untuk Keluar (Logout) saja dibanding menghapus akun.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close delete account warnings bottomsheet
                              _showLogoutBottomSheet(context); // Show logout confirmation bottomsheet!
                            },
                            icon: const Icon(LucideIcons.logOut, size: 14),
                            label: const Text(
                              'Keluar Akun (Logout) Sekarang',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Checkbox Confirmation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: AppColors.danger,
                          onChanged: (val) {
                            setModalState(() {
                              isChecked = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Saya menyatakan memahami konsekuensi di atas dan setuju untuk menghapus akun secara permanen.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Delete Permanently Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isChecked
                          ? () async {
                              Navigator.pop(context); // Close bottomsheet
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Akun Anda sedang dihapus secara permanen...'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                              await ref.read(authServiceProvider).deleteAccount();
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(
                          color: isChecked ? AppColors.danger : AppColors.border,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Hapus Akun Permanen',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isChecked ? AppColors.danger : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: 36.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.logOut, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                'Konfirmasi Keluar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Apakah Anda yakin ingin keluar dari akun Anda?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close bottomsheet
                        ref.read(authServiceProvider).signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expense,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWarningBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.dot, color: AppColors.danger, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
