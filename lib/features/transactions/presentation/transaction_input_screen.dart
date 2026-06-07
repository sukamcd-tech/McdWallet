import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/transaction_model.dart';
import '../domain/wallet_model.dart';
import '../domain/category_model.dart';
import '../domain/ocr_result_model.dart';
import '../providers/transactions_provider.dart';
import '../../forex/domain/forex_rate_model.dart';
import '../../forex/providers/forex_provider.dart';
import 'widgets/manage_categories_sheet.dart';
import 'widgets/ocr_scanner_sheet.dart';
import '../services/ai_category_service.dart';

class TransactionInputScreen extends ConsumerStatefulWidget {
  final String? initialType; // 'expense', 'income', or 'transfer'
  final TransactionModel? transactionToEdit; // Transaction to edit

  const TransactionInputScreen({
    Key? key,
    this.initialType,
    this.transactionToEdit,
  }) : super(key: key);

  @override
  ConsumerState<TransactionInputScreen> createState() => _TransactionInputScreenState();
}

class _TransactionInputScreenState extends ConsumerState<TransactionInputScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _adminFeeController = TextEditingController();
  
  WalletModel? _selectedWallet;
  WalletModel? _selectedToWallet; // only for transfer
  CategoryModel? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  
  File? _attachmentFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  // AI Categorization States
  Timer? _debounceTimer;
  bool _isAiCategorizing = false;
  bool _isAiCategorized = false;
  final _aiCategoryService = AiCategoryService();

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    
    final tx = widget.transactionToEdit;
    if (tx != null) {
      if (tx.type == 'income') {
        initialIndex = 1;
      } else if (tx.type == 'transfer') {
        initialIndex = 2;
      }
      
      // Pre-fill controllers. Replace the separator with empty space for typing.
      _amountController.text = Formatters.formatCurrency(tx.amount).replaceAll('Rp ', '').trim();
      _descriptionController.text = tx.description ?? '';
      if (tx.type == 'transfer' && tx.adminFee != null && tx.adminFee! > 0) {
        _adminFeeController.text = Formatters.formatCurrency(tx.adminFee!).replaceAll('Rp ', '').trim();
      }
      _selectedDate = tx.date;
    } else {
      if (widget.initialType == 'income') {
        initialIndex = 1;
      } else if (widget.initialType == 'transfer') {
        initialIndex = 2;
      }
    }
    
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(_handleTabChange);
    _descriptionController.addListener(_onDescriptionChanged);
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {
      _selectedCategory = null;
      _adminFeeController.clear();
      _isAiCategorized = false;
    });
  }

  void _onDescriptionChanged() {
    if (_currentType == 'transfer') return;
    
    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) {
      if (_isAiCategorized) {
        setState(() {
          _isAiCategorized = false;
        });
      }
      return;
    }
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _runAiCategorization(desc);
    });
  }

  Future<void> _runAiCategorization(String desc) async {
    if (!mounted) return;
    
    final categories = ref.read(categoriesProvider).value ?? [];
    final activeCategories = categories.where((c) => c.type == _currentType).toList();
    
    if (activeCategories.isEmpty) return;
    
    setState(() {
      _isAiCategorizing = true;
    });
    
    try {
      final predicted = await _aiCategoryService.predictCategory(
        description: desc,
        availableCategories: activeCategories,
        transactionType: _currentType,
      );
      
      if (predicted != null && mounted) {
        setState(() {
          _selectedCategory = predicted;
          _isAiCategorized = true;
        });
      }
    } catch (e) {
      debugPrint('Error running AI categorization: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAiCategorizing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _debounceTimer?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _adminFeeController.dispose();
    super.dispose();
  }

  String get _currentType {
    switch (_tabController.index) {
      case 0:
        return 'expense';
      case 1:
        return 'income';
      case 2:
        return 'transfer';
      default:
        return 'expense';
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _attachmentFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil gambar: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera, color: AppColors.primary),
              title: const Text('Kamera', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: AppColors.primary),
              title: const Text('Galeri', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String _formatCurrencyWithSymbol(double amount, String currencyCode) {
    return Formatters.formatCurrencyWithCode(amount, currencyCode);
  }

  double _getConversionRate(String currencyCode, List<ForexRateModel> rates) {
    if (currencyCode == 'IDR') return 1.0;
    final matched = rates.firstWhere(
      (r) => r.code.toUpperCase() == currencyCode.toUpperCase(),
      orElse: () => const ForexRateModel(
        code: '',
        name: '',
        symbol: '',
        flag: '',
        rate: 0.0,
        previousRate: 0.0,
        trend: ForexTrend.flat,
      ),
    );
    if (matched.rate > 0.0) {
      return matched.rate;
    }
    // Fallbacks
    switch (currencyCode.toUpperCase()) {
      case 'USD': return 16230.0;
      case 'SGD': return 12050.0;
      case 'EUR': return 17620.0;
      case 'JPY': return 103.5;
      case 'MYR': return 3450.0;
      case 'GBP': return 20610.0;
      default: return 1.0;
    }
  }

  Future<void> _handleSaveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    if (_selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih dompet terlebih dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final type = _currentType;

    if (type == 'transfer') {
      if (_selectedToWallet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih dompet tujuan transfer.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      if (_selectedWallet!.id == _selectedToWallet!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dompet asal dan tujuan tidak boleh sama.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    } else {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih kategori terlebih dahulu.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    final cleanAmountText = _amountController.text.replaceAll('.', '').replaceAll(',', '.').trim();
    final amount = double.tryParse(cleanAmountText) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal transaksi harus lebih dari 0.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Jika pengeluaran, pastikan dompet asal memiliki saldo yang cukup (peringatan saja)
    if (type == 'expense' && _selectedWallet!.balance < amount) {
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
                'Saldo Kurang?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'Saldo dompet "${_selectedWallet!.name}" saat ini (${_formatCurrencyWithSymbol(_selectedWallet!.balance, _selectedWallet!.currencyCode)}) kurang dari nominal pengeluaran (${_formatCurrencyWithSymbol(amount, _selectedWallet!.currencyCode)}). Lanjutkan transaksi?',
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

    try {
      String? attachmentUrl;
      if (_attachmentFile != null) {
        final service = ref.read(transactionsServiceProvider);
        attachmentUrl = await service.uploadReceipt(user.id, _attachmentFile!.path);
      }

      final adminFee = type == 'transfer'
          ? (double.tryParse(_adminFeeController.text.replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0.0)
          : null;

      final rates = ref.read(forexRatesProvider).value ?? [];
      final currencyCode = _selectedWallet!.currencyCode;
      final rate = _getConversionRate(currencyCode, rates);
      final amountInIdr = currencyCode == 'IDR' ? amount : amount * rate;

      double? targetAmount;
      if (type == 'transfer' && _selectedToWallet != null) {
        if (currencyCode == _selectedToWallet!.currencyCode) {
          targetAmount = amount;
        } else {
          final rateTo = _getConversionRate(_selectedToWallet!.currencyCode, rates);
          if (rateTo > 0.0) {
            targetAmount = amountInIdr / rateTo;
          } else {
            targetAmount = amount;
          }
        }
      }

      final transaction = TransactionModel(
        id: '', // Generated by backend
        userId: user.id,
        walletId: _selectedWallet!.id,
        categoryId: type == 'transfer' ? null : _selectedCategory!.id,
        amount: amount,
        amountInIdr: amountInIdr,
        targetAmount: targetAmount,
        type: type,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        attachmentPath: attachmentUrl ?? widget.transactionToEdit?.attachmentPath,
        toWalletId: type == 'transfer' ? _selectedToWallet!.id : null,
        adminFee: adminFee,
        createdAt: DateTime.now(),
      );

      if (widget.transactionToEdit != null) {
        await ref.read(transactionsProvider.notifier).editTransaction(widget.transactionToEdit!, transaction);
      } else {
        await ref.read(transactionsProvider.notifier).addTransaction(transaction);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transactionToEdit != null
                  ? 'Catatan transaksi berhasil diperbarui!'
                  : type == 'expense'
                      ? 'Catatan pengeluaran berhasil disimpan!'
                      : type == 'income'
                          ? 'Catatan pemasukan berhasil disimpan!'
                          : 'Transfer saldo berhasil dicatat!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: $e'),
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

  void _launchOcrScanner(BuildContext context) {
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OcrScannerSheet(),
    ).then((resultMap) {
      if (resultMap == null) return;

      final OcrResultModel result = resultMap['result'];
      final String imagePath = resultMap['imagePath'];

      final categories = ref.read(categoriesProvider).value ?? [];
      final activeCategories = categories.where((c) => c.type == _currentType).toList();

      setState(() {
        // Set nominal belanja
        if (result.amount > 0) {
          final cleanString = result.amount.toInt().toString();
          final formatted = IndonesianCurrencyInputFormatter().formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: cleanString),
          ).text;
          _amountController.text = formatted;
        }

        // Set deskripsi merchant
        _descriptionController.text = result.merchantName;

        // Set tanggal
        _selectedDate = result.date;

        // Set lampiran foto
        _attachmentFile = File(imagePath);

        // Jika ada rekomendasi kategori, cari yang cocok dan set
        if (result.suggestedCategoryName != null) {
          final suggName = result.suggestedCategoryName!.toLowerCase().trim();
          try {
            // 1. Coba pencocokan persis
            final matchedCategory = activeCategories.firstWhere(
              (c) => c.name.toLowerCase().trim() == suggName,
            );
            _selectedCategory = matchedCategory;
            _isAiCategorized = true;
          } catch (_) {
            try {
              // 2. Coba pencocokan sebagian (fuzzy) jika persis gagal
              final matchedCategory = activeCategories.firstWhere(
                (c) => c.name.toLowerCase().contains(suggName) || suggName.contains(c.name.toLowerCase()),
              );
              _selectedCategory = matchedCategory;
              _isAiCategorized = true;
            } catch (_) {
              // Kategori tidak ditemukan, abaikan
            }
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data struk kasir berhasil diekstraksi ke formulir!'),
          backgroundColor: AppColors.success,
        ),
      );
    });
  }

  void _showManageCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManageCategoriesBottomSheet(initialType: _currentType),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final rates = ref.watch(forexRatesProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.transactionToEdit != null ? 'Ubah Transaksi' : 'Catat Transaksi'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: widget.transactionToEdit != null
            ? null
            : [
                IconButton(
                  icon: const Icon(LucideIcons.scanLine, color: AppColors.primary),
                  onPressed: () => _launchOcrScanner(context),
                  tooltip: 'Pindai Struk Kasir',
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Gagal memuat dompet: $err', style: const TextStyle(color: AppColors.danger))),
        data: (wallets) {
          if (wallets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.wallet, size: 80, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'Anda belum membuat dompet.',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Silakan buat dompet/rekening terlebih dahulu dari Dasbor sebelum menambahkan transaksi.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Buat Dompet Pertama',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          }

          // Pre-select first wallet if none selected
          if (_selectedWallet == null && wallets.isNotEmpty) {
            final tx = widget.transactionToEdit;
            if (tx != null) {
              _selectedWallet = wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => wallets.first);
              if (tx.type == 'transfer' && tx.toWalletId != null) {
                _selectedToWallet = wallets.firstWhere((w) => w.id == tx.toWalletId, orElse: () => wallets.first);
              }
              // Format properly based on currency
              final formatter = NumberFormat.decimalPattern('id_ID');
              _amountController.text = formatter.format(tx.amount);
            } else {
              // Cari dompet IDR pertama sebagai default yang aman
              _selectedWallet = wallets.firstWhere(
                (w) => w.currencyCode == 'IDR',
                orElse: () => wallets.first,
              );
            }
          }

          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, _) => Center(child: Text('Gagal memuat kategori: $err', style: const TextStyle(color: AppColors.danger))),
            data: (categories) {
              final activeCategories = categories.where((c) => c.type == _currentType).toList();
              if (_selectedCategory == null && 
                  widget.transactionToEdit != null && 
                  widget.transactionToEdit!.categoryId != null &&
                  activeCategories.isNotEmpty) {
                _selectedCategory = activeCategories.firstWhere((c) => c.id == widget.transactionToEdit!.categoryId, orElse: () => activeCategories.first);
              }
              if (_selectedCategory != null && !activeCategories.any((c) => c.id == _selectedCategory!.id)) {
                _selectedCategory = null;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TAB SLIDER SELECTOR (Custom Premium Segmented Control)
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedBuilder(
                              animation: _tabController.animation!,
                              builder: (context, child) {
                                final width = constraints.maxWidth;
                                final segmentWidth = width / 3;
                                final double value = _tabController.animation!.value;
                                
                                return Stack(
                                  children: [
                                    // Background Sliding Active Pill
                                    Positioned(
                                      left: value * segmentWidth,
                                      top: 0,
                                      bottom: 0,
                                      width: segmentWidth,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(13),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.12),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // Tab Labels Interaction Layer
                                    Row(
                                      children: [
                                        _buildCustomTabItem(0, 'Pengeluaran'),
                                        _buildCustomTabItem(1, 'Pemasukan'),
                                        _buildCustomTabItem(2, 'Transfer'),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // NOMINAL ENTRY CARD
                      AppCard(
                        borderColor: _currentType == 'expense'
                            ? AppColors.expense.withOpacity(0.3)
                            : _currentType == 'income'
                                ? AppColors.income.withOpacity(0.3)
                                : AppColors.transfer.withOpacity(0.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOMINAL TRANSAKSI',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountController,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                IndonesianCurrencyInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Text(
                                    _selectedWallet != null
                                        ? CurrencyMetadata.getSymbol(_selectedWallet!.currencyCode)
                                        : 'Rp',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted.withOpacity(0.5),
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nominal tidak boleh kosong';
                                }
                                final cleanVal = value.replaceAll('.', '').replaceAll(',', '.').trim();
                                final numVal = double.tryParse(cleanVal);
                                if (numVal == null || numVal <= 0) {
                                  return 'Masukkan nominal angka yang valid (>0)';
                                }
                                return null;
                              },
                            ),
                            if (_selectedWallet != null && _selectedWallet!.currencyCode != 'IDR') ...[
                              const SizedBox(height: 8),
                              AnimatedBuilder(
                                animation: _amountController,
                                builder: (context, _) {
                                  final rate = _getConversionRate(_selectedWallet!.currencyCode, rates);
                                  
                                  final textVal = _amountController.text.replaceAll('.', '').replaceAll(',', '.').trim();
                                  final amountVal = double.tryParse(textVal) ?? 0.0;
                                  final converted = amountVal * rate;
                                  
                                  return Text(
                                    'Setara ${Formatters.formatCurrency(converted)}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // DETAILS FORM
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // DOMPET/WALLET SELECTION
                            Text(
                              _currentType == 'transfer' ? 'DARI DOMPET (ASAL)' : 'PILIH DOMPET',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
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
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: isIdr ? color : AppColors.textMuted.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width - 150,
                                        ),
                                        child: Text(
                                          isIdr
                                              ? '${wallet.name} (${_formatCurrencyWithSymbol(wallet.balance, wallet.currencyCode)})'
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
                            ),
                            const SizedBox(height: 20),

                            // DOMPET TUJUAN (Hanya untuk transfer)
                            if (_currentType == 'transfer') ...[
                              const Text(
                                'KE DOMPET (TUJUAN)',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedToWallet?.id,
                                isExpanded: true,
                                hint: const Text('Pilih Dompet Tujuan', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
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
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isIdr ? color : AppColors.textMuted.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width - 150,
                                          ),
                                          child: Text(
                                            isIdr
                                                ? '${wallet.name} (${_formatCurrencyWithSymbol(wallet.balance, wallet.currencyCode)})'
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
                                      _selectedToWallet = wallet;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 20),

                              // BIAYA ADMIN (Hanya untuk transfer)
                              CustomTextField(
                                controller: _adminFeeController,
                                label: 'BIAYA ADMIN (OPSIONAL)',
                                hintText: 'Masukkan biaya admin...',
                                prefixIcon: LucideIcons.coins,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  IndonesianCurrencyInputFormatter(),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],

                            // KATEGORI (Hanya untuk pemasukan & pengeluaran)
                            if (_currentType != 'transfer') ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'KATEGORI',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showManageCategoriesSheet(context),
                                    icon: const Icon(LucideIcons.settings, size: 12, color: AppColors.textSecondary),
                                    label: const Text('Kelola', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedCategory?.id,
                                isExpanded: true,
                                hint: const Text('Pilih Kategori', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                                dropdownColor: AppColors.surface,
                                icon: const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 18),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: activeCategories.map((cat) {
                                  final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
                                  return DropdownMenuItem<String>(
                                    value: cat.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width - 150,
                                          ),
                                          child: Text(
                                            cat.name,
                                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCategory = activeCategories.firstWhere((c) => c.id == val);
                                    _isAiCategorized = false; // Reset AI status if changed manually
                                  });
                                },
                              ),
                              if (_isAiCategorized) ...[
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(LucideIcons.sparkles, size: 12, color: const Color(0xFF10B981)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Kategori dipilih otomatis oleh AI',
                                      style: TextStyle(
                                        color: const Color(0xFF10B981),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),
                            ],

                            // TANGGAL & WAKTU (PICKER)
                            const Text(
                              'TANGGAL & WAKTU',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(LucideIcons.calendar, size: 18, color: AppColors.primary),
                                        const SizedBox(width: 12),
                                        Text(
                                          Formatters.formatDateTime(_selectedDate),
                                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // CATATAN/KETERANGAN
                            CustomTextField(
                              controller: _descriptionController,
                              label: 'CATATAN (OPSIONAL)',
                              hintText: 'Tulis deskripsi ringkas transaksi di sini...',
                              prefixIcon: LucideIcons.fileText,
                            ),
                            const SizedBox(height: 20),

                            // LAMPIRAN STRUK/NOTA (IMAGE PICKER)
                            const Text(
                              'LAMPIRAN NOTA/STRUK (OPSIONAL)',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            if (_attachmentFile != null) ...[
                              Stack(
                                children: [
                                  Container(
                                    height: 180,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.border.withOpacity(0.3)),
                                      image: DecorationImage(
                                        image: FileImage(_attachmentFile!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: _showImageSourceActionSheet,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                                            child: const Icon(LucideIcons.edit2, color: AppColors.primary, size: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _attachmentFile = null;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                                            child: const Icon(LucideIcons.x, color: AppColors.danger, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              InkWell(
                                onTap: _showImageSourceActionSheet,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: 100,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.01),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border.withOpacity(0.2), style: BorderStyle.values[0]), // dashed is ideal but solid thin works
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.camera, color: AppColors.textMuted.withOpacity(0.5), size: 28),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Ambil Foto / Unggah Struk Belanja',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // SAVE BUTTON
                      CustomButton(
                        text: widget.transactionToEdit != null
                            ? 'Simpan Perubahan'
                            : _currentType == 'expense'
                                ? 'Simpan Pengeluaran'
                                : _currentType == 'income'
                                    ? 'Simpan Pemasukan'
                                    : 'Lakukan Transfer',
                        isLoading: _isSaving,
                        onPressed: _handleSaveTransaction,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomTabItem(int index, String label) {
    final double value = _tabController.animation?.value ?? _tabController.index.toDouble();
    final isSelected = (value - index).abs() < 0.5;
    
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _tabController.animateTo(index);
        },
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
