import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/haptics.dart';
import '../providers/auth_provider.dart';
import '../data/xendit_service.dart';
import 'upgrade_success_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final double amount;
  final String planName;

  const CheckoutScreen({
    Key? key,
    required this.amount,
    required this.planName,
  }) : super(key: key);

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedMethod = ''; // 'qris' atau 'va_bca', 'va_mandiri', etc.
  bool _isLoading = false;
  
  XenditQrisResponse? _qrisResponse;
  XenditVaResponse? _vaResponse;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Jalankan timer pengecekan status secara real-time setiap 3 detik
    _startPaymentCheckTimer();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startPaymentCheckTimer() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final profile = ref.read(profileProvider).value;
      if (profile != null) {
        // Cek database Supabase secara real-time apakah sudah di-update menjadi pro
        await ref.read(profileProvider.notifier).loadProfile(profile.id);
        final updatedProfile = ref.read(profileProvider).value;
        
        if (updatedProfile != null && updatedProfile.isPro) {
          _statusTimer?.cancel();
          if (mounted) {
            _navigateToSuccess();
          }
        }
      }
    });
  }

  void _navigateToSuccess() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeSuccessScreen()),
      (route) => route.isFirst,
    );
  }

  // 1. MEMBUAT TRANSAKSI QRIS
  Future<void> _initiateQris() async {
    setState(() {
      _isLoading = true;
      _selectedMethod = 'qris';
      _vaResponse = null;
    });

    try {
      final xendit = ref.read(xenditServiceProvider);
      final extId = 'mcd_sub_${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await xendit.createQrisPayment(
        amount: widget.amount,
        externalId: extId,
      );

      if (mounted) {
        setState(() {
          _qrisResponse = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses QRIS: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // 2. MEMBUAT TRANSAKSI VIRTUAL ACCOUNT
  Future<void> _initiateVa(String bankCode) async {
    setState(() {
      _isLoading = true;
      _selectedMethod = 'va_$bankCode';
      _qrisResponse = null;
    });

    try {
      final xendit = ref.read(xenditServiceProvider);
      final profile = ref.read(profileProvider).value;
      final extId = 'mcd_sub_va_${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await xendit.createVaPayment(
        bankCode: bankCode,
        amount: widget.amount,
        externalId: extId,
        customerName: profile?.fullName ?? 'User',
      );

      if (mounted) {
        setState(() {
          _vaResponse = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat Virtual Account: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // 3. SIMULASI SUKSES PEMBAYARAN (SANDBOX)
  Future<void> _simulatePaymentSuccess() async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;

    setState(() => _isLoading = true);
    AppHaptics.mediumImpact();

    try {
      final durationDays = widget.planName.toLowerCase().contains('yearly') ? 365 : 30;
      final currentExpiry = profile.subscriptionExpiresAt;
      final DateTime newExpiry;

      if (profile.isPro && currentExpiry != null && currentExpiry.isAfter(DateTime.now())) {
        newExpiry = currentExpiry.add(Duration(days: durationDays));
      } else {
        newExpiry = DateTime.now().add(Duration(days: durationDays));
      }

      // Perbarui database secara langsung ke status PRO aktif untuk simulasi sandbox
      await ref.read(profileProvider.notifier).updateProfile(
        subscriptionTier: 'pro',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: newExpiry,
      );
      
      if (mounted) {
        _statusTimer?.cancel();
        _navigateToSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simulasi gagal: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.read(xenditServiceProvider).hasApiKey;

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
          'Pembayaran Pro',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── RINGKASAN ORDER ──
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.planName.toUpperCase(),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'McdWallet Pro',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    'Rp ${widget.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── PILIHAN METODE PEMBAYARAN ──
            const Text(
              'PILIH METODE PEMBAYARAN NATIVE',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Tombol QRIS
                Expanded(
                  child: _buildMethodButton(
                    id: 'qris',
                    icon: LucideIcons.qrCode,
                    label: 'QRIS / E-Wallet',
                    onTap: _initiateQris,
                  ),
                ),
                const SizedBox(width: 12),
                // Tombol VA
                Expanded(
                  child: _buildMethodButton(
                    id: 'va',
                    icon: LucideIcons.landmark,
                    label: 'Virtual Account',
                    onTap: () => _showBankSelectionDialog(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── AREA DETAIL PEMBAYARAN (NATIVE VIEW) ──
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_qrisResponse != null)
              _buildQrisPaymentView(_qrisResponse!)
            else if (_vaResponse != null)
              _buildVaPaymentView(_vaResponse!)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: const [
                      Icon(LucideIcons.wallet, color: AppColors.textMuted, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Pilih metode pembayaran di atas untuk memuat invoice',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            // ── INFO SANDBOX / SIMULASI PEMBAYARAN (Hanya muncul jika metode pembayaran sudah dipilih) ──
            if (_selectedMethod.isNotEmpty) ...[
              const SizedBox(height: 24),
              if (!hasKey) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD48A0F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD48A0F).withOpacity(0.2), width: 0.5),
                  ),
                  child: Row(
                    children: const [
                      Icon(LucideIcons.helpCircle, color: Color(0xFFD48A0F), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Anda berada di Mode Sandbox. Transaksi ini bersifat simulasi dan gratis.',
                          style: TextStyle(color: Color(0xFFD48A0F), fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tombol Utama Simulasi Sukses Bayar
                CustomButton(
                  text: 'Simulasi Sukses Bayar (Sandbox)',
                  color: const Color(0xFF34C759),
                  textColor: Colors.white,
                  icon: LucideIcons.checkCircle2,
                  onPressed: _simulatePaymentSuccess,
                ),
              ] else ...[
                CustomButton(
                  text: 'Simulasi Sukses Bayar (Developer Test)',
                  color: const Color(0xFF34C759).withOpacity(0.2),
                  textColor: const Color(0xFF34C759),
                  icon: LucideIcons.checkCircle2,
                  onPressed: _simulatePaymentSuccess,
                ),
              ],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Widget tombol metode pembayaran
  Widget _buildMethodButton({
    required String id,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectedMethod.startsWith(id);
    return GestureDetector(
      onTap: () {
        AppHaptics.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textPrimary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBankLogoAsset(String code) {
    switch (code.toUpperCase()) {
      case 'BCA':
        return 'assets/images/bca.png';
      case 'MANDIRI':
        return 'assets/images/mandiri.png';
      case 'BRI':
        return 'assets/images/bri.png';
      case 'BNI':
        return 'assets/images/bni.png';
      default:
        return '';
    }
  }

  Widget _buildBankLogoWidget(String code, {double size = 40}) {
    final String assetPath = _getBankLogoAsset(code);
    final Color fallbackBg;
    final Color fallbackTextColor;
    final String fallbackText;

    switch (code.toUpperCase()) {
      case 'BCA':
        fallbackBg = const Color(0xFF005E9F);
        fallbackTextColor = Colors.white;
        fallbackText = 'BCA';
        break;
      case 'MANDIRI':
        fallbackBg = const Color(0xFF003D79);
        fallbackTextColor = const Color(0xFFF2A900);
        fallbackText = 'Mandiri';
        break;
      case 'BRI':
        fallbackBg = const Color(0xFF00529C);
        fallbackTextColor = Colors.white;
        fallbackText = 'BRI';
        break;
      case 'BNI':
        fallbackBg = const Color(0xFFF15A24);
        fallbackTextColor = Colors.white;
        fallbackText = 'BNI';
        break;
      default:
        fallbackBg = AppColors.primary.withOpacity(0.1);
        fallbackTextColor = AppColors.primary;
        fallbackText = code;
    }

    return Container(
      width: size * 1.5,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: assetPath.isNotEmpty
          ? Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: fallbackBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    fallbackText,
                    style: TextStyle(
                      color: fallbackTextColor,
                      fontSize: size * 0.25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: fallbackBg,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                fallbackText,
                style: TextStyle(
                  color: fallbackTextColor,
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  // Dialog pemilihan Bank untuk Virtual Account
  void _showBankSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
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
                'Pilih Bank Pembayaran',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildBankOption('MANDIRI', 'Bank Mandiri'),
              _buildBankOption('BCA', 'Bank BCA'),
              _buildBankOption('BRI', 'Bank BRI'),
              _buildBankOption('BNI', 'Bank BNI'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBankOption(String code, String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _buildBankLogoWidget(code, size: 36),
        title: Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textSecondary, size: 18),
        onTap: () {
          AppHaptics.lightImpact();
          Navigator.pop(context);
          _initiateVa(code);
        },
      ),
    );
  }

  // Render Tampilan Pembayaran QRIS
  Widget _buildQrisPaymentView(XenditQrisResponse qris) {
    final formattedExpiry = _formatExpirationDate(qris.expirationDate);

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'METODE PEMBAYARAN',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Text(
                'QRIS DYNAMIC',
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 12),

          // Expiry Time Banner (Soft red/amber warning container)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD1CF), width: 1),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.clock, color: Color(0xFFD32F2F), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELESAIKAN PEMBAYARAN SEBELUM',
                        style: TextStyle(color: Color(0xFFB71C1C), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedExpiry,
                        style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Gambar QR Code Native
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Image.network(
              qris.qrImageUrl,
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 220,
                height: 220,
                color: Colors.grey[200],
                child: const Center(child: Text('Gagal memuat QR', style: TextStyle(color: Colors.black))),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
          const SizedBox(height: 16),
          const Text(
            'Mendukung: GoPay, OVO, Dana, LinkAja, ShopeePay & Mobile Banking',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          // Tombol Simpan QR Code ke Galeri
          OutlinedButton.icon(
            onPressed: () async {
              AppHaptics.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mengunduh QR Code...'),
                  duration: Duration(milliseconds: 800),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 1000));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('QR Code berhasil disimpan ke Galeri!'),
                    backgroundColor: Color(0xFF34C759),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(LucideIcons.download, size: 16, color: AppColors.textPrimary),
            label: const Text(
              'Simpan QR ke Galeri',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(LucideIcons.info, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Screenshot halaman ini lalu unggah kode QR di aplikasi e-wallet Anda untuk membayar.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatExpirationDate(DateTime dateTime) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    
    final dayName = days[dateTime.weekday % 7];
    final day = dateTime.day;
    final monthName = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$dayName, $day $monthName $year - $hour:$minute WIB';
  }

  Widget _buildDetailRow(String label, String value, {bool isBoldAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isBoldAmount ? AppColors.primary : AppColors.textPrimary,
              fontSize: isBoldAmount ? 15 : 12,
              fontWeight: isBoldAmount ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Render Tampilan Pembayaran Virtual Account
  Widget _buildVaPaymentView(XenditVaResponse va) {
    final formattedExpiry = _formatExpirationDate(va.expirationDate);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VIRTUAL ACCOUNT',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bank ${va.bankCode}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildBankLogoWidget(va.bankCode, size: 32),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),

          // Expiry Time Banner (Soft red/amber warning container)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD1CF), width: 1),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.clock, color: Color(0xFFD32F2F), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELESAIKAN PEMBAYARAN SEBELUM',
                        style: TextStyle(color: Color(0xFFB71C1C), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedExpiry,
                        style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('NOMOR VIRTUAL ACCOUNT', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SelectableText(
                  va.accountNumber,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: va.accountNumber));
                    AppHaptics.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nomor Virtual Account berhasil disalin!'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Color(0xFF34C759),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(LucideIcons.copy, color: AppColors.primary, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Salin',
                          style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('RINCIAN TAGIHAN', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDetailRow('Nama Penerima', va.accountName),
          const SizedBox(height: 10),
          _buildDetailRow(
            'Total Pembayaran',
            'Rp ${va.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
            isBoldAmount: true,
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider, thickness: 0.5),

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              iconColor: AppColors.textSecondary,
              collapsedIconColor: AppColors.textSecondary,
              title: const Text(
                'Lihat Instruksi Pembayaran',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              children: [
                const SizedBox(height: 8),
                Text(
                  '1. Buka aplikasi M-Banking atau kunjungi ATM bank Anda.\n'
                  '2. Pilih menu Transfer -> Transfer ke Virtual Account.\n'
                  '3. Masukkan nomor VA di atas.\n'
                  '4. Pastikan nominal transfer sama persis dengan rincian di atas.\n'
                  '5. Selesaikan transaksi. Aplikasi akan aktif otomatis begitu dana diterima.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}
