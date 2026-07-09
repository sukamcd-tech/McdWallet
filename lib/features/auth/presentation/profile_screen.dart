import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/auth_provider.dart';
import 'settings_screen.dart';
import 'widgets/feedback_sheet.dart';
import '../../../core/utils/haptics.dart';
import 'upgrade_screen.dart';

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

  String _formatExpiryDateText(DateTime? date) {
    if (date == null) return '-';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

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

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (profile.isPro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: AppColors.premiumGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                      const SizedBox(height: 4),

                      Text(
                        '@${profile.username}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

                      /*
                      // Promo Banner untuk Upgrade ke Pro / Perpanjang
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: () {
                          AppHaptics.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface, // Putih terang
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary, // Charcoal
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  profile.isPro ? LucideIcons.shieldCheck : LucideIcons.sparkles, 
                                  color: Colors.white, 
                                  size: 14
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.isPro ? 'Keanggotaan Pro Aktif' : 'Upgrade ke McdWallet Pro',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary, // Charcoal
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      profile.isPro
                                          ? 'Masa aktif sampai: ${_formatExpiryDateText(profile.subscriptionExpiresAt)} (Klik untuk Perpanjang)'
                                          : 'Buka fitur kolaborasi & pembukuan usaha.',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary, // Abu-abu gelap
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(LucideIcons.chevronRight, color: AppColors.textPrimary, size: 16), // Charcoal
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                      */

                      const SizedBox(height: 24),

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
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: AppColors.border, height: 1, thickness: 0.5),
                            ),
                            _buildInfoRow(
                              LucideIcons.award,
                              'TIPE AKUN',
                              profile.isPro ? 'Bisnis (Aktif)' : 'Personal',
                              /*
                              onTap: () {
                                AppHaptics.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                                );
                              },
                              */
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
                              onTap: () {
                                _showAppUpdate(context, ref);
                              },
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

  void _showAppUpdate(BuildContext context, WidgetRef ref) {
    AppHaptics.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AppUpdateBottomSheet(),
    );
  }
}

// ========================================================
// APP UPDATE CHECKER BOTTOM SHEET
// ========================================================
class _AppUpdateBottomSheet extends ConsumerStatefulWidget {
  const _AppUpdateBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<_AppUpdateBottomSheet> createState() => _AppUpdateBottomSheetState();
}

class _AppUpdateBottomSheetState extends ConsumerState<_AppUpdateBottomSheet> {
  String _status = 'checking'; // 'checking', 'available', 'upToDate', 'error'
  String _latestVersion = '';
  String _currentVersion = '';
  String _downloadUrl = '';
  String _releaseNotes = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final current = ref.read(appVersionProvider).value ?? '1.0.0';
      _currentVersion = current;

      final response = await Supabase.instance.client
          .from('app_releases')
          .select()
          .eq('app_name', 'McdWallet')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final latestVersion = response['version'] as String;
        final changelogList = response['changelog'] as List?;
        
        String releaseNotesText = '';
        if (changelogList != null && changelogList.isNotEmpty) {
          releaseNotesText = changelogList.map((item) {
            if (item is Map) {
              final text = item['text'] ?? '';
              final type = item['type'] ?? 'new';
              if (text.startsWith('#') || text.startsWith('*') || text.startsWith('-')) {
                return text;
              }
              if (type == 'fix') {
                return '* **[Perbaikan]** $text';
              } else if (type == 'improve') {
                return '* **[Peningkatan]** $text';
              } else {
                return '* $text';
              }
            }
            final strText = item.toString();
            if (strText.startsWith('#') || strText.startsWith('*') || strText.startsWith('-')) {
              return strText;
            }
            return '* $strText';
          }).join('\n');
        }

        _latestVersion = latestVersion;
        _downloadUrl = 'https://www.sukamcd.tech/projects/mcdwallet/download';
        _releaseNotes = releaseNotesText;

        if (_isVersionGreater(_latestVersion, _currentVersion)) {
          if (mounted) {
            setState(() {
              _status = 'available';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _status = 'upToDate';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _status = 'upToDate';
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking app update: $e');
      if (mounted) {
        setState(() {
          _status = 'error';
          _errorMessage = 'Gagal menghubungi server database pembaruan.';
        });
      }
    }
  }

  bool _isVersionGreater(String newVersion, String currentVersion) {
    final cleanNew = newVersion.split('+')[0].split('-')[0].toLowerCase().replaceAll('v', '').trim();
    final cleanCurrent = currentVersion.split('+')[0].split('-')[0].toLowerCase().replaceAll('v', '').trim();

    List<int> newParts = cleanNew.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    int maxLength = newParts.length > currentParts.length ? newParts.length : currentParts.length;
    for (int i = 0; i < maxLength; i++) {
      int newPart = i < newParts.length ? newParts[i] : 0;
      int currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (newPart > currentPart) return true;
      if (newPart < currentPart) return false;
    }
    return false;
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
        border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
      ),
      padding: const EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 20.0,
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
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case 'checking':
        return Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              'Memeriksa Pembaruan...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Menghubungkan ke server untuk memverifikasi versi terbaru...',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms);

      case 'available':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Versi Baru Tersedia!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versi terbaru $_latestVersion siap diunduh (versi saat ini: $_currentVersion).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (_releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catatan Rilis:',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      MarkdownBody(
                        data: _releaseNotes,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                          listBullet: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
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
                    onPressed: () async {
                      Navigator.pop(context);
                      final uri = Uri.parse(_downloadUrl);
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          final fallbackUri = Uri.parse('https://www.sukamcd.tech/projects/mcdwallet/download');
                          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                        }
                      } catch (_) {
                        final fallbackUri = Uri.parse('https://www.sukamcd.tech/projects/mcdwallet/download');
                        await launchUrl(fallbackUri, mode: LaunchMode.platformDefault);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(LucideIcons.download, size: 16),
                        SizedBox(width: 8),
                        Text('Unduh', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);

      case 'upToDate':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle, color: AppColors.success, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aplikasi Sudah Terupdate',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda sudah menggunakan versi terbaru ($_currentVersion).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'OK',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms);

      case 'error':
      default:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.alertTriangle, color: AppColors.danger, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Gagal Memeriksa Pembaruan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Terjadi kesalahan saat menghubungi server.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
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
                    onPressed: () async {
                      Navigator.pop(context);
                      final uri = Uri.parse('https://www.sukamcd.tech/projects/mcdwallet/download');
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {
                        await launchUrl(uri, mode: LaunchMode.platformDefault);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Kunjungi Unduhan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 250.ms);
    }
  }
}
