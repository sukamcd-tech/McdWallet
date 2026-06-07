import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/domain/category_model.dart';
import '../domain/budget_model.dart';
import '../providers/budgets_provider.dart';
import 'budget_detail_screen.dart';

import '../../savings/domain/savings_goal_model.dart';
import '../../savings/providers/savings_provider.dart';
import '../../savings/presentation/widgets/add_savings_goal_sheet.dart';
import '../../savings/presentation/widgets/deposit_savings_sheet.dart';
import '../../transactions/presentation/widgets/manage_categories_sheet.dart';
import '../../savings/presentation/savings_goal_detail_screen.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(activeBudgetsTabProvider);
    _pageController = PageController(initialPage: initialTab == 'budgets' ? 0 : 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showAddBudgetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddBudgetBottomSheet(),
    );
  }

  void _showAddSavingsGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddSavingsGoalBottomSheet(),
    );
  }

  void _showDepositSavingsSheet(BuildContext context, SavingsGoalModel goal, {required bool isDeposit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DepositSavingsSheet(goal: goal, isDeposit: isDeposit),
    );
  }

  void _showDeleteGoalDialog(BuildContext context, WidgetRef ref, SavingsGoalModel goal) {
    showModalBottomSheet(
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
              'Hapus Target Tabungan?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Apakah Anda yakin ingin menghapus target tabungan impian "${goal.name}"?\n(Aksi ini tidak dapat dibatalkan)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Hapus',
              color: AppColors.danger,
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(savingsProvider.notifier).removeSavingsGoal(goal.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Target tabungan "${goal.name}" berhasil dihapus.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'Batal',
              isOutlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final budgetsProgressAsync = ref.watch(budgetsProgressProvider);
    final activeTab = ref.watch(activeBudgetsTabProvider);

    // Sync PageView when activeBudgetsTabProvider changes externally/programmatically
    ref.listen<String>(activeBudgetsTabProvider, (previous, next) {
      final targetPage = next == 'budgets' ? 0 : 1;
      if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Anggaran & Tabungan'),
      ),
      body: Column(
        children: [
          // Dynamic Top Segmented Tab Control (Custom animated sliding pill!)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final tabWidth = totalWidth / 2;
                  final isBudgets = activeTab == 'budgets';
                  
                  return Stack(
                    children: [
                      // Smooth Sliding highlight capsule
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.fastOutSlowIn,
                        left: isBudgets ? 0 : tabWidth,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
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
                      
                      // Row of labels
                      Row(
                        children: [
                          // Tab 1: Anggaran
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                ref.read(activeBudgetsTabProvider.notifier).state = 'budgets';
                              },
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 150),
                                  style: TextStyle(
                                    color: isBudgets ? Colors.white : AppColors.textSecondary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                  child: const Text('Batas Pengeluaran'),
                                ),
                              ),
                            ),
                          ),
                          // Tab 2: Tabungan
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                ref.read(activeBudgetsTabProvider.notifier).state = 'savings';
                              },
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 150),
                                  style: TextStyle(
                                    color: !isBudgets ? Colors.white : AppColors.textSecondary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                  child: const Text('Target Tabungan'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          
          // Tab Content Area
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                ref.read(activeBudgetsTabProvider.notifier).state = index == 0 ? 'budgets' : 'savings';
              },
              physics: const BouncingScrollPhysics(),
              children: [
                _buildBudgetsTab(context, ref, budgetsProgressAsync),
                _buildSavingsTab(context, ref),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          if (activeTab == 'budgets') {
            _showAddBudgetSheet(context);
          } else {
            _showAddSavingsGoalSheet(context);
          }
        },
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildBudgetsTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<BudgetProgress>> budgetsProgressAsync,
  ) {
    return budgetsProgressAsync.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => ShimmerSkeleton.card(height: 120),
      ),
      error: (err, _) => Center(
        child: Text(
          'Gagal memuat anggaran: $err',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (progressList) {
        if (progressList.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.activity, size: 80, color: AppColors.secondary.withOpacity(0.3)),
                  const SizedBox(height: 24),
                  const Text(
                    'Belum Ada Anggaran Dibuat',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tentukan batas maksimal pengeluaran bulanan atau kategori spesifik Anda '
                    'untuk melacak keuangan secara reaktif dan otomatis.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Buat Anggaran Pertama',
                    onPressed: () => _showAddBudgetSheet(context),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
          itemCount: progressList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final progress = progressList[index];
            final budget = progress.budget;
            final isGlobal = budget.categoryId == null;

            final categoryName = isGlobal ? 'Anggaran Global' : (budget.category?.name ?? 'Kategori');
            final categoryColor = isGlobal
                ? AppColors.secondary
                : Color(int.parse((budget.category?.color ?? '#607D8B').replaceAll('#', '0xFF')));

            String periodLabel = 'Bulanan';
            if (budget.period == 'weekly') periodLabel = 'Mingguan';
            if (budget.period == 'yearly') periodLabel = 'Tahunan';

            Color progressColor = AppColors.primary; // Charcoal
            if (progress.percentage >= 0.8 && progress.percentage < 1.0) {
              progressColor = const Color(0xFFF59E0B); // Amber Yellow
            } else if (progress.percentage >= 1.0) {
              progressColor = AppColors.expense; // Rose Red
            }

            final bool isExceeded = progress.percentage >= 1.0;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BudgetDetailScreen(budget: budget),
                  ),
                );
              },
              child: AppCard(
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
                                    fontSize: 16,
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            const SizedBox(width: 8),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(LucideIcons.trash2, color: AppColors.danger, size: 18),
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
                                          'Hapus Anggaran?',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Apakah Anda yakin ingin menghapus anggaran untuk "$categoryName"?',
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
                                  ref.read(budgetsProvider.notifier).removeBudget(budget.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Anggaran untuk "$categoryName" berhasil dihapus.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${Formatters.formatDateShort(budget.startDate)} - ${Formatters.formatDateShort(budget.endDate)}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TERPAKAI', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.formatCurrency(progress.spentAmount),
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
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
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.percentage.clamp(0.0, 1.0),
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
                          '${(progress.percentage * 100).toStringAsFixed(0)}% terpakai',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        Text(
                          isExceeded
                              ? 'Melebihi ${Formatters.formatCurrency(progress.remainingAmount.abs())}'
                              : 'Sisa ${Formatters.formatCurrency(progress.remainingAmount)}',
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavingsTab(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(savingsProvider);
    final isLocalFallback = ref.watch(isSavingsLocalFallbackProvider);

    return Column(
      children: [
        if (isLocalFallback) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Mode Penyimpanan Lokal Aktif',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Jalankan script SQL tabungan di dashboard Supabase Anda untuk mengaktifkan sinkronisasi awan otomatis.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        Expanded(
          child: savingsAsync.when(
            loading: () => ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, __) => ShimmerSkeleton.card(height: 110),
            ),
            error: (err, _) => Center(
              child: Text(
                'Gagal memuat tabungan: $err',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            data: (goals) {
              if (goals.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.wallet,
                          size: 80,
                          color: AppColors.secondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Belum Ada Target Tabungan Impian',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tentukan mimpi impian Anda (seperti beli gadget, liburan, atau dana darurat) '
                          'dan mulailah alokasikan uang dari dompet secara terencana.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Buat Target Tabungan Pertama',
                          onPressed: () => _showAddSavingsGoalSheet(context),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                itemCount: goals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final accentColor = Color(int.parse(goal.color.replaceAll('#', '0xFF')));

                  String? targetDateLabel;
                  if (goal.targetDate != null) {
                    targetDateLabel = Formatters.formatDateShort(goal.targetDate!);
                  }

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SavingsGoalDetailScreen(goal: goal),
                        ),
                      );
                    },
                    child: AppCard(
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
                                    _getIconData(goal.icon),
                                    color: accentColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.name,
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
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.trash2, color: AppColors.danger, size: 18),
                                  onPressed: () => _showDeleteGoalDialog(context, ref, goal),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (goal.savingInterval != 'custom') ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Chip alokasi (e.g. Harian / Mingguan / Bulanan)
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
                                    Icon(
                                      LucideIcons.repeat,
                                      size: 12,
                                      color: accentColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${Formatters.formatCurrency(goal.savingAmountPerInterval)} / ${goal.savingInterval == 'daily' ? 'hari' : goal.savingInterval == 'weekly' ? 'minggu' : 'bulan'}',
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
                              // Chip sisa waktu (e.g. Sisa 20 hari lagi)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: goal.isAchieved 
                                      ? AppColors.success.withOpacity(0.08) 
                                      : AppColors.surfaceAlt.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: goal.isAchieved 
                                        ? AppColors.success.withOpacity(0.2) 
                                        : AppColors.border,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      goal.isAchieved ? LucideIcons.checkCircle : LucideIcons.hourglass,
                                      size: 12,
                                      color: goal.isAchieved ? AppColors.success : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      goal.isAchieved 
                                          ? 'Tercapai 🎉' 
                                          : 'Sisa ${goal.remainingIntervals} ${goal.savingInterval == 'daily' ? 'hari' : goal.savingInterval == 'weekly' ? 'minggu' : 'bulan'} lagi',
                                      style: TextStyle(
                                        color: goal.isAchieved ? AppColors.success : AppColors.textSecondary,
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
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TERKUMPUL',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.formatCurrency(goal.currentAmount),
                                  style: TextStyle(
                                    color: goal.isAchieved ? AppColors.success : AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'TARGET NOMINAL',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.formatCurrency(goal.targetAmount),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: goal.percentage,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceAlt,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              goal.isAchieved ? AppColors.success : accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(goal.percentage * 100).toStringAsFixed(0)}% tercapai',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            Row(
                              children: [
                                if (goal.isAchieved) ...[
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
                                  const SizedBox(width: 8),
                                ],
                                ElevatedButton(
                                  onPressed: () => _showDepositSavingsSheet(context, goal, isDeposit: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Tabung',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _showDepositSavingsSheet(context, goal, isDeposit: false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.border, width: 1.5),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Tarik',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ========================================================
// ADD BUDGET BOTTOM SHEET
// ========================================================
class _AddBudgetBottomSheet extends ConsumerStatefulWidget {
  const _AddBudgetBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<_AddBudgetBottomSheet> createState() => _AddBudgetBottomSheetState();
}

class _AddBudgetBottomSheetState extends ConsumerState<_AddBudgetBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();

  CategoryModel? _selectedCategory;
  String _selectedPeriod = 'monthly';
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1); // awal bulan
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0); // akhir bulan
  bool _isSaving = false;

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _showManageCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManageCategoriesBottomSheet(initialType: 'expense'),
    ).then((_) {
      setState(() {});
    });
  }

  // Menghitung otomatis rentang tanggal default berdasarkan periode
  void _updateDatesByPeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;
      if (period == 'weekly') {
        _startDate = now;
        _endDate = now.add(const Duration(days: 6));
      } else if (period == 'monthly') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
      } else if (period == 'yearly') {
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
      }
    });
  }

  Future<void> _selectDate(bool isStart) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  Future<void> _handleSaveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal akhir tidak boleh mendahului tanggal mulai.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final limit = double.tryParse(_limitController.text.replaceAll('.', '').trim()) ?? 0.0;
    if (limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batas limit anggaran harus lebih dari 0.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final newBudget = BudgetModel(
        id: '', // Di-generate oleh database
        userId: user.id,
        categoryId: _selectedCategory?.id, // Null berarti global
        amountLimit: limit,
        period: _selectedPeriod,
        startDate: _startDate,
        endDate: _endDate,
        createdAt: DateTime.now(),
      );

      await ref.read(budgetsProvider.notifier).addBudget(newBudget);

      if (mounted) {
        Navigator.pop(context); // Tutup bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anggaran baru berhasil disimpan!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan anggaran: $e'),
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
    final categoriesAsync = ref.watch(categoriesProvider);

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
                const Text(
                  'Buat Anggaran Baru',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // LIMIT ANGGARAN
                CustomTextField(
                  controller: _limitController,
                  label: 'BATAS MAKSIMAL (LIMIT)',
                  hintText: 'Masukkan nominal rupiah, contoh: 2.000.000',
                  prefixIcon: LucideIcons.coins,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    IndonesianCurrencyInputFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Batas limit tidak boleh kosong';
                    }
                    final cleanValue = value.replaceAll('.', '');
                    if (double.tryParse(cleanValue) == null) {
                      return 'Masukkan nominal angka yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // PILIHAN KATEGORI (DROPDOWN)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'UNTUK KATEGORI',
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
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (categories) {
                    // Budgets hanya untuk pengeluaran (type = expense)
                    final expenseCategories = categories.where((c) => c.type == 'expense').toList();
                    if (_selectedCategory != null && !expenseCategories.any((c) => c.id == _selectedCategory!.id)) {
                      _selectedCategory = null;
                    }

                    return DropdownButtonFormField<String?>(
                      value: _selectedCategory?.id,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 18),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      hint: const Text('Anggaran Global (Semua Pengeluaran)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Anggaran Global (Semua Pengeluaran)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        ),
                        ...expenseCategories.map((cat) {
                          final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
                          return DropdownMenuItem<String?>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
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
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val == null ? null : expenseCategories.firstWhere((c) => c.id == val);
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // PERIODE ANGGARAN (WEEKLY / MONTHLY / YEARLY)
                const Text(
                  'PERIODE ANGGARAN',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 18),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Mingguan', style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                    DropdownMenuItem(value: 'monthly', child: Text('Bulanan', style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                    DropdownMenuItem(value: 'yearly', child: Text('Tahunan', style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                  ],
                  onChanged: (val) {
                    if (val != null) _updateDatesByPeriod(val);
                  },
                ),
                const SizedBox(height: 20),

                // DATE PICKERS FOR START & END DATE
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MULAI TANGGAL', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(true),
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
                                  Text(Formatters.formatDateShort(_startDate), style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                  const Icon(LucideIcons.calendar, size: 16, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SAMPAI TANGGAL', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(false),
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
                                  Text(Formatters.formatDateShort(_endDate), style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                  const Icon(LucideIcons.calendar, size: 16, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // TOMBOL SIMPAN
                CustomButton(
                  text: 'Simpan Anggaran',
                  isLoading: _isSaving,
                  onPressed: _handleSaveBudget,
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
