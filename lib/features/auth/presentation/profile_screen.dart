import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/auth_provider.dart';
import 'settings_screen.dart';
import 'widgets/feedback_sheet.dart';
import '../../../core/utils/haptics.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'v${packageInfo.version}';
  } catch (_) {
    return 'v1.0.0';
  }
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Pengaturan',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          children: [
            profileAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
                error: (err, _) => Text('Error: $err', style: const TextStyle(color: AppColors.danger)),
                data: (profile) {
                  if (profile == null) return const Text('Profil tidak ditemukan', style: TextStyle(color: AppColors.textSecondary));

                  return Column(
                    children: [
                      // ── App Logo as Profile Avatar ──
                      Image.asset(
                        'assets/images/logo.png',
                        width: 110,
                        height: 80,
                        fit: BoxFit.contain,
                      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 400.ms),

                      const SizedBox(height: 16),

                      Text(
                        profile.fullName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                      const SizedBox(height: 4),

                      Text(
                        '@${profile.username}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

                      const SizedBox(height: 36),

                      // ── Info Card ──
                      AppCard(
                        child: Column(
                          children: [
                            _buildInfoRow(
                              LucideIcons.mail,
                              'EMAIL',
                              ref.watch(authStateProvider).value?.email ?? '',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: AppColors.border, height: 1, thickness: 0.5),
                            ),
                            _buildInfoRow(
                              LucideIcons.coins,
                              'MATA UANG',
                              profile.currency,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: AppColors.border, height: 1, thickness: 0.5),
                            ),
                            _buildInfoRow(
                              LucideIcons.calendar,
                              'TERDAFTAR',
                              '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}',
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),

                      const SizedBox(height: 16),

                      // ── App Info Card ──
                      AppCard(
                        child: Column(
                          children: [
                            _buildInfoRow(
                              LucideIcons.info,
                              'VERSI APLIKASI',
                              versionAsync.maybeWhen(
                                data: (version) => version,
                                orElse: () => 'v1.0.0',
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: AppColors.border, height: 1, thickness: 0.5),
                            ),
                            _buildInfoRow(
                              LucideIcons.messageSquare,
                              'MASUKAN & BUG',
                              'Kirim Bug / Saran',
                              onTap: () {
                                AppHaptics.lightImpact();
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const FeedbackSheet(),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: AppColors.border, height: 1, thickness: 0.5),
                            ),
                            _buildInfoRow(
                              LucideIcons.code2,
                              'TENTANG',
                              'McdWallet',
                              onTap: () async {
                                final uri = Uri.parse('https://github.com/sukamcd-tech/McdWallet');
                                try {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } catch (_) {
                                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                                }
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: AppColors.border, height: 1, thickness: 0.5),
                            ),
                            _buildInfoRow(
                              LucideIcons.shield,
                              'KEBIJAKAN PRIVASI',
                              'Privacy Policy',
                              onTap: () async {
                                final uri = Uri.parse(kDebugMode
                                    ? 'https://www.sukamcd.tech/projects/mcdwallet/privacy'
                                    : 'https://sukamcd.com/projects/mcdwallet/privacy');
                                try {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } catch (_) {
                                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                                }
                              },
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Support Me ──
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'DUKUNG PENGEMBANG',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 300.ms),

              const SizedBox(height: 8),

              AppCard(
                child: Column(
                  children: [
                    // ── Trakteer ──
                    _buildInfoRow(
                      LucideIcons.heart,
                      'TRAKTEER',
                      'Trakteer Aku',
                      iconWidget: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: FaIcon(FontAwesomeIcons.heartCirclePlus, color: AppColors.textSecondary, size: 16),
                        ),
                      ),
                      onTap: () async {
                        final uri = Uri.parse('https://trakteer.id/sukamcd');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          await launchUrl(uri, mode: LaunchMode.platformDefault);
                        }
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: AppColors.border, height: 1, thickness: 0.5),
                    ),
                    // ── Ko-fi ──
                    _buildInfoRow(
                      LucideIcons.coffee,
                      'KO-FI',
                      'Traktir Kopi',
                      iconWidget: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: FaIcon(FontAwesomeIcons.koFi, color: AppColors.textSecondary, size: 16),
                        ),
                      ),
                      onTap: () async {
                        final uri = Uri.parse('https://ko-fi.com/SukaMCD');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          await launchUrl(uri, mode: LaunchMode.platformDefault);
                        }
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),

              const SizedBox(height: 24),

              // ── Sign Out ──
              CustomButton(
                text: 'Keluar',
                color: AppColors.expense,
                icon: LucideIcons.logOut,
                onPressed: () {
                  _showLogoutBottomSheet(context, ref);
                },
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onTap, Widget? iconWidget}) {
    final row = Row(
      children: [
        iconWidget ?? Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: onTap != null ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(LucideIcons.externalLink, size: 14, color: AppColors.primary),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: row,
      );
    }
    return row;
  }

  void _showLogoutBottomSheet(BuildContext context, WidgetRef ref) {
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
}
