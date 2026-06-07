import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/domain/category_model.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../domain/budget_model.dart';
import '../../../core/providers/budget_settings_provider.dart';

class BudgetDetailScreen extends ConsumerWidget {
  final BudgetModel budget;

  const BudgetDetailScreen({Key? key, required this.budget}) : super(key: key);

  IconData _getIconData(String name) {
    switch (name) {
      case 'utensils':
        return LucideIcons.utensils;
      case 'shoppingBag':
        return LucideIcons.shoppingBag;
      case 'car':
        return LucideIcons.car;
      case 'zap':
        return LucideIcons.zap;
      case 'wallet':
        return LucideIcons.wallet;
      case 'activity':
        return LucideIcons.activity;
      case 'graduationCap':
        return LucideIcons.graduationCap;
      case 'gift':
        return LucideIcons.gift;
      case 'tag':
        return LucideIcons.tag;
      default:
        return LucideIcons.tag;
    }
  }

  List<MapEntry<String, List<TransactionModel>>> _groupTransactionsByDate(List<TransactionModel> txs) {
    final Map<String, List<TransactionModel>> groups = {};
    for (var tx in txs) {
      final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(tx.date);
      if (!groups.containsKey(dateStr)) {
        groups[dateStr] = [];
      }
      groups[dateStr]!.add(tx);
    }
    return groups.entries.toList();
  }

