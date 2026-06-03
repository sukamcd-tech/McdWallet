import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/wallets_screen.dart';
import '../../transactions/presentation/transaction_input_screen.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/providers/privacy_provider.dart';
import 'widgets/cashflow_line_chart.dart';
import 'widgets/expense_pie_chart.dart';
import 'widgets/export_sheet.dart';
import '../../forex/presentation/forex_dashboard_widget.dart';
import '../../forex/providers/forex_provider.dart';
import '../../ai_advisor/presentation/ai_advisor_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedPeriod = 'month';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 1. Cek Shared Preferences untuk versi terakhir yang dilihat
      final prefs = await SharedPreferences.getInstance();
      final lastSeenVersion = prefs.getString('last_seen_version');

      // Ambil rilisan terbaru berdasarkan tanggal dibuat (created_at) paling baru
      final response = await Supabase.instance.client
          .from('app_releases')
          .select()
          .eq('app_name', 'McdWallet')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final latestVersion = response['version'] as String;
        final forceUpdate = response['force_update'] as bool? ?? false;
        final changelogList = response['changelog'] as List?;
        final releaseDate = response['release_date'] as String?;

        if (_isVersionGreater(latestVersion, currentVersion)) {
          if (!mounted) return;
          _showUpdateBottomSheet(
            context: context,
            latestVersion: latestVersion,
            forceUpdate: forceUpdate,
            releaseDate: releaseDate,
            changelog: changelogList,
          );
          return; // Hentikan di sini jika ada update
        }
      }

      // 2. Jika tidak ada update, cek apakah user baru saja mengupdate aplikasi
      if (lastSeenVersion != null && _isVersionGreater(currentVersion, lastSeenVersion)) {
        // Ambil data rilis versi sekarang dari database untuk menampilkan changelog
        final currentReleaseResponse = await Supabase.instance.client
            .from('app_releases')
            .select()
            .eq('app_name', 'McdWallet')
            .eq('version', currentVersion)
            .maybeSingle();

        if (currentReleaseResponse != null) {
          final changelogList = currentReleaseResponse['changelog'] as List?;
          final releaseDate = currentReleaseResponse['release_date'] as String?;

          if (!mounted) return;
          _showWhatNewBottomSheet(
            context: context,
            version: currentVersion,
            releaseDate: releaseDate,
            changelog: changelogList,
          );
        }

        // Simpan versi sekarang sebagai versi terakhir yang dilihat
        await prefs.setString('last_seen_version', currentVersion);
      } else if (lastSeenVersion == null) {
        // Simpan versi sekarang jika baru pertama kali menjalankan check versi di instalasi ini
        await prefs.setString('last_seen_version', currentVersion);
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  bool _isVersionGreater(String newVersion, String currentVersion) {
    // Bersihkan build number (+1) atau pre-release suffix (-beta) jika ada
    final cleanNew = newVersion.split('+')[0].split('-')[0];
    final cleanCurrent = currentVersion.split('+')[0].split('-')[0];

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

  void _showWhatNewBottomSheet({
    required BuildContext context,
    required String version,
    String? releaseDate,
    List? changelog,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Berhasil Diperbarui!',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Selamat datang di versi v$version${releaseDate != null ? ' ($releaseDate)' : ''}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (changelog != null && changelog.isNotEmpty) ...[
                  const Text(
                    'Daftar Perubahan:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: MarkdownBody(
                        data: changelog.map((item) {
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
                        }).join('\n'),
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          h1: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                          h2: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                          h3: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                          h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
                          h3Padding: const EdgeInsets.only(top: 6, bottom: 2),
                          listBullet: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Mulai Gunakan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpdateBottomSheet({
    required BuildContext context,
    required String latestVersion,
    required bool forceUpdate,
    String? releaseDate,
    List? changelog,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: !forceUpdate,
      enableDrag: !forceUpdate,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PopScope(
          canPop: !forceUpdate,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!forceUpdate)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: forceUpdate 
                              ? AppColors.expense.withOpacity(0.12)
                              : AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          LucideIcons.arrowUpCircle,
                          color: forceUpdate ? AppColors.expense : AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              forceUpdate ? 'Pembaruan Wajib!' : 'Pembaruan Tersedia',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Versi Terbaru: v$latestVersion${releaseDate != null ? ' ($releaseDate)' : ''}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (changelog != null && changelog.isNotEmpty) ...[
                    const Text(
                      'Yang Baru:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: MarkdownBody(
                          data: changelog.map((item) {
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
                          }).join('\n'),
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            h1: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            h2: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            h3: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            listBullet: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Row(
                    children: [
                      if (!forceUpdate) ...[
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: const Text(
                              'Tutup',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _redirectToDownloadPage(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: forceUpdate ? AppColors.expense : AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Update Sekarang',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _redirectToDownloadPage() async {
    Uri url;
    if (kDebugMode) {
      url = Uri.parse('https:www.sukamcd.tech/projects/mcdwallet/download');
    } else {
      url = Uri.parse('https:www.sukamcd.tech/projects/mcdwallet/download');
    }
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final prodUrl = Uri.parse('https:www.sukamcd.tech/projects/mcdwallet/download');
        if (await canLaunchUrl(prodUrl)) {
          await launchUrl(prodUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showExportSheet(BuildContext context, dynamic transactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportSheet(transactions: transactions),
    );
  }

  List<TransactionModel> _getTransactionsInPeriod(List<TransactionModel> txs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedPeriod == 'week') {
      final limitDate = today.subtract(const Duration(days: 7));
      return txs.where((tx) => tx.date.isAfter(limitDate)).toList();
    } else if (_selectedPeriod == 'month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      return txs
          .where((tx) =>
              tx.date.isAfter(startOfMonth) ||
              tx.date.isAtSameMomentAs(startOfMonth))
          .toList();
    }
    return txs;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final walletsAsync = ref.watch(walletsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: SafeArea(
            child: _buildHeader(profileAsync, transactionsAsync),
          ),
        ),
      ),
      // ─── FAB McdAI ───
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const AiAdvisorScreen(),
            ),
          );
        },
        child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 22),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          final user = ref.read(authStateProvider).value;
          if (user != null) {
            ref.read(profileProvider.notifier).loadProfile(user.id);
            ref.read(walletsProvider.notifier).loadWallets(user.id);
            final wId = ref.read(walletFilterProvider);
            final cId = ref.read(categoryFilterProvider);
            final type = ref.read(typeFilterProvider);
            ref.read(transactionsProvider.notifier).loadTransactions(
                  user.id,
                  walletId: wId,
                  categoryId: cId,
                  type: type,
                );
            ref.read(forexRatesProvider.notifier).refreshRates();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Balance ───
              _buildBalanceSection(walletsAsync, transactionsAsync),
              const SizedBox(height: 24),

              // ─── Quick Actions ───
              _buildQuickActions(),
              const SizedBox(height: 16),



              // ─── Forex Monitoring ───
              const ForexDashboardWidget(),
              const SizedBox(height: 36),

              // ─── Analytics ───
              _buildAnalyticsSection(transactionsAsync),
              const SizedBox(height: 36),

              // ─── Recent Transactions ───
              _buildRecentTransactions(transactionsAsync),

              // Spacer agar konten tidak tertutup FAB
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════

  Widget _buildHeader(
    AsyncValue profileAsync,
    AsyncValue transactionsAsync,
  ) {
    return profileAsync.when(
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox(height: 40),
      data: (profile) {
        final initials = (profile?.fullName ?? 'U')
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join();

        return Row(
          children: [
            // App Logo
            Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                profile?.fullName ?? 'User',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Wallet button
            _iconButton(
              icon: LucideIcons.wallet,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletsScreen()),
              ),
            ),
            const SizedBox(width: 8),

            // Export button — in header, not buried at bottom
            transactionsAsync.when(
              loading: () => _iconButton(icon: LucideIcons.download, onTap: () {}),
              error: (_, __) =>
                  _iconButton(icon: LucideIcons.download, onTap: () {}),
              data: (txs) => _iconButton(
                icon: LucideIcons.download,
                onTap: () => _showExportSheet(context, txs),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 350.ms);
      },
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 16),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  BALANCE
  // ════════════════════════════════════════════════

  Widget _buildBalanceSection(
    AsyncValue walletsAsync,
    AsyncValue transactionsAsync,
  ) {
    final hideBalance = ref.watch(privacyProvider);
    final totalBalanceAsync = ref.watch(totalBalanceProvider);

    return walletsAsync.when(
      loading: () => const SizedBox(height: 110),
      error: (_, __) => const SizedBox.shrink(),
      data: (wallets) {
        final totalBalance = totalBalanceAsync.value ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Total saldo',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ref.read(privacyProvider.notifier).toggleHideBalance(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hideBalance ? '••••••' : Formatters.formatCurrency(totalBalance),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: hideBalance ? 32 : 40,
                fontWeight: FontWeight.w800,
                letterSpacing: hideBalance ? 2.0 : -1.8,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 10),

            // Net flow badge
            transactionsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (txs) {
                final filtered = _getTransactionsInPeriod(txs);
                final totalIn = filtered
                    .where((t) => t.type == 'income')
                    .fold(0.0, (s, t) => s + t.amount);
                final totalOut = filtered.fold(0.0, (s, t) {
                  if (t.type == 'expense') {
                    return s + t.amount;
                  } else if (t.type == 'transfer' && t.adminFee != null) {
                    return s + t.adminFee!;
                  }
                  return s;
                });
                final net = totalIn - totalOut;
                final isPositive = net >= 0;
                final periodLabel = _selectedPeriod == 'week'
                    ? '7 hari ini'
                    : _selectedPeriod == 'month'
                        ? 'bulan ini'
                        : 'semua waktu';

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isPositive
                                ? AppColors.primary
                                : AppColors.expense)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? LucideIcons.trendingUp
                                : LucideIcons.trendingDown,
                            size: 12,
                            color: isPositive
                                ? AppColors.primary
                                : AppColors.expense,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hideBalance ? '${isPositive ? '+' : ''}••••••' : '${isPositive ? '+' : ''}${Formatters.formatCurrency(net)}',
                            style: TextStyle(
                              color: isPositive
                                  ? AppColors.primary
                                  : AppColors.expense,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Wallet chips
            if (wallets.isNotEmpty)
              SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wallets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final w = wallets[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.border, width: 0.5),
                      ),
                      child: Text(
                        hideBalance ? '${w.name}  ••••••' : '${w.name}  ${Formatters.formatCurrencyWithCode(w.balance, w.currencyCode)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ).animate().fadeIn(delay: 100.ms, duration: 350.ms);
      },
    );
  }

  // ════════════════════════════════════════════════
  //  QUICK ACTIONS
  // ════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: LucideIcons.arrowDownLeft,
            label: 'Pengeluaran',
            accentColor: AppColors.expense,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const TransactionInputScreen(initialType: 'expense'),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            icon: LucideIcons.arrowUpRight,
            label: 'Pemasukan',
            accentColor: AppColors.income,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const TransactionInputScreen(initialType: 'income'),
                ),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accentColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  ANALYTICS
  // ════════════════════════════════════════════════

  Widget _buildAnalyticsSection(AsyncValue transactionsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row + segmented period control
        Row(
          children: [
            const Text(
              'Analitik',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _periodChip('week', '7H'),
                  _periodChip('month', '1B'),
                  _periodChip('all', 'All'),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(delay: 240.ms, duration: 350.ms),
        const SizedBox(height: 16),

        // Content
        transactionsAsync.when(
          loading: () => ShimmerSkeleton.card(
            height: 120,
            borderRadius: 14,
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (txs) {
            final filtered = _getTransactionsInPeriod(txs);
            final totalIn = filtered
                .where((t) => t.type == 'income')
                .fold(0.0, (s, t) => s + t.amount);
            final totalOut = filtered.fold(0.0, (s, t) {
              if (t.type == 'expense') {
                return s + t.amount;
              } else if (t.type == 'transfer' && t.adminFee != null) {
                return s + t.adminFee!;
              }
              return s;
            });
            final totalFlow = totalIn + totalOut;
            final incomeRatio =
                totalFlow > 0 ? totalIn / totalFlow : 0.5;

            return Column(
              children: [
                // Cashflow summary card
                _cashflowCard(totalIn, totalOut, incomeRatio)
                    .animate()
                    .fadeIn(delay: 290.ms, duration: 350.ms),

                if (filtered.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CashflowLineChart(
                    transactions: filtered,
                    period: _selectedPeriod,
                  ).animate().fadeIn(delay: 340.ms, duration: 400.ms),
                  const SizedBox(height: 12),
                  ExpensePieChart(transactions: filtered)
                      .animate()
                      .fadeIn(delay: 380.ms, duration: 400.ms),
                ] else ...[
                  const SizedBox(height: 12),
                  _emptyChart()
                      .animate()
                      .fadeIn(delay: 340.ms, duration: 350.ms),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _cashflowCard(
    double totalIn,
    double totalOut,
    double incomeRatio,
  ) {
    final hideBalance = ref.watch(privacyProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Income
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.income,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Pemasukan',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hideBalance ? '••••••' : Formatters.formatCurrency(totalIn),
                      style: const TextStyle(
                        color: AppColors.income,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 0.5,
                height: 34,
                color: AppColors.border,
              ),
              // Expense
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Pengeluaran',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.expense,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hideBalance ? '••••••' : Formatters.formatCurrency(totalOut),
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Income vs expense ratio bar
          LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final clampedRatio = incomeRatio.clamp(0.02, 0.98);
              return ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 4,
                  width: totalW,
                  child: Row(
                    children: [
                      // Income portion
                      Container(
                        width: totalW * clampedRatio,
                        color: AppColors.income,
                      ),
                      // Gap
                      Container(width: 2, color: AppColors.background),
                      // Expense portion
                      Expanded(
                        child: Container(color: AppColors.expense),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyChart() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              LucideIcons.barChart2,
              size: 32,
              color: AppColors.textMuted.withOpacity(0.22),
            ),
            const SizedBox(height: 10),
            const Text(
              'Belum ada data di periode ini',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.primary
                : AppColors.textMuted,
            fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  RECENT TRANSACTIONS
  // ════════════════════════════════════════════════

  Widget _buildRecentTransactions(AsyncValue transactionsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transaksi Terakhir',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () =>
                  ref.read(navigationProvider.notifier).setTab(1),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 430.ms, duration: 350.ms),
        const SizedBox(height: 14),

        transactionsAsync.when(
          loading: () => Column(
            children: List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  ShimmerSkeleton.circle(size: 38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerSkeleton(width: 100, height: 12, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(width: 60, height: 8, borderRadius: 4),
                      ],
                    ),
                  ),
                  const ShimmerSkeleton(width: 60, height: 12, borderRadius: 4),
                ],
              ),
            )),
          ),
          error: (err, _) =>
              Text('Error: $err',
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 13)),
          data: (txs) {
            if (txs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.receipt,
                          size: 32,
                          color:
                              AppColors.textMuted.withOpacity(0.22)),
                      const SizedBox(height: 10),
                      const Text(
                        'Belum ada transaksi',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            final displayTxs = txs.take(5).toList();

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.border, width: 0.5),
              ),
              clipBehavior: Clip.hardEdge,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayTxs.length,
                separatorBuilder: (_, __) => const Divider(
                  color: AppColors.border,
                  height: 0.5,
                  thickness: 0.5,
                  indent: 0,
                ),
                itemBuilder: (context, index) =>
                    _transactionItem(displayTxs[index]),
              ),
            ).animate().fadeIn(delay: 480.ms, duration: 380.ms);
          },
        ),
      ],
    );
  }

  Widget _transactionItem(TransactionModel tx) {
    final isExpense = tx.type == 'expense';
    final isTransfer = tx.type == 'transfer';

    Color txColor = AppColors.income;
    if (isExpense) txColor = AppColors.expense;
    if (isTransfer) txColor = AppColors.transfer;

    final amountPrefix = isExpense ? '−' : (isTransfer ? '' : '+');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left accent stripe
          Container(
            width: 3,
            color: txColor.withOpacity(0.6),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isTransfer
                              ? 'Transfer'
                              : (tx.category?.name ?? 'Lainnya'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx.description != null &&
                                  tx.description!.isNotEmpty
                              ? tx.description!
                              : isTransfer
                                  ? '${tx.wallet?.name} → ${tx.toWallet?.name}'
                                  : (tx.wallet?.name ?? ''),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isTransfer && tx.adminFee != null && tx.adminFee! > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Biaya Admin: ${Formatters.formatCurrencyWithCode(tx.adminFee!, tx.wallet?.currencyCode ?? 'IDR')}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$amountPrefix${Formatters.formatCurrencyWithCode(tx.amount, tx.wallet?.currencyCode ?? 'IDR')}',
                        style: TextStyle(
                          color: isTransfer
                              ? AppColors.textPrimary
                              : txColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatDateShort(tx.date),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
