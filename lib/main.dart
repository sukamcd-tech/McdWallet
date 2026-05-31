import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/colors.dart';
import 'core/constants/config.dart';
import 'core/theme/theme.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/providers/security_provider.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/pin_setup_screen.dart';
import 'features/auth/presentation/pin_entry_screen.dart';
import 'core/services/error_logger_service.dart';
import 'core/providers/haptic_provider.dart';
import 'core/utils/haptics.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set style status bar & navigation bar global
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x0C000000), // Transparansi gelap tipis (5%) agar terpisah dari background putih
      statusBarIconBrightness: Brightness.dark, // Ikon/teks status bar berwarna gelap agar terbaca jelas
      statusBarBrightness: Brightness.light, // iOS (Light content background -> Dark status bar text)
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Inisialisasi Logger Global
  await ErrorLoggerService().initialize();

  // Inisialisasi lokalisasi penanggalan Indonesia (id_ID)
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi Firebase & FCM (opsional jika setup android/iOS belum dilakukan)
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase Initialization failed: $e');
  }

  // Inisialisasi Supabase secara aman (tidak crash jika key belum diganti)
  try {
    if (AppConfig.supabaseUrl.startsWith('http')) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );

      // Inisialisasi notifikasi lokal & FCM
      await NotificationService().initialize(Supabase.instance.client);
    }
  } catch (e) {
    debugPrint('Supabase Initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final securityState = ref.read(securityProvider);
    if (!securityState.isSecurityEnabled) {
      // Jika fitur keamanan dinonaktifkan, pastikan overlay mati dan abaikan penguncian
      setState(() {
        _isMinimized = false;
      });
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
      setState(() {
        _isMinimized = true;
      });
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        _isMinimized = false;
      });
      if (_pausedAt != null) {
        final diff = DateTime.now().difference(_pausedAt!);
        if (diff.inMinutes >= 3) {
          ref.read(securityProvider.notifier).lock();
        }
        _pausedAt = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sinkronisasi status getaran taktil global
    AppHaptics.enabled = ref.watch(hapticProvider);

    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'McdWallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Mengaktifkan tema Off-White & Charcoal Premium
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (_isMinimized)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      home: authState.when(
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (err, _) => Scaffold(
          body: Center(
            child: Text(
              'Terjadi kesalahan koneksi sistem:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
        data: (user) {
          if (user != null) {
            // Cek status keamanan lokal (PIN & Biometric)
            final securityState = ref.watch(securityProvider);
            
            if (!securityState.isSecurityEnabled) {
              // Jika fitur privasi dimatikan, langsung masuk MainLayout
              return const MainLayout();
            } else if (!securityState.hasPin) {
              // Wajib setel PIN jika belum ada
              return const PinSetupScreen();
            } else if (securityState.isLocked) {
              // Layar Lock Screen jika terkunci
              return const PinEntryScreen();
            } else {
              // Layar Utama jika sukses terbuka
              return const MainLayout();
            }
          } else {
            // Belum login -> Tampilkan Layar Login
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
