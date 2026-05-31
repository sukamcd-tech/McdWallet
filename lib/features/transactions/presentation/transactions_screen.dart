import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/widgets/shimmer_loading.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/transaction_model.dart';
import '../domain/wallet_model.dart';
import '../providers/transactions_provider.dart';
import 'transaction_input_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _FilterBottomSheet(),
    );
  }

  void _showTransactionDetailsDialog(BuildContext context, TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TransactionDetailsDialog(tx: tx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final allTransactionsAsync = ref.watch(allTransactionsProvider);
    final walletsAsync = ref.watch(walletsProvider);
    final activeWalletFilter = ref.watch(walletFilterProvider);
    final activeCategoryFilter = ref.watch(categoryFilterProvider);
    final activeTypeFilter = ref.watch(typeFilterProvider);

    final hasActiveFilters = activeWalletFilter != null || activeCategoryFilter != null || activeTypeFilter != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.slidersHorizontal, color: AppColors.textPrimary),
                onPressed: () => _showFilterBottomSheet(context),
              ),
              if (hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  icon: const Icon(LucideIcons.search, color: AppColors.textSecondary, size: 18),
                  hintText: 'Cari transaksi...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
          ),

          // ACTIVE FILTER BADGES ROW
          if (hasActiveFilters)
            _buildActiveFilterBadgesRow(context, activeWalletFilter, activeCategoryFilter, activeTypeFilter),



          // TRANSACTIONS LIST
          Expanded(
            child: transactionsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: 8,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, __) => Row(
                  children: [
                    ShimmerSkeleton.circle(size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerSkeleton(width: 120, height: 14, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerSkeleton(width: 80, height: 10, borderRadius: 4),
                        ],
                      ),
                    ),
                    const ShimmerSkeleton(width: 70, height: 14, borderRadius: 4),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Gagal memuat transaksi: $err',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (txs) {
                // Apply search filter locally
                var filteredTxs = txs;
                if (_searchQuery.isNotEmpty) {
                  filteredTxs = txs.where((tx) {
                    final desc = tx.description?.toLowerCase() ?? '';
                    final catName = tx.category?.name.toLowerCase() ?? '';
                    final walletName = tx.wallet?.name.toLowerCase() ?? '';
                    final toWalletName = tx.toWallet?.name.toLowerCase() ?? '';
                    
                    return desc.contains(_searchQuery) ||
                        catName.contains(_searchQuery) ||
                        walletName.contains(_searchQuery) ||
                        toWalletName.contains(_searchQuery);
                  }).toList();
                }

                // Filter by selected month
                final monthTxs = filteredTxs.where((tx) {
                  return tx.date.year == _selectedMonth.year &&
                      tx.date.month == _selectedMonth.month;
                }).toList();

                if (monthTxs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      _buildMonthlySummaryCard(
                        context,
                        filteredTxs,
                        allTransactionsAsync.value,
                        walletsAsync.value,
                        activeWalletFilter,
                      ),
                      const SizedBox(height: 48),
                      Icon(LucideIcons.listX, size: 60, color: AppColors.textMuted.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Tidak ada transaksi ditemukan',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty || hasActiveFilters
                            ? 'Coba ubah kata kunci pencarian atau matikan filter aktif.'
                            : 'Tidak ada catatan transaksi untuk bulan ini.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      if (hasActiveFilters) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton.icon(
                            icon: const Icon(LucideIcons.refreshCw, size: 16),
                            label: const Text('Reset Semua Filter'),
                            onPressed: () {
                              ref.read(walletFilterProvider.notifier).state = null;
                              ref.read(categoryFilterProvider.notifier).state = null;
                              ref.read(typeFilterProvider.notifier).state = null;
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                }

                // Group transactions by date
                final grouped = _groupTransactionsByDate(monthTxs);

                // Flatten the list of items for true lazy scroll virtualization
                final flatItems = <dynamic>[];
                flatItems.add('summary_card');
                for (final entry in grouped) {
                  flatItems.add(entry.key); // Header (String)
                  flatItems.addAll(entry.value); // Transactions (List<TransactionModel>)
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: flatItems.length,
                  itemBuilder: (context, index) {
                    final item = flatItems[index];

                    if (item == 'summary_card') {
                      return _buildMonthlySummaryCard(
                        context,
                        filteredTxs,
                        allTransactionsAsync.value,
                        walletsAsync.value,
                        activeWalletFilter,
                      );
                    } else if (item is String) {
                      // Date Header
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 10, left: 4),
                        child: Text(
                          item.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      );
                    } else if (item is TransactionModel) {
                      // Transaction Item wrapped with consistent list gap spacing
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildTransactionItem(context, item),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TransactionInputScreen(initialType: 'expense'),
            ),
          );
        },
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  double _calculateOpeningBalance({
    required List<TransactionModel> allTxs,
    required double currentBalance,
    required DateTime targetDateTime,
    String? activeWalletId,
  }) {
    double rollbackAmount = 0.0;
    for (final tx in allTxs) {
      if (tx.date.isAfter(targetDateTime) || tx.date.isAtSameMomentAs(targetDateTime)) {
        if (activeWalletId == null) {
          // Gabungan semua dompet
          if (tx.type == 'income') {
            rollbackAmount += tx.amount;
          } else if (tx.type == 'expense') {
            rollbackAmount -= tx.amount;
          } else if (tx.type == 'transfer') {
            rollbackAmount -= (tx.adminFee ?? 0.0);
          }
        } else {
          // Spesifik dompet aktif
          if (tx.walletId == activeWalletId) {
            if (tx.type == 'income') {
              rollbackAmount += tx.amount;
            } else if (tx.type == 'expense') {
              rollbackAmount -= tx.amount;
            } else if (tx.type == 'transfer') {
              rollbackAmount -= (tx.amount + (tx.adminFee ?? 0.0));
            }
          }
          if (tx.toWalletId == activeWalletId && tx.type == 'transfer') {
            rollbackAmount += tx.amount;
          }
        }
      }
    }
    return currentBalance - rollbackAmount;
  }

  Widget _buildMonthlySummaryCard(
    BuildContext context,
    List<TransactionModel> filteredTxs,
    List<TransactionModel>? allTxs,
    List<WalletModel>? wallets,
    String? activeWalletFilter,
  ) {
    final activeWallet = (wallets != null && activeWalletFilter != null)
        ? wallets.firstWhere((w) => w.id == activeWalletFilter, orElse: () => wallets.first)
        : null;
    final currencyCode = activeWallet?.currencyCode ?? 'IDR';

    final now = DateTime.now();
    final canGoToNextMonth = _selectedMonth.year < now.year || 
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);

    final monthTxs = filteredTxs.where((tx) {
      return tx.date.year == _selectedMonth.year &&
          tx.date.month == _selectedMonth.month;
    }).toList();

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    
    for (var tx in monthTxs) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
      } else if (tx.type == 'transfer' && tx.adminFee != null) {
        totalExpense += tx.adminFee!;
      }
    }
    final netBalance = totalIncome - totalExpense;

    // Hitung Saldo Awal dan Saldo Akhir secara absolut
    double currentBalance = 0.0;
    if (wallets != null) {
      if (activeWalletFilter != null) {
        final wallet = wallets.firstWhere(
          (w) => w.id == activeWalletFilter,
          orElse: () => WalletModel(id: '', userId: '', name: '', balance: 0.0, color: '', icon: '', createdAt: DateTime.now()),
        );
        currentBalance = wallet.balance;
      } else {
        currentBalance = wallets.fold(0.0, (sum, w) => sum + w.balance);
      }
    }

    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    
    double saldoAwal = 0.0;
    double saldoAkhir = 0.0;

    if (allTxs != null && wallets != null) {
      saldoAwal = _calculateOpeningBalance(
        allTxs: allTxs,
        currentBalance: currentBalance,
        targetDateTime: monthStart,
        activeWalletId: activeWalletFilter,
      );

      // Hitung absolute income & expense bulan ini untuk saldo akhir
      double monthIncome = 0.0;
      double monthExpense = 0.0;

      final monthTxsForBalance = allTxs.where((tx) {
        final isSameMonth = tx.date.year == _selectedMonth.year && tx.date.month == _selectedMonth.month;
        if (!isSameMonth) return false;
        
        if (activeWalletFilter != null) {
          return tx.walletId == activeWalletFilter || (tx.type == 'transfer' && tx.toWalletId == activeWalletFilter);
        }
        return true;
      }).toList();

      for (final tx in monthTxsForBalance) {
        if (activeWalletFilter == null) {
          if (tx.type == 'income') {
            monthIncome += tx.amount;
          } else if (tx.type == 'expense') {
            monthExpense += tx.amount;
          } else if (tx.type == 'transfer') {
            monthExpense += (tx.adminFee ?? 0.0);
          }
        } else {
          if (tx.walletId == activeWalletFilter) {
            if (tx.type == 'income') {
              monthIncome += tx.amount;
            } else if (tx.type == 'expense') {
              monthExpense += tx.amount;
            } else if (tx.type == 'transfer') {
              monthExpense += (tx.amount + (tx.adminFee ?? 0.0));
            }
          }
          if (tx.toWalletId == activeWalletFilter && tx.type == 'transfer') {
            monthIncome += tx.amount;
          }
        }
      }

      saldoAkhir = saldoAwal + monthIncome - monthExpense;
    }

    final monthStr = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // MONTH SELECTOR ROW - Compact Premium Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textSecondary, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                    });
                  },
                  visualDensity: VisualDensity.compact,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    monthStr.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.chevronRight, 
                    color: canGoToNextMonth ? AppColors.textSecondary : AppColors.textMuted.withOpacity(0.3), 
                    size: 18
                  ),
                  onPressed: canGoToNextMonth ? () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                    });
                  } : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            
            // SALDO AWAL & SALDO AKHIR FLOW CONTAINER
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.4), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Saldo Awal Block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.wallet, size: 11, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            const Text(
                              'SALDO AWAL',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Formatters.formatCurrencyWithCode(saldoAwal, currencyCode),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Middle Flow Indicator
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.arrowRight,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Saldo Akhir Block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'SALDO AKHIR',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(LucideIcons.checkCircle2, size: 11, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Formatters.formatCurrencyWithCode(saldoAkhir, currencyCode),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'PEMASUKAN',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Formatters.formatCurrencyWithCode(totalIncome, currencyCode),
                        style: const TextStyle(
                          color: AppColors.income,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'PENGELUARAN',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Formatters.formatCurrencyWithCode(totalExpense, currencyCode),
                        style: const TextStyle(
                          color: AppColors.expense,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'SELISIH',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Formatters.formatCurrencyWithCode(netBalance, currencyCode),
                        style: TextStyle(
                          color: netBalance >= 0 ? AppColors.textPrimary : AppColors.expense,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBadgesRow(
    BuildContext context,
    String? activeWalletId,
    String? activeCategoryId,
    String? activeType,
  ) {
    return Container(
      height: 34,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (activeWalletId != null)
            _buildFilterBadge('Dompet Aktif', () {
              ref.read(walletFilterProvider.notifier).state = null;
            }),
          if (activeCategoryId != null)
            _buildFilterBadge('Kategori Aktif', () {
              ref.read(categoryFilterProvider.notifier).state = null;
            }),
          if (activeType != null)
            _buildFilterBadge(
              activeType == 'income'
                  ? 'Pemasukan'
                  : activeType == 'expense'
                      ? 'Pengeluaran'
                      : 'Transfer',
              () {
                ref.read(typeFilterProvider.notifier).state = null;
              },
            ),
          TextButton(
            onPressed: () {
              ref.read(walletFilterProvider.notifier).state = null;
              ref.read(categoryFilterProvider.notifier).state = null;
              ref.read(typeFilterProvider.notifier).state = null;
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBadge(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(LucideIcons.x, size: 12, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel tx) {
    final isExpense = tx.type == 'expense';
    final isTransfer = tx.type == 'transfer';

    Color valueColor = AppColors.income;
    IconData icon = LucideIcons.trendingUp;
    String prefix = '+';

    if (isExpense) {
      valueColor = AppColors.expense;
      icon = LucideIcons.trendingDown;
      prefix = '-';
    } else if (isTransfer) {
      valueColor = AppColors.transfer;
      icon = LucideIcons.arrowLeftRight;
      prefix = '';
    }

    final Color iconColor;
    if (tx.type == 'income') {
      iconColor = AppColors.income;
    } else if (tx.type == 'expense') {
      iconColor = AppColors.expense;
    } else {
      iconColor = AppColors.textMuted; // Grey for transfer
    }

    return InkWell(
      onTap: () => _showTransactionDetailsDialog(context, tx),
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.category?.name ?? (isTransfer ? 'Transfer Saldo' : 'Lainnya'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.description != null && tx.description!.isNotEmpty
                        ? tx.description!
                        : isTransfer
                            ? '${tx.wallet?.name} ➔ ${tx.toWallet?.name}'
                            : (tx.wallet?.name ?? 'Dompet'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isTransfer && tx.adminFee != null && tx.adminFee! > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Biaya Admin: ${Formatters.formatCurrencyWithCode(tx.adminFee!, tx.wallet?.currencyCode ?? 'IDR')}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (tx.attachmentPath != null) ...[
              Icon(LucideIcons.paperclip, size: 14, color: AppColors.textMuted.withOpacity(0.7)),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$prefix${Formatters.formatCurrencyWithCode(tx.amount, tx.wallet?.currencyCode ?? 'IDR')}',
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatTime(tx.date),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, List<TransactionModel>>> _groupTransactionsByDate(List<TransactionModel> txs) {
    final Map<String, List<TransactionModel>> map = {};
    
    final todayStr = Formatters.formatDate(DateTime.now());
    final yesterdayStr = Formatters.formatDate(DateTime.now().subtract(const Duration(days: 1)));

    for (var tx in txs) {
      final keyDateStr = Formatters.formatDate(tx.date);
      String groupKey = keyDateStr;
      
      if (keyDateStr == todayStr) {
        groupKey = 'Hari Ini';
      } else if (keyDateStr == yesterdayStr) {
        groupKey = 'Kemarin';
      }

      if (map[groupKey] == null) {
        map[groupKey] = [];
      }
      map[groupKey]!.add(tx);
    }

    return map.entries.toList();
  }
}

// ========================================================
// FILTER BOTTOM SHEET
// ========================================================
class _FilterBottomSheet extends ConsumerStatefulWidget {
  const _FilterBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  String? _tempWalletId;
  String? _tempCategoryId;
  String? _tempType;

  @override
  void initState() {
    super.initState();
    _tempWalletId = ref.read(walletFilterProvider);
    _tempCategoryId = ref.read(categoryFilterProvider);
    _tempType = ref.read(typeFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Penyaringan Cerdas',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempWalletId = null;
                        _tempCategoryId = null;
                        _tempType = null;
                      });
                    },
                    child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // FILTER BY TYPE
              const Text(
                'Tipe Transaksi',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTypeOption('Semua', null),
                  const SizedBox(width: 8),
                  _buildTypeOption('Pengeluaran', 'expense'),
                  const SizedBox(width: 8),
                  _buildTypeOption('Pemasukan', 'income'),
                  const SizedBox(width: 8),
                  _buildTypeOption('Transfer', 'transfer'),
                ],
              ),
              const SizedBox(height: 24),

              // FILTER BY WALLET
              const Text(
                'Berdasarkan Dompet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              walletsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (wallets) => DropdownButtonFormField<String?>(
                  value: _tempWalletId,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 18),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: const Text('Semua Dompet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Semua Dompet', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    ),
                    ...wallets.map((wallet) {
                      final color = Color(int.parse(wallet.color.replaceAll('#', '0xFF')));
                      return DropdownMenuItem(
                        value: wallet.id,
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Text(wallet.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _tempWalletId = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // FILTER BY CATEGORY
              if (_tempType != 'transfer') ...[
                const Text(
                  'Berdasarkan Kategori',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (categories) {
                    final filteredCats = _tempType == null ? categories : categories.where((c) => c.type == _tempType).toList();
                    return DropdownButtonFormField<String?>(
                      value: _tempCategoryId,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 18),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      hint: const Text('Semua Kategori', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Semua Kategori', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        ),
                        ...filteredCats.map((cat) {
                          final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
                          return DropdownMenuItem(
                            value: cat.id,
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Text(cat.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _tempCategoryId = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],

              // APPLY FILTER BUTTON
              CustomButton(
                text: 'Terapkan Penyaringan',
                onPressed: () {
                  ref.read(walletFilterProvider.notifier).state = _tempWalletId;
                  ref.read(categoryFilterProvider.notifier).state = _tempCategoryId;
                  ref.read(typeFilterProvider.notifier).state = _tempType;
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String label, String? type) {
    final isSelected = _tempType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tempType = type;
            _tempCategoryId = null; // reset category filter as type changed
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary.withOpacity(0.3) : AppColors.border,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================================
// TRANSACTION DETAILS DIALOG
// ========================================================
class _TransactionDetailsDialog extends ConsumerWidget {
  final TransactionModel tx;

  const _TransactionDetailsDialog({Key? key, required this.tx}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = tx.type == 'expense';
    final isTransfer = tx.type == 'transfer';
    final amountColor = isExpense
        ? AppColors.expense
        : isTransfer
            ? AppColors.transfer
            : AppColors.income;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: amountColor.withOpacity(0.5), width: 2.0)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isExpense
                            ? LucideIcons.trendingDown
                            : isTransfer
                                ? LucideIcons.arrowLeftRight
                                : LucideIcons.trendingUp,
                        color: amountColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isExpense
                            ? 'Pengeluaran'
                            : isTransfer
                                ? 'Transfer Saldo'
                                : 'Pemasukan',
                        style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(LucideIcons.moreHorizontal, color: AppColors.textSecondary, size: 20),
                    color: AppColors.surface,
                    surfaceTintColor: AppColors.surface,
                    onSelected: (val) {
                      if (val == 'edit') {
                        Navigator.pop(context); // Close details bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionInputScreen(
                              transactionToEdit: tx,
                            ),
                          ),
                        );
                      } else if (val == 'delete') {
                        _confirmDelete(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(LucideIcons.edit2, color: AppColors.textPrimary, size: 16),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(LucideIcons.trash2, color: AppColors.danger, size: 16),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: AppColors.danger, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: AppColors.border, height: 24),

              // AMOUNT
              Center(
                child: Column(
                  children: [
                    const Text(
                      'NOMINAL',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.formatCurrencyWithCode(tx.amount, tx.wallet?.currencyCode ?? 'IDR'),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: amountColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TRANSACTION DETAILS ROWS
              _buildDetailRow('Tanggal & Waktu', Formatters.formatDateTime(tx.date)),
              const SizedBox(height: 12),
              if (!isTransfer) ...[
                _buildDetailRow('Kategori', tx.category?.name ?? 'Lainnya'),
                const SizedBox(height: 12),
                _buildDetailRow('Dompet', tx.wallet?.name ?? 'Dompet'),
              ] else ...[
                _buildDetailRow('Dompet Asal', tx.wallet?.name ?? 'Dompet'),
                const SizedBox(height: 12),
                _buildDetailRow('Dompet Tujuan', tx.toWallet?.name ?? 'Dompet Tujuan'),
                if (tx.adminFee != null && tx.adminFee! > 0) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Biaya Admin', Formatters.formatCurrencyWithCode(tx.adminFee!, tx.wallet?.currencyCode ?? 'IDR')),
                  const SizedBox(height: 12),
                  _buildDetailRow('Total Potong Saldo', Formatters.formatCurrencyWithCode(tx.amount + tx.adminFee!, tx.wallet?.currencyCode ?? 'IDR')),
                ],
              ],
              const SizedBox(height: 12),
              _buildDetailRow('Catatan', tx.description != null && tx.description!.isNotEmpty ? tx.description! : '-'),

              // RECEIPT ATTACHMENT VIEW
              if (tx.attachmentPath != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'LAMPIRAN STRUK',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // Open full screen image view in bottom sheet
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.8,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Lampiran Nota',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: InteractiveViewer(
                                  panEnabled: true,
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: Image.network(
                                    tx.attachmentPath!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                                    },
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Text('Gagal memuat struk', style: TextStyle(color: AppColors.danger)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        tx.attachmentPath!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        },
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(LucideIcons.imageOff, color: AppColors.danger, size: 30),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              CustomButton(
                text: 'Tutup',
                isOutlined: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
              'Hapus Transaksi?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Apakah Anda yakin ingin menghapus catatan transaksi ini? Saldo dompet Anda akan dikembalikan otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
      ref.read(transactionsProvider.notifier).removeTransaction(tx.id);
      if (context.mounted) {
        Navigator.pop(context); // Close details dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan transaksi berhasil dihapus.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
