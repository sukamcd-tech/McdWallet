import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/wallet_model.dart';
import '../providers/transactions_provider.dart';
import '../../../core/providers/privacy_provider.dart';
import '../../forex/domain/forex_rate_model.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  String _formatWalletBalance(WalletModel wallet) {
    final symbol = CurrencyMetadata.getSymbol(wallet.currencyCode);
    final formattedVal = NumberFormat.decimalPattern('id_ID').format(wallet.balance);
    return '$symbol $formattedVal';
  }

  final List<String> _colorOptions = [
    '#10B981', // Emerald Green
    '#8B5CF6', // Violet
    '#3B82F6', // Blue
    '#F59E0B', // Amber
    '#EF4444', // Rose/Red
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#64748B', // Slate Gray
  ];

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'wallet', 'icon': LucideIcons.wallet},
    {'name': 'bank', 'icon': LucideIcons.landmark},
    {'name': 'credit_card', 'icon': LucideIcons.creditCard},
    {'name': 'coins', 'icon': LucideIcons.coins},
    {'name': 'phone', 'icon': LucideIcons.smartphone}, // for e-wallets
    {'name': 'piggy_bank', 'icon': LucideIcons.piggyBank},
  ];

  void _showAddWalletSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddWalletBottomSheet(
        colorOptions: _colorOptions,
        iconOptions: _iconOptions,
      ),
    );
  }

  void _showEditWalletSheet(BuildContext context, WalletModel wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddWalletBottomSheet(
        colorOptions: _colorOptions,
        iconOptions: _iconOptions,
        existingWallet: wallet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);
    final hideBalance = ref.watch(privacyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Dompet'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Text(
            'Gagal memuat dompet: $err',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (wallets) {
          if (wallets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.wallet, size: 60, color: AppColors.textMuted.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada dompet dibuat.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
            itemCount: wallets.length,
            onReorder: (oldIndex, newIndex) {
              ref.read(walletsProvider.notifier).reorderWallets(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              final walletColor = Color(int.parse(wallet.color.replaceAll('#', '0xFF')));
              
              // Find matching icon
              IconData walletIcon = LucideIcons.wallet;
              for (var opt in _iconOptions) {
                if (opt['name'] == wallet.icon) {
                  walletIcon = opt['icon'] as IconData;
                  break;
                }
              }

              return Container(
                key: ValueKey(wallet.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _showEditWalletSheet(context, wallet),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Hamburger Handle
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            child: Icon(
                              LucideIcons.menu,
                              color: AppColors.textMuted.withOpacity(0.5),
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Wallet Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: walletColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(walletIcon, color: walletColor, size: 18),
                        ),
                        const SizedBox(width: 14),
                        
                        // Wallet Name & Balance Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hideBalance ? '••••••' : _formatWalletBalance(wallet),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Right Chevron indicating tap action
                        Icon(
                          LucideIcons.chevronRight,
                          color: AppColors.textMuted.withOpacity(0.4),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddWalletSheet(context);
        },
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }
}

// ========================================================
// BOTTOM SHEET UNTUK PENAMBAHAN DOMPET BARU
// ========================================================
class _AddWalletBottomSheet extends ConsumerStatefulWidget {
  final List<String> colorOptions;
  final List<Map<String, dynamic>> iconOptions;
  final WalletModel? existingWallet;

  const _AddWalletBottomSheet({
    Key? key,
    required this.colorOptions,
    required this.iconOptions,
    this.existingWallet,
  }) : super(key: key);

  @override
  ConsumerState<_AddWalletBottomSheet> createState() => _AddWalletBottomSheetState();
}

class _AddWalletBottomSheetState extends ConsumerState<_AddWalletBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  
  late String _selectedColor;
  late String _selectedIconName;
  String _selectedCurrency = 'IDR';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingWallet != null) {
      _nameController.text = widget.existingWallet!.name;
      _balanceController.text = NumberFormat.decimalPattern('id_ID').format(widget.existingWallet!.balance);
      _selectedColor = widget.existingWallet!.color;
      _selectedIconName = widget.existingWallet!.icon;
      _selectedCurrency = widget.existingWallet!.currencyCode;
    } else {
      _selectedColor = widget.colorOptions.first;
      _selectedIconName = widget.iconOptions.first['name'] as String;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final initialBalance = double.tryParse(_balanceController.text.replaceAll('.', '').trim()) ?? 0.0;

      if (widget.existingWallet != null) {
        final updatedWallet = widget.existingWallet!.copyWith(
          name: _nameController.text.trim(),
          balance: initialBalance,
          color: _selectedColor,
          icon: _selectedIconName,
          currencyCode: _selectedCurrency,
        );

        await ref.read(walletsProvider.notifier).editWallet(widget.existingWallet!.id, updatedWallet);
      } else {
        final newWallet = WalletModel(
          id: '', // Di-generate otomatis oleh Postgres/Supabase
          userId: user.id,
          name: _nameController.text.trim(),
          balance: initialBalance,
          color: _selectedColor,
          icon: _selectedIconName,
          createdAt: DateTime.now(),
          currencyCode: _selectedCurrency,
        );

        await ref.read(walletsProvider.notifier).addWallet(newWallet);
      }
      
      if (mounted) {
        Navigator.pop(context); // Tutup bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingWallet != null ? 'Dompet berhasil diperbarui!' : 'Dompet baru berhasil ditambahkan!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan dompet: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      widget.existingWallet != null ? 'Edit Dompet' : 'Tambah Dompet Baru',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.existingWallet != null)
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, color: AppColors.danger, size: 20),
                        onPressed: () async {
                          final confirm = await showModalBottomSheet<bool>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Container(
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Hapus Dompet?',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Apakah Anda yakin ingin menghapus dompet "${widget.existingWallet!.name}"? Semua transaksi terkait dompet ini akan terhapus.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                  const SizedBox(height: 24),
                                  CustomButton(
                                    text: 'Hapus',
                                    color: AppColors.danger,
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
                          if (confirm == true) {
                            ref.read(walletsProvider.notifier).removeWallet(widget.existingWallet!.id);
                            if (mounted) {
                              Navigator.pop(context); // Tutup bottom sheet edit
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Dompet "${widget.existingWallet!.name}" berhasil dihapus.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // NAMA DOMPET
                CustomTextField(
                  controller: _nameController,
                  label: 'Nama Dompet',
                  hintText: 'Contoh: Bank BCA, Gopay, Tunai',
                  prefixIcon: LucideIcons.tag,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama dompet tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // PILIHAN MATA UANG
                const Text(
                  'Mata Uang Dompet',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCurrency,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      items: ['IDR', 'USD', 'SGD', 'EUR', 'JPY', 'GBP', 'MYR'].map((String value) {
                        final flag = CurrencyMetadata.getFlag(value);
                        final name = CurrencyMetadata.getName(value);
                        final isIdr = value == 'IDR';
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Text(flag, style: TextStyle(fontSize: 18, color: isIdr ? null : AppColors.textMuted.withOpacity(0.5))),
                              const SizedBox(width: 10),
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width - 140,
                                ),
                                child: Text(
                                  isIdr ? '$value - $name' : '$value - $name (Sedang dalam pengembangan)',
                                  style: TextStyle(
                                    color: isIdr ? AppColors.textPrimary : AppColors.textMuted.withOpacity(0.5),
                                    fontSize: 14,
                                    fontWeight: isIdr ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          if (newValue != 'IDR') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fitur Multi-Mata Uang (Valas) sedang dalam pengembangan!'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _selectedCurrency = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // SALDO AWAL
                CustomTextField(
                  controller: _balanceController,
                  label: 'Saldo Awal (Opsional)',
                  hintText: '0',
                  prefixIcon: LucideIcons.coins,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    IndonesianCurrencyInputFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // Opsional
                    }
                    final cleanValue = value.replaceAll('.', '');
                    if (double.tryParse(cleanValue) == null) {
                      return 'Masukkan nominal angka yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // PILIHAN WARNA KUSTOM
                const Text(
                  'Warna Tema Dompet',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.colorOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final hex = widget.colorOptions[index];
                      final isSelected = hex == _selectedColor;
                      final c = Color(int.parse(hex.replaceAll('#', '0xFF')));

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = hex;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected 
                              ? const Icon(LucideIcons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // PILIHAN IKON KUSTOM
                const Text(
                  'Pilih Ikon Dompet',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.iconOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final opt = widget.iconOptions[index];
                      final name = opt['name'] as String;
                      final isSelected = name == _selectedIconName;
                      final iconData = opt['icon'] as IconData;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIconName = name;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.surfaceAlt 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary.withOpacity(0.5) : AppColors.border,
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            iconData, 
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
                
                // TOMBOL SIMPAN
                CustomButton(
                  text: widget.existingWallet != null ? 'Simpan Perubahan' : 'Simpan Dompet',
                  isLoading: _isSaving,
                  onPressed: _handleSaveWallet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
