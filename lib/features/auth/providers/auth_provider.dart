import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/auth_service.dart';
import '../domain/profile_model.dart';
import '../data/xendit_service.dart';

// Provider untuk mengakses AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthService(supabase);
});

// Provider untuk melacak apakah aplikasi sedang dalam mode pemulihan password (password recovery)
final passwordRecoveryModeProvider = StateProvider<bool>((ref) => false);

// Stream Provider untuk memantau User Supabase Auth yang sedang aktif
final authStateProvider = StreamProvider<User?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges.map((event) {
    if (event.event == AuthChangeEvent.passwordRecovery) {
      ref.read(passwordRecoveryModeProvider.notifier).state = true;
    }
    return event.session?.user;
  });
});

// StateNotifierProvider untuk mengelola profil publik pengguna aktif
final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel?>>((ref) {
  final service = ref.watch(authServiceProvider);
  final authState = ref.watch(authStateProvider);
  
  final notifier = ProfileNotifier(service);
  
  // Sinkronisasi otomatis ketika status login berubah
  authState.whenData((user) {
    if (user != null) {
      notifier.loadProfile(user.id);
    } else {
      notifier.clearProfile();
    }
  });
  
  return notifier;
});

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel?>> {
  final AuthService _authService;

  ProfileNotifier(this._authService) : super(const AsyncValue.loading());

  // Memuat data profil dari database
  Future<void> loadProfile(String userId) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authService.fetchProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Menghapus data profil saat user logout
  void clearProfile() {
    state = const AsyncValue.data(null);
  }

  // Memperbarui profil secara asinkron
  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? currency,
    String? subscriptionTier,
    String? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
  }) async {
    final currentProfile = state.value;
    if (currentProfile == null) return;

    state = const AsyncValue.loading();
    try {
      final updated = await _authService.updateProfile(
        userId: currentProfile.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
        currency: currency,
        subscriptionTier: subscriptionTier,
        subscriptionStatus: subscriptionStatus,
        subscriptionExpiresAt: subscriptionExpiresAt,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Provider untuk mengakses XenditService
final xenditServiceProvider = Provider<XenditService>((ref) {
  return XenditService();
});

// Provider untuk memeriksa apakah user berstatus PRO aktif
final isPremiumProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(profileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile?.isPro ?? false,
    orElse: () => false,
  );
});
