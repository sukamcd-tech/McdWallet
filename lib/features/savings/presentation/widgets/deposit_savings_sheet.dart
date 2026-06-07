import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../transactions/providers/transactions_provider.dart';
import '../../../transactions/domain/wallet_model.dart';
import '../../domain/savings_goal_model.dart';
import '../../providers/savings_provider.dart';

class DepositSavingsSheet extends ConsumerStatefulWidget {
  final SavingsGoalModel goal;
  final bool isDeposit;

  const DepositSavingsSheet({
    Key? key,
    required this.goal,
    this.isDeposit = true,
  }) : super(key: key);

  @override
  ConsumerState<DepositSavingsSheet> createState() => _DepositSavingsSheetState();
}

class _DepositSavingsSheetState extends ConsumerState<DepositSavingsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  WalletModel? _selectedWallet;
  late bool _isDeposit;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isDeposit = widget.isDeposit;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleAdjustBalance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWallet == null) return;

    final amountStr = _amountController.text.replaceAll('.', '');
    final amount = double.parse(amountStr);

    // Validasi penarikan tidak boleh melebihi saldo tabungan saat ini
    if (!_isDeposit && amount > widget.goal.currentAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dana tidak cukup! Saldo tabungan Anda saat ini adalah ${Formatters.formatCurrency(widget.goal.currentAmount)}.'
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Peringatan jika menabung melebihi saldo dompet asal
    if (_isDeposit && amount > _selectedWallet!.balance) {
      final confirm = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saldo Dompet Kurang?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'Saldo dompet "${_selectedWallet!.name}" saat ini (${Formatters.formatCurrencyWithCode(_selectedWallet!.balance, _selectedWallet!.currencyCode)}) kurang dari nominal yang ingin ditabung (${Formatters.formatCurrency(amount)}). Tetap lanjutkan transaksi?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Lanjutkan',
                color: AppColors.warning,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              CustomButton(
                text: 'Batal',
                isOutlined: true,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await ref.read(savingsProvider.notifier).adjustSavingsBalance(
      goalId: widget.goal.id,
      amount: amount,
      walletId: _selectedWallet!.id,
      isDeposit: _isDeposit,
      note: _noteController.text.trim().isNotEmpty 
          ? _noteController.text.trim() 
          : (_isDeposit ? 'Tabungan: ${widget.goal.name}' : 'Tarik Dana: ${widget.goal.name}'),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        Navigator.pop(context); // Tutup sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isDeposit 
                  ? 'Berhasil menabung ${Formatters.formatCurrency(amount)} ke "${widget.goal.name}"!'
                  : 'Berhasil menarik ${Formatters.formatCurrency(amount)} dari "${widget.goal.name}" ke dompet!'
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui saldo tabungan.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isDeposit ? 'Menabung untuk Impian' : 'Tarik Uang Tabungan',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Target Tabungan: ${widget.goal.name} (${Formatters.formatCurrency(widget.goal.currentAmount)} / ${Formatters.formatCurrency(widget.goal.targetAmount)})',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // SEGMENTED ACTION CHANGER (Menabung / Tarik)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      // OPSI MENABUNG
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isDeposit = true),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _isDeposit ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Menabung',
                              style: TextStyle(
                                color: _isDeposit ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // OPSI TARIK TABUNGAN
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isDeposit = false),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_isDeposit ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Tarik Dana',
                              style: TextStyle(
                                color: !_isDeposit ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // NOMINAL
                CustomTextField(
                  controller: _amountController,
                  label: _isDeposit ? 'NOMINAL DITABUNG' : 'NOMINAL DITARIK',
                  hintText: 'Masukkan nominal, contoh: 250.000',
                  prefixIcon: LucideIcons.coins,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    IndonesianCurrencyInputFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nominal tidak boleh kosong';
                    }
                    final cleanValue = value.replaceAll('.', '');
                    final numVal = double.tryParse(cleanValue);
                    if (numVal == null || numVal <= 0) {
                      return 'Masukkan nominal yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // PILIH DOMPET
                const Text(
                  'PILIH REKENING / DOMPET',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                walletsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (wallets) {
                    if (wallets.isEmpty) {
                      return const Text('Tidak ada dompet tersedia.', style: TextStyle(color: AppColors.danger));
                    }
                    
                    if (_selectedWallet == null && wallets.isNotEmpty) {
                      // Ambil dompet IDR pertama sebagai default yang aman
                      _selectedWallet = wallets.firstWhere(
                        (w) => w.currencyCode == 'IDR',
                        orElse: () => wallets.first,
                      );
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedWallet?.id,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 18),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: wallets.map((wallet) {
                        final color = Color(int.parse(wallet.color.replaceAll('#', '0xFF')));
                        final isIdr = wallet.currencyCode == 'IDR';
                        return DropdownMenuItem<String>(
                          value: wallet.id,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isIdr ? color : AppColors.textMuted.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width - 150,
                                ),
                                child: Text(
                                  isIdr
                                      ? '${wallet.name} (${Formatters.formatCurrencyWithCode(wallet.balance, wallet.currencyCode)})'
                                      : '${wallet.name} (Sedang dalam pengembangan)',
                                  style: TextStyle(
                                    color: isIdr ? AppColors.textPrimary : AppColors.textMuted.withOpacity(0.5),
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final wallet = wallets.firstWhere((w) => w.id == val);
                          if (wallet.currencyCode != 'IDR') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dompet dengan mata uang asing dinonaktifkan sementara (Sedang dalam pengembangan).'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _selectedWallet = wallet;
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // CATATAN
                CustomTextField(
                  controller: _noteController,
                  label: 'CATATAN (OPSIONAL)',
                  hintText: _isDeposit 
                      ? 'Contoh: Sisa uang belanja bulanan'
                      : 'Contoh: Biaya servis laptop darurat',
                  prefixIcon: LucideIcons.fileText,
                ),
                const SizedBox(height: 30),

                // TOMBOL SUBMIT
                CustomButton(
                  text: _isDeposit ? 'Lakukan Menabung' : 'Tarik Uang Sekarang',
                  isLoading: _isSaving,
                  color: _isDeposit ? AppColors.success : AppColors.primary,
                  onPressed: _handleAdjustBalance,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
