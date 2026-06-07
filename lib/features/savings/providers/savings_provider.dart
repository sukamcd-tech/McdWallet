import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/domain/transaction_model.dart';
import '../data/savings_service.dart';
import '../domain/savings_goal_model.dart';
import '../../../core/providers/supabase_provider.dart';

// Provider untuk sub-tab aktif di halaman Anggaran ('budgets' atau 'savings')
final activeBudgetsTabProvider = StateProvider<String>((ref) => 'budgets');

// Provider untuk mendeteksi fallback penyimpanan lokal jika tabel DB belum dibuat
final isSavingsLocalFallbackProvider = StateProvider<bool>((ref) => false);

// Provider akses ke SavingsService
final savingsServiceProvider = Provider<SavingsService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SavingsService(supabase);
});

// StateNotifierProvider utama untuk mengelola daftar Target Tabungan
final savingsProvider = StateNotifierProvider<SavingsNotifier, AsyncValue<List<SavingsGoalModel>>>((ref) {
  final service = ref.watch(savingsServiceProvider);
  final authState = ref.watch(authStateProvider);

  final notifier = SavingsNotifier(service, ref);

  authState.whenData((user) {
    if (user != null) {
      notifier.loadSavings(user.id);
    } else {
      notifier.clear();
    }
  });

  return notifier;
});

class SavingsNotifier extends StateNotifier<AsyncValue<List<SavingsGoalModel>>> {
  final SavingsService _service;
  final Ref _ref;

  SavingsNotifier(this._service, this._ref) : super(const AsyncValue.loading());

  Future<void> loadSavings(String userId) async {
    state = const AsyncValue.loading();
    try {
      final goals = await _service.fetchSavingsGoals(userId);
      _ref.read(isSavingsLocalFallbackProvider.notifier).state = false;
      state = AsyncValue.data(goals);
    } catch (e) {
      if (e is FormatException && e.message == 'TABLE_NOT_FOUND') {
        // Fallback ke penyimpanan lokal SharedPreferences
        _ref.read(isSavingsLocalFallbackProvider.notifier).state = true;
        await _loadLocalGoals(userId);
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }

  // Menambah target tabungan baru
  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;

    final isLocal = _ref.read(isSavingsLocalFallbackProvider);
    if (isLocal) {
      final list = state.value ?? [];
      final newGoal = goal.copyWith(id: 'local_${DateTime.now().millisecondsSinceEpoch}');
      final newList = [...list, newGoal];
      state = AsyncValue.data(newList);
      await _saveLocalGoals(user.id, newList);
    } else {
      try {
        final newGoal = await _service.createSavingsGoal(goal);
        final list = state.value ?? [];
        state = AsyncValue.data([...list, newGoal]);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  // Menghapus target tabungan
  Future<void> removeSavingsGoal(String goalId) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;

    final isLocal = _ref.read(isSavingsLocalFallbackProvider);
    if (isLocal) {
      final list = state.value ?? [];
      final newList = list.where((g) => g.id != goalId).toList();
      state = AsyncValue.data(newList);
      await _saveLocalGoals(user.id, newList);
    } else {
      try {
        await _service.deleteSavingsGoal(goalId);
        final list = state.value ?? [];
        state = AsyncValue.data(list.where((g) => g.id != goalId).toList());
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  // Menabung (Deposit) atau Menarik (Withdraw) dana tabungan terintegrasi mutasi dompet
  Future<bool> adjustSavingsBalance({
    required String goalId,
    required double amount,
    required String walletId,
    required bool isDeposit,
    String? note,
  }) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return false;

    try {
      // 1. Catat transaksi mutasi keuangan dompet agar saldo dompet otomatis terpotong/bertambah
      final transaction = TransactionModel(
        id: '', // Di-generate di DB / provider
        userId: user.id,
        walletId: walletId,
        categoryId: null, // Null karena mutasi target tabungan non-kategori
        amount: amount,
        type: isDeposit ? 'expense' : 'income',
        description: note != null && note.trim().isNotEmpty
            ? note.trim()
            : (isDeposit ? 'Alokasi Tabungan' : 'Tarik Dana Tabungan'),
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Simpan transaksi melalui transactionsProvider
      await _ref.read(transactionsProvider.notifier).addTransaction(transaction);

      // 2. Perbarui jumlah current_amount tabungan reaktif di memori
      final isLocal = _ref.read(isSavingsLocalFallbackProvider);
      final list = state.value;
      if (list == null) return false;

      final index = list.indexWhere((g) => g.id == goalId);
      if (index == -1) return false;

      final goal = list[index];
      double newAmount = goal.currentAmount + (isDeposit ? amount : -amount);
      if (newAmount < 0) newAmount = 0.0;

      if (isLocal) {
        final updatedGoal = goal.copyWith(currentAmount: newAmount);
        final newList = [...list];
        newList[index] = updatedGoal;
        state = AsyncValue.data(newList);
        await _saveLocalGoals(user.id, newList);
        return true;
      } else {
        final updatedGoal = await _service.updateSavingsGoalAmount(goalId, newAmount);
        final newList = [...list];
        newList[index] = updatedGoal;
        state = AsyncValue.data(newList);
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  // Helper load data dari penyimpanan SharedPreferences
  Future<void> _loadLocalGoals(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_savings_goals_$userId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final goals = list.map((e) => SavingsGoalModel.fromJson(e as Map<String, dynamic>)).toList();
        state = AsyncValue.data(goals);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Helper save data ke penyimpanan SharedPreferences
  Future<void> _saveLocalGoals(String userId, List<SavingsGoalModel> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_savings_goals_$userId';
      final jsonList = goals.map((e) => e.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      // Ignored
    }
  }
}
