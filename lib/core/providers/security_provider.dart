import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

class SecurityState {
  final bool isLocked;
  final bool hasPin;
  final bool isBiometricsSupported;
  final bool isSecurityEnabled;

  SecurityState({
    required this.isLocked,
    required this.hasPin,
    required this.isBiometricsSupported,
    required this.isSecurityEnabled,
  });

  SecurityState copyWith({
    bool? isLocked,
    bool? hasPin,
    bool? isBiometricsSupported,
    bool? isSecurityEnabled,
  }) {
    return SecurityState(
      isLocked: isLocked ?? this.isLocked,
      hasPin: hasPin ?? this.hasPin,
      isBiometricsSupported: isBiometricsSupported ?? this.isBiometricsSupported,
      isSecurityEnabled: isSecurityEnabled ?? this.isSecurityEnabled,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  final SecurityService _service;

  SecurityNotifier(this._service)
      : super(SecurityState(
          isLocked: false,
          hasPin: false,
          isBiometricsSupported: false,
          isSecurityEnabled: false,
        )) {
    init();
  }

  // Menginisialisasi status keamanan lokal
  Future<void> init() async {
    final hasPin = await _service.hasPin();
    final isBioSupported = await _service.isBiometricsSupported();
    
    // Ambil preferensi privasi & keamanan global
    final prefs = await SharedPreferences.getInstance();
    final isSecEnabled = prefs.getBool('security_enabled') ?? false;
    
    state = SecurityState(
      isLocked: hasPin && isSecEnabled, // Hanya dikunci jika PIN sudah disetel & fitur aktif
      hasPin: hasPin,
      isBiometricsSupported: isBioSupported,
      isSecurityEnabled: isSecEnabled,
    );
  }

  // Membuka kunci aplikasi
  void unlock() {
    state = state.copyWith(isLocked: false);
  }

  // Mengunci aplikasi kembali (misal saat masuk background)
  void lock() {
    if (state.hasPin && state.isSecurityEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }

  // Mengubah status fitur keamanan aktif/nonaktif
  Future<void> toggleSecurityEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('security_enabled', enabled);
    state = state.copyWith(
      isSecurityEnabled: enabled,
      isLocked: enabled ? state.hasPin : false, // Langsung buka kunci jika dinonaktifkan
    );
  }

  // Merefresh status keamanan
  Future<void> refresh() async {
    await init();
  }
}

final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final service = ref.watch(securityServiceProvider);
  return SecurityNotifier(service);
});
