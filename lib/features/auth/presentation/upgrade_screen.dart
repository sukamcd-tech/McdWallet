import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/haptics.dart';
import 'checkout_screen.dart';
import '../providers/auth_provider.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  String _selectedPlan = 'monthly'; // 'monthly' atau 'yearly'

  String _formatExpiryDate(DateTime? date) {
    if (date == null) return '-';
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _showCancelSubscriptionDialog() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CancelSubscriptionSheet(),
    );

    if (confirmed == true) {
      if (mounted) {
        setState(() {});
      }
      try {
        await ref.read(profileProvider.notifier).updateProfile(
          subscriptionTier: 'free',
          subscriptionStatus: 'inactive',
          subscriptionExpiresAt: null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Langganan berhasil dibatalkan. Akun Anda kembali ke Personal.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membatalkan langganan: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final bool isPro = profile?.isPro ?? false;

    final double price = _selectedPlan == 'monthly' ? 19000 : 149000;
    final String priceLabel = _selectedPlan == 'monthly' ? 'Rp 19.000 / bulan' : 'Rp 149.000 / tahun';
    final String discountLabel = _selectedPlan == 'yearly' ? 'Hemat ~35%' : '';

    return Scaffold(
      backgroundColor: AppColors.background, // Off-white
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'McdWallet Pro',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── TOP HEADER (Premium Badge - Charcoal) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary, // Charcoal
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      color: Colors.white,
                      size: 36,
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text(
                    isPro ? 'Perpanjang Bisnis' : 'Upgrade ke Bisnis',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPro
                        ? 'Langganan Anda aktif saat ini. Anda dapat memperpanjang masa aktif untuk menghindari gangguan akses.'
                        : 'Buka fitur premium kolaborasi dan pembukuan profesional untuk bisnis/usaha kecil Anda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (isPro && profile?.subscriptionExpiresAt != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        border: Border.all(color: AppColors.border, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Status Aktif Sampai: ${_formatExpiryDate(profile!.subscriptionExpiresAt)}',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── PLAN TOGGLE ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.lightImpact();
                        setState(() => _selectedPlan = 'monthly');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPlan == 'monthly' ? AppColors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedPlan == 'monthly'
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Bulanan',
                            style: TextStyle(
                              color: _selectedPlan == 'monthly' ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.lightImpact();
                        setState(() => _selectedPlan = 'yearly');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPlan == 'yearly' ? AppColors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedPlan == 'yearly'
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Tahunan',
                                style: TextStyle(
                                  color: _selectedPlan == 'yearly' ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '-35%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── DETAILS OF FEATURES ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FITUR PREMIUM BISNIS',
                    style: TextStyle(
                      color: AppColors.textPrimary, // Charcoal
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    LucideIcons.users,
                    'Dompet Bersama (Collaboration)',
                    'Kelola & lacak pengeluaran bersama keluarga, pasangan, atau partner bisnis secara real-time.',
                  ),
                  _buildFeatureItem(
                    LucideIcons.tags,
                    'Pemisahan Transaksi Bisnis',
                    'Tag transaksi sebagai "Bisnis" atau "Personal" untuk menganalisis pembukuan secara mandiri.',
                  ),
                  _buildFeatureItem(
                    LucideIcons.fileSpreadsheet,
                    'Laporan Akuntansi Profesional',
                    'Ekspor laporan Laba Rugi berformat PDF eksklusif dan ekspor Buku Besar ke berkas Excel.',
                  ),
                  _buildFeatureItem(
                    LucideIcons.globe,
                    'Dompet Multi-Mata Uang (Valas)',
                    'Simpan saldo dalam USD, SGD, JPY, dll., dengan kurs nilai tukar valas yang ter-update otomatis.',
                  ),
                  _buildFeatureItem(
                    LucideIcons.receipt,
                    'Invoice & Resi Digital',
                    'Buat invoice professional untuk klien dan kirim tanda terima pembayaran langsung dari aplikasi.',
                  ),
                  _buildFeatureItem(
                    LucideIcons.brainCircuit,
                    'Analis Keuangan AI Bisnis',
                    'Asisten AI (McdAI) beralih menjadi analis bisnis yang memproyeksikan arus kas bulanan Anda.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── UPGRADE ACTION CARD ──
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPlan == 'monthly' ? 'PRO BULANAN' : 'PRO TAHUNAN',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            priceLabel,
                            style: const TextStyle(
                              color: AppColors.textPrimary, // Charcoal
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      if (discountLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            discountLabel,
                            style: const TextStyle(
                              color: Color(0xFF34C759),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: isPro ? 'Perpanjang Sekarang' : 'Upgrade Sekarang',
                    color: AppColors.primary, // Charcoal
                    textColor: Colors.white,
                    onPressed: () {
                      AppHaptics.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            amount: price,
                            planName: _selectedPlan == 'monthly' ? 'Monthly Pro' : 'Yearly Pro',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPro
                        ? 'Masa aktif baru akan ditambahkan ke sisa hari paket aktif Anda.'
                        : 'Batalkan kapan saja. Pembayaran aman melalui Xendit.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isPro) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _showCancelSubscriptionDialog,
                icon: const Icon(Icons.cancel, color: AppColors.expense, size: 16),
                label: const Text(
                  'Batalkan Langganan Pro',
                  style: TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 18), // Charcoal Icon
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelSubscriptionSheet extends StatefulWidget {
  const _CancelSubscriptionSheet({Key? key}) : super(key: key);

  @override
  State<_CancelSubscriptionSheet> createState() => _CancelSubscriptionSheetState();
}

class _CancelSubscriptionSheetState extends State<_CancelSubscriptionSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 0) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // Toleransi 10 piksel dari batas bawah
      if (currentScroll >= maxScroll - 10) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          const Text(
            'Ketentuan Pembatalan Pro',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: const Text(
                    'KETENTUAN PEMBATALAN LANGGANAN BISNIS\n\n'
                    'Sebelum melanjutkan pembatalan, mohon membaca ketentuan di bawah ini dengan saksama:\n\n'
                    '1. Konsekuensi Downgrade Akun\n'
                    'Dengan membatalkan langganan McdWallet Bisnis, akun Anda akan segera diturunkan ke status Personal.\n\n'
                    '2. Kehilangan Akses Fitur Premium\n'
                    'Anda akan segera kehilangan akses penuh ke fitur-fitur berikut:\n'
                    '- Kolaborasi Dompet Bersama (Shared Wallet): Seluruh dompet bersama yang Anda buat atau ikuti akan dinonaktifkan.\n'
                    '- Pemisahan Transaksi Bisnis: Semua tag bisnis pada transaksi Anda akan disembunyikan/dinonaktifkan.\n'
                    '- Ekspor Laporan Profesional: Anda tidak lagi memiliki hak akses untuk mengekspor laporan keuangan dalam format PDF eksklusif maupun Excel Ledger.\n'
                    '- Multi-Mata Uang (Valas): Saldo non-IDR Anda tidak akan disinkronisasikan lagi dengan kurs nilai tukar valas real-time.\n'
                    '- Asisten Keuangan AI (McdAI): Asisten kecerdasan buatan Anda akan kehilangan kemampuan analisis arus kas usaha.\n\n'
                    '3. Kebijakan Refund / Pengembalian Dana\n'
                    'Pembatalan ini bersifat final. Dana yang telah ditransfer tidak dapat dikembalikan baik sebagian maupun seluruhnya.\n\n'
                    '4. Masa Aktif yang Tersisa\n'
                    'Pembatalan ini akan langsung mencabut status PRO Anda secara instan untuk kebutuhan simulasi sistem. Sisa hari paket aktif Anda akan hangus.\n\n'
                    'Dengan menggulirkan layar hingga ke bagian paling bawah dan mencentang kotak persetujuan di bawah, Anda menyatakan memahami dan menerima seluruh konsekuensi dari pembatalan ini secara penuh.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _isAccepted,
                  activeColor: AppColors.primary,
                  onChanged: _hasScrolledToBottom
                      ? (value) {
                          setState(() {
                            _isAccepted = value ?? false;
                          });
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _hasScrolledToBottom
                      ? () {
                          setState(() {
                            _isAccepted = !_isAccepted;
                          });
                        }
                      : null,
                  child: Text(
                    'Saya memahami dan menyetujui seluruh ketentuan pembatalan di atas.',
                    style: TextStyle(
                      color: _hasScrolledToBottom
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!_hasScrolledToBottom) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(LucideIcons.arrowDown, color: AppColors.textMuted, size: 12),
                SizedBox(width: 4),
                Text(
                  'Gulir ke bawah untuk membaca seluruh ketentuan',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          CustomButton(
            text: 'Ya, Batalkan Langganan Pro',
            color: (_hasScrolledToBottom && _isAccepted)
                ? AppColors.expense
                : AppColors.border,
            textColor: (_hasScrolledToBottom && _isAccepted)
                ? Colors.white
                : AppColors.textMuted,
            onPressed: (_hasScrolledToBottom && _isAccepted)
                ? () => Navigator.pop(context, true)
                : null,
          ),
        ],
      ),
    );
  }
}
