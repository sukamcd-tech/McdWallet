import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider untuk mengelola pengaturan ambang batas peringatan anggaran (budget warning thresholds).
/// Menampung Set berisi persentase peringatan aktif (50, 70, 90).
final budgetSettingsProvider = StateNotifierProvider<BudgetSettingsNotifier, Set<int>>((ref) {
  return BudgetSettingsNotifier();
});

class BudgetSettingsNotifier extends StateNotifier<Set<int>> {
  BudgetSettingsNotifier() : super({50, 70, 90}) {
    _loadState();
  }

  static const _key = 'budget_thresholds';

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key);
      if (list != null) {
        state = list.map((e) => int.parse(e)).toSet();
      }
    } catch (_) {
      // Fallback ke default jika terjadi kegagalan
      state = {50, 70, 90};
    }
  }

  /// Menyalakan/mematikan salah satu ambang batas peringatan
  Future<void> toggleThreshold(int threshold) async {
    final updated = Set<int>.from(state);
    if (updated.contains(threshold)) {
      updated.remove(threshold);
    } else {
      updated.add(threshold);
    }
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, updated.map((e) => e.toString()).toList());
    } catch (_) {}
  }
}

/// Provider family untuk mengelola ambang batas peringatan anggaran spesifik per anggaran (budget-specific).
/// Jatuh kembali (fallback) ke pengaturan global jika tidak dikustomisasi oleh user.
final budgetThresholdsProvider = StateNotifierProvider.family<BudgetThresholdsNotifier, Set<int>, String>((ref, budgetId) {
  final globalThresholds = ref.watch(budgetSettingsProvider);
  return BudgetThresholdsNotifier(budgetId, globalThresholds);
});

class BudgetThresholdsNotifier extends StateNotifier<Set<int>> {
  final String budgetId;
  final Set<int> globalDefault;

  BudgetThresholdsNotifier(this.budgetId, this.globalDefault) : super({}) {
    _loadState();
  }

  String get _key => 'budget_thresholds_$budgetId';

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key);
      if (list != null) {
        state = list.map((e) => int.parse(e)).toSet();
      } else {
        state = globalDefault;
      }
    } catch (_) {
      state = globalDefault;
    }
  }

  /// Memperbarui ambang batas khusus untuk anggaran ini
  Future<void> updateThresholds(Set<int> newThresholds) async {
    state = newThresholds;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, newThresholds.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  /// Menghapus pengaturan khusus sehingga kembali menggunakan pengaturan global
  Future<void> resetToGlobal() async {
    state = globalDefault;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  /// Mengecek apakah anggaran ini menggunakan kustom threshold atau global default
  Future<bool> isCustom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) != null;
    } catch (_) {
      return false;
    }
  }
}