  void _showNotificationSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BudgetNotificationSettingsBottomSheet(budgetId: budget.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTransactionsAsync = ref.watch(allTransactionsProvider);
    final thresholds = ref.watch(budgetThresholdsProvider(budget.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Anggaran'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: allTransactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Text(
            'Gagal memuat detail anggaran: $err',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (allTransactions) {
          // 1. FILTER TRANSACTIONS BY DATE RANGE AND CATEGORY (IF CATEGORY-SPECIFIC)
          final periodTransactions = allTransactions.where((tx) {
            final isWithinPeriod = tx.date.isAfter(budget.startDate.subtract(const Duration(seconds: 1))) &&
                tx.date.isBefore(budget.endDate.add(const Duration(days: 1)));
            
            if (!isWithinPeriod) return false;

            if (budget.categoryId != null) {
              return tx.type == 'expense' && tx.categoryId == budget.categoryId;
            } else {
              // Global budget includes all expenses and transfer admin fees
              return tx.type == 'expense' || (tx.type == 'transfer' && tx.adminFee != null && tx.adminFee! > 0);
            }
          }).toList();

          // 2. CALCULATE SPENT AND PROGRESS
          double spentAmount = 0.0;
          for (final tx in periodTransactions) {
            if (tx.type == 'expense') {
              spentAmount += tx.amount;
            } else if (tx.type == 'transfer' && tx.adminFee != null) {
              spentAmount += tx.adminFee!;
            }
          }

          final remainingAmount = budget.amountLimit - spentAmount;
          final percentage = budget.amountLimit > 0 ? spentAmount / budget.amountLimit : 0.0;
          final isExceeded = percentage >= 1.0;

          Color progressColor = AppColors.primary;
          if (percentage >= 0.8 && percentage < 1.0) {
            progressColor = const Color(0xFFF59E0B); // Amber
          } else if (percentage >= 1.0) {
            progressColor = AppColors.expense; // Red
          }

          // 3. GENERATE CATEGORY BREAKDOWN (IF GLOBAL BUDGET)
          final Map<String, _CategoryBreakdownItem> breakdownMap = {};
          if (budget.categoryId == null) {
            for (final tx in periodTransactions) {
              if (tx.type == 'expense') {
                final catId = tx.categoryId ?? 'other';
                final catName = tx.category?.name ?? 'Lainnya';
                final catColor = tx.category?.color ?? '#607D8B';
                final catIcon = tx.category?.icon ?? 'tag';

                if (breakdownMap.containsKey(catId)) {
                  breakdownMap[catId]!.amount += tx.amount;
                } else {
                  breakdownMap[catId] = _CategoryBreakdownItem(
                    name: catName,
                    colorHex: catColor,
                    icon: catIcon,
                    amount: tx.amount,
                  );
                }
              } else if (tx.type == 'transfer' && tx.adminFee != null && tx.adminFee! > 0) {
                const transferId = 'transfer_fee';
                if (breakdownMap.containsKey(transferId)) {
                  breakdownMap[transferId]!.amount += tx.adminFee!;
                } else {
                  breakdownMap[transferId] = _CategoryBreakdownItem(
                    name: 'Biaya Admin Transfer',
                    colorHex: '#607D8B',
                    icon: 'wallet',
                    amount: tx.adminFee!,
                  );
                }
              }
            }
          }

          final sortedBreakdown = breakdownMap.values.toList()
            ..sort((a, b) => b.amount.compareTo(a.amount));

          // 4. GROUP TRANSACTIONS BY DATE
          final groupedTransactions = _groupTransactionsByDate(periodTransactions);

          final isGlobal = budget.categoryId == null;
          final categoryName = isGlobal ? 'Anggaran Global' : (budget.category?.name ?? 'Kategori');
          final categoryColor = isGlobal
              ? AppColors.secondary
              : Color(int.parse((budget.category?.color ?? '#607D8B').replaceAll('#', '0xFF')));

          String periodLabel = 'Bulanan';
          if (budget.period == 'weekly') periodLabel = 'Mingguan';
          if (budget.period == 'yearly') periodLabel = 'Tahunan';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. FINANCIAL SUMMARY CARD
                // ==========================================
                AppCard(
                  borderColor: progressColor.withOpacity(0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: categoryColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    categoryName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              periodLabel,
                              style: TextStyle(color: categoryColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${Formatters.formatDateShort(budget.startDate)} - ${Formatters.formatDateShort(budget.endDate)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TERPAKAI', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.formatCurrency(spentAmount),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('BATAS LIMIT', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.formatCurrency(budget.amountLimit),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: percentage.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}% terpakai',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            isExceeded
                                ? 'Melebihi ${Formatters.formatCurrency(remainingAmount.abs())}'
                                : 'Sisa ${Formatters.formatCurrency(remainingAmount)}',
                            style: TextStyle(
                              color: isExceeded ? AppColors.expense : AppColors.income,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 20),

                // ==========================================
                // 2. WARNING NOTIFICATION SETTINGS ROW
                // ==========================================
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.bellRing, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Peringatan Batas Anggaran',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              thresholds.isEmpty
                                  ? 'Notifikasi Peringatan Dinonaktifkan'
                                  : 'Peringatan aktif pada: ${thresholds.map((e) => '$e%').join(', ')}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showNotificationSettingsSheet(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceAlt,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppColors.border, width: 0.5),
                          ),
                        ),
                        child: const Text(
                          'Atur',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
                const SizedBox(height: 24),

                // ==========================================
                // 3. CATEGORY BREAKDOWN (ONLY FOR GLOBAL BUDGETS)
                // ==========================================
                if (isGlobal) ...[
                  const Text(
                    'Pengeluaran per Kategori',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sortedBreakdown.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: const Text(
                        'Belum ada pengeluaran per kategori.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    )
                  else
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedBreakdown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final item = sortedBreakdown[index];
                          final itemColor = Color(int.parse(item.colorHex.replaceAll('#', '0xFF')));
                          final itemPercentage = spentAmount > 0 ? item.amount / spentAmount : 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: itemColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getIconData(item.icon),
                                          color: itemColor,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        Formatters.formatCurrency(item.amount),
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(itemPercentage * 100).toStringAsFixed(0)}% dari total',
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: itemPercentage.clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: AppColors.surfaceAlt,
                                  valueColor: AlwaysStoppedAnimation<Color>(itemColor),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 24),
                ],

                // ==========================================
                // 4. TRANSACTION HISTORY LIST
                // ==========================================
                const Text(
                  'Catatan Transaksi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                if (groupedTransactions.isEmpty)
                  Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.listX, size: 48, color: AppColors.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          'Tidak ada transaksi di periode ini.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupedTransactions.length,
                    itemBuilder: (context, index) {
                      final entry = groupedTransactions[index];
                      final dateHeader = entry.key;
                      final txs = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 10, left: 4),
                            child: Text(
                              dateHeader.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: txs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, txIndex) {
                              final tx = txs[txIndex];
                              return _buildTransactionCardItem(context, tx);
                            },
                          ),
                        ],
                      );
                    },
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCardItem(BuildContext context, TransactionModel tx) {
    final isExpense = tx.type == 'expense';
    final isTransfer = tx.type == 'transfer';
    final accentColor = isExpense
        ? AppColors.expense
        : isTransfer
            ? AppColors.transfer
            : AppColors.income;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => TransactionDetailsDialog(tx: tx),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.7),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isTransfer
                                    ? 'Transfer'
                                    : (tx.category?.name ?? 'Lainnya'),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tx.description != null && tx.description!.isNotEmpty
                                    ? tx.description!
                                    : isTransfer
                                        ? '${tx.wallet?.name} → ${tx.toWallet?.name}'
                                        : (tx.wallet?.name ?? 'Dompet'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${isExpense ? '−' : ''}${Formatters.formatCurrencyWithCode(tx.amount, tx.wallet?.currencyCode ?? 'IDR')}',
                              style: TextStyle(
                                color: isTransfer ? AppColors.textPrimary : accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            if (isTransfer && tx.adminFee != null && tx.adminFee! > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Fee Admin: ${Formatters.formatCurrency(tx.adminFee!)}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdownItem {
  final String name;
  final String colorHex;
  final String icon;
  double amount;

  _CategoryBreakdownItem({
    required this.name,
    required this.colorHex,
    required this.icon,
    required this.amount,
  });
}

// ========================================================
// BUDGET SPECIFIC NOTIFICATION SETTINGS SHEET
// ========================================================
class _BudgetNotificationSettingsBottomSheet extends ConsumerStatefulWidget {
  final String budgetId;

  const _BudgetNotificationSettingsBottomSheet({Key? key, required this.budgetId}) : super(key: key);

  @override
  ConsumerState<_BudgetNotificationSettingsBottomSheet> createState() => _BudgetNotificationSettingsBottomSheetState();
}

class _BudgetNotificationSettingsBottomSheetState extends ConsumerState<_BudgetNotificationSettingsBottomSheet> {
  bool _useGlobal = true;
  final Set<int> _selectedThresholds = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final notifier = ref.read(budgetThresholdsProvider(widget.budgetId).notifier);
    final isCustomSettings = await notifier.isCustom();
    final currentSet = ref.read(budgetThresholdsProvider(widget.budgetId));

    setState(() {
      _useGlobal = !isCustomSettings;
      _selectedThresholds.addAll(currentSet);
    });
  }

  void _toggleThreshold(int val) {
    setState(() {
      if (_selectedThresholds.contains(val)) {
        _selectedThresholds.remove(val);
      } else {
        _selectedThresholds.add(val);
      }
    });
  }

  Future<void> _saveSettings() async {
    final notifier = ref.read(budgetThresholdsProvider(widget.budgetId).notifier);
    if (_useGlobal) {
      await notifier.resetToGlobal();
    } else {
      await notifier.updateThresholds(_selectedThresholds);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan peringatan anggaran berhasil disimpan!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalThresholds = ref.watch(budgetSettingsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Atur Peringatan Anggaran',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tentukan kapan Anda ingin menerima notifikasi alarm batas anggaran terlampaui.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const Divider(color: AppColors.border, height: 32),

            // Use Global Default Toggle Switch
            SwitchListTile.adaptive(
              title: const Text(
                'Gunakan Pengaturan Global',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Mengikuti pengaturan umum aplikasi (${globalThresholds.map((e) => '$e%').join(', ')})',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              activeColor: AppColors.primary,
              value: _useGlobal,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _useGlobal = val;
                  if (_useGlobal) {
                    _selectedThresholds.clear();
                    _selectedThresholds.addAll(globalThresholds);
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // Custom Settings Options (Disable/dim if global is on)
            AnimatedOpacity(
              opacity: _useGlobal ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _useGlobal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PILIH AMBANG BATAS PERINGATAN KUSTOM',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    _buildThresholdCheckbox(50, 'Peringatan ketika pengeluaran mencapai 50% limit'),
                    const SizedBox(height: 4),
                    _buildThresholdCheckbox(70, 'Peringatan ketika pengeluaran mencapai 70% limit'),
                    const SizedBox(height: 4),
                    _buildThresholdCheckbox(90, 'Peringatan ketika pengeluaran mencapai 90% limit'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            CustomButton(
              text: 'Simpan Pengaturan',
              onPressed: _saveSettings,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdCheckbox(int value, String description) {
    final isChecked = _selectedThresholds.contains(value);
    return CheckboxListTile(
      title: Text(
        '$value% Limit',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      value: isChecked,
      activeColor: AppColors.primary,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (val) {
        if (val != null) {
          _toggleThreshold(value);
        }
      },
    );
  }
}
