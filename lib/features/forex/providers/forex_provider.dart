import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/forex_service.dart';
import '../domain/forex_rate_model.dart';

// ════════════════════════════════════════════════════════════
//  SERVICE PROVIDER
// ════════════════════════════════════════════════════════════

final forexServiceProvider = Provider<ForexService>((_) => ForexService());

// ════════════════════════════════════════════════════════════
//  SELECTED CURRENCIES  (max 5, persisted)
// ════════════════════════════════════════════════════════════

const _defaultCurrencies    = ['USD', 'SGD', 'EUR'];
const _selectedCurrenciesKey = 'forex_selected_currencies';
const int maxSelectedCurrencies = 5;

final selectedCurrenciesProvider =
    StateNotifierProvider<SelectedCurrenciesNotifier, List<String>>(
  (ref) => SelectedCurrenciesNotifier(),
);

class SelectedCurrenciesNotifier extends StateNotifier<List<String>> {
  SelectedCurrenciesNotifier() : super(List.from(_defaultCurrencies)) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_selectedCurrenciesKey);
      if (saved != null && saved.isNotEmpty) {
        state = saved;
      }
    } catch (_) {
      // Gunakan default
    }
  }

  Future<void> _persist(List<String> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_selectedCurrenciesKey, list);
    } catch (_) {}
  }

  void toggle(String code) {
    if (state.contains(code)) {
      final next = state.where((c) => c != code).toList();
      state = next;
      _persist(next);
    } else {
      if (state.length >= maxSelectedCurrencies) return;
      final next = [...state, code];
      state = next;
      _persist(next);
    }
  }

  void add(String code) {
    if (state.contains(code) || state.length >= maxSelectedCurrencies) return;
    final next = [...state, code];
    state = next;
    _persist(next);
  }

  void remove(String code) {
    if (!state.contains(code)) return;
    final next = state.where((c) => c != code).toList();
    state = next;
    _persist(next);
  }
}

// ════════════════════════════════════════════════════════════
//  COOLDOWN  (5 menit setelah refresh manual)
// ════════════════════════════════════════════════════════════

const _cooldownKey          = 'forex_cooldown_until_ms';
const _cooldownDuration     = Duration(minutes: 5);

final forexCooldownProvider =
    StateNotifierProvider<ForexCooldownNotifier, DateTime?>(
  (ref) => ForexCooldownNotifier(),
);

class ForexCooldownNotifier extends StateNotifier<DateTime?> {
  ForexCooldownNotifier() : super(null) {
    _loadCooldown();
  }

  Future<void> _loadCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms    = prefs.getInt(_cooldownKey);
      if (ms == null) return;
      final until = DateTime.fromMillisecondsSinceEpoch(ms);
      if (until.isAfter(DateTime.now())) {
        state = until;
      }
    } catch (_) {}
  }

  Future<void> start() async {
    final until = DateTime.now().add(_cooldownDuration);
    state = until;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cooldownKey, until.millisecondsSinceEpoch);
    } catch (_) {}
  }

  void tickCheck() {
    if (state != null && DateTime.now().isAfter(state!)) {
      state = null;
    }
  }

  bool get isActive {
    final s = state;
    return s != null && s.isAfter(DateTime.now());
  }

  /// Sisa detik cooldown (0 jika tidak aktif)
  int get remainingSeconds {
    final s = state;
    if (s == null) return 0;
    final diff = s.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

// ════════════════════════════════════════════════════════════
//  FOREX RATES
// ════════════════════════════════════════════════════════════

final forexRatesProvider = StateNotifierProvider<ForexRatesNotifier,
    AsyncValue<List<ForexRateModel>>>(
  (ref) {
    final service = ref.read(forexServiceProvider);
    final notifier = ForexRatesNotifier(service, ref);

    // Auto-reload ketika daftar mata uang berubah
    ref.listen<List<String>>(
      selectedCurrenciesProvider,
      (prev, next) => notifier.loadRates(next),
      fireImmediately: true,
    );

    return notifier;
  },
);

class ForexRatesNotifier
    extends StateNotifier<AsyncValue<List<ForexRateModel>>> {
  final ForexService _service;
  final Ref _ref;

  ForexRatesNotifier(this._service, this._ref)
      : super(const AsyncValue.loading());

  /// Load dari cache atau API (cache-first)
  Future<void> loadRates(List<String> currencies) async {
    if (currencies.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    // Jangan tampilkan loading jika sudah ada data (seamless update)
    final isFirstLoad = state is AsyncLoading;
    if (isFirstLoad) state = const AsyncValue.loading();

    try {
      final rates = await _service.fetchRates('IDR', currencies);
      final sorted = _sortRates(rates, currencies);
      if (mounted) state = AsyncValue.data(sorted);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Refresh paksa dari API (dipanggil tombol "Perbarui")
  Future<void> refreshRates() async {
    final currencies = _ref.read(selectedCurrenciesProvider);
    if (currencies.isEmpty) return;

    final cooldown = _ref.read(forexCooldownProvider.notifier);
    if (cooldown.isActive) return; // Masih dalam masa cooldown

    try {
      final rates = await _service.refreshRates('IDR', currencies);
      final sorted = _sortRates(rates, currencies);
      if (mounted) state = AsyncValue.data(sorted);
      await cooldown.start();
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  List<ForexRateModel> _sortRates(List<ForexRateModel> rates, List<String> order) {
    final Map<String, ForexRateModel> rateMap = {for (var r in rates) r.code.toUpperCase(): r};
    final List<ForexRateModel> sorted = [];
    for (var code in order) {
      final key = code.toUpperCase();
      if (rateMap.containsKey(key)) {
        sorted.add(rateMap[key]!);
      }
    }
    return sorted;
  }
}

// ════════════════════════════════════════════════════════════
//  LAST UPDATE TIME
// ════════════════════════════════════════════════════════════

final forexLastUpdateProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(forexRatesProvider); // invalidate ketika rates diperbarui
  return ref.read(forexServiceProvider).getLastCacheTime();
});
