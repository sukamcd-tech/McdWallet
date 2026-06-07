import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../domain/savings_goal_model.dart';
import '../providers/savings_provider.dart';
import '../presentation/widgets/deposit_savings_sheet.dart';

class SavingsGoalDetailScreen extends ConsumerWidget {
  final SavingsGoalModel goal;

  const SavingsGoalDetailScreen({Key? key, required this.goal}) : super(key: key);

  IconData _getIconData(String name) {
    switch (name) {
      case 'piggyBank':
        return LucideIcons.wallet;
      case 'home':
        return LucideIcons.home;
      case 'car':
        return LucideIcons.car;
      case 'plane':
        return LucideIcons.plane;
      case 'laptop':
        return LucideIcons.laptop;
      case 'gift':
        return LucideIcons.gift;
      case 'smartphone':
        return LucideIcons.smartphone;
      case 'gamepad':
        return LucideIcons.gamepad2;
      case 'shopping':
        return LucideIcons.shoppingBag;
      case 'trending':
        return LucideIcons.trendingUp;
      default:
        return LucideIcons.wallet;
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

  void _showDepositSavingsSheet(BuildContext context, SavingsGoalModel currentGoal, {required bool isDeposit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DepositSavingsSheet(goal: currentGoal, isDeposit: isDeposit),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTransactionsAsync = ref.watch(allTransactionsProvider);
    final savingsGoalsAsync = ref.watch(savingsProvider);

    // Watch the savings goals to get the updated goal amount live!
    final SavingsGoalModel currentGoal = savingsGoalsAsync.when(
      data: (goals) => goals.firstWhere((g) => g.id == goal.id, orElse: () => goal),
      loading: () => goal,
      error: (_, __) => goal,
    );

    final accentColor = Color(int.parse(currentGoal.color.replaceAll('#', '0xFF')));

    String? targetDateLabel;
    if (currentGoal.targetDate != null) {
      targetDateLabel = Formatters.formatDateShort(currentGoal.targetDate!);
    }

    final double remainingNeeded = currentGoal.targetAmount - currentGoal.currentAmount;
    final double percentage = currentGoal.percentage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Tabungan'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: allTransactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Text(
            'Gagal memuat detail tabungan: $err',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (allTransactions) {
          // Filter transactions that mention the goal's name or fit default descriptions
          final goalTransactions = allTransactions.where((tx) {
            final desc = tx.description?.toLowerCase() ?? '';
            final goalNameLower = currentGoal.name.toLowerCase();
            return desc.contains(goalNameLower);
          }).toList();

          final groupedTransactions = _groupTransactionsByDate(goalTransactions);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. FINANCIAL SUMMARY CARD
                // ==========================================
                AppCard(
                  borderColor: accentColor.withOpacity(0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getIconData(currentGoal.icon),
                                  color: accentColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentGoal.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (targetDateLabel != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(LucideIcons.calendar, size: 12, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Target: $targetDateLabel',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (currentGoal.isAchieved)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Tercapai 🎉',
                                style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      
                      if (currentGoal.savingInterval != 'custom') ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accentColor.withOpacity(0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.repeat, size: 12, color: accentColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${Formatters.formatCurrency(currentGoal.savingAmountPerInterval)} / ${currentGoal.savingInterval == 'daily' ? 'hari' : currentGoal.savingInterval == 'weekly' ? 'minggu' : 'bulan'}',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: currentGoal.isAchieved 
                                    ? AppColors.success.withOpacity(0.08) 
                                    : AppColors.surfaceAlt.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: currentGoal.isAchieved 
                                      ? AppColors.success.withOpacity(0.2) 
                                      : AppColors.border,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    currentGoal.isAchieved ? LucideIcons.checkCircle : LucideIcons.hourglass,
                                    size: 12,
                                    color: currentGoal.isAchieved ? AppColors.success : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentGoal.isAchieved 
                                        ? 'Tercapai 🎉' 
                                        : 'Sisa ${currentGoal.remainingIntervals} ${currentGoal.savingInterval == 'daily' ? 'hari' : currentGoal.savingInterval == 'weekly' ? 'minggu' : 'bulan'} lagi',
                                    style: TextStyle(
                                      color: currentGoal.isAchieved ? AppColors.success : AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TERKUMPUL', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.formatCurrency(currentGoal.currentAmount),
                                style: TextStyle(
                                  color: currentGoal.isAchieved ? AppColors.success : AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('TARGET NOMINAL', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.formatCurrency(currentGoal.targetAmount),
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
                          value: percentage,
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            currentGoal.isAchieved ? AppColors.success : accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}% tercapai',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            currentGoal.isAchieved
                                ? 'Target terpenuhi!'
                                : 'Kurang ${Formatters.formatCurrency(remainingNeeded)} lagi',
                            style: TextStyle(
                              color: currentGoal.isAchieved ? AppColors.success : AppColors.textSecondary,
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
                // 2. QUICK ACTIONS (TABUNG & TARIK)
                // ==========================================
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Aksi Cepat',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _showDepositSavingsSheet(context, currentGoal, isDeposit: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Tabung',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _showDepositSavingsSheet(context, currentGoal, isDeposit: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Tarik',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
                const SizedBox(height: 24),

                // ==========================================
                // 3. TRANSACTION HISTORY LIST
                // ==========================================
                const Text(
                  'Riwayat Tabungan',
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
                          'Belum ada riwayat transaksi tabungan.',
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
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCardItem(BuildContext context, TransactionModel tx) {
    // Expense means deposit to savings goal, income means withdrawal from savings goal
    final isDeposit = tx.type == 'expense';
    final accentColor = isDeposit ? AppColors.income : AppColors.expense;

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
                                isDeposit ? 'Menabung' : 'Tarik Tabungan',
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
                              '${isDeposit ? '+' : '−'}${Formatters.formatCurrencyWithCode(tx.amount, tx.wallet?.currencyCode ?? 'IDR')}',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Outfit',
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
          ),
        ),
      ),
    );
  }
}
