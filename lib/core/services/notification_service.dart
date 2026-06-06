import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isLocalInitialized = false;
  bool _isFirebaseInitialized = false;

  // Inisialisasi local notifications dan listener FCM
  Future<void> initialize(SupabaseClient supabase) async {
    if (_isLocalInitialized) return;

    // 1. SETUP LOCAL NOTIFICATIONS FOR IN-APP & BACKGROUND ALERTS
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );
      
      // Android channel khusus untuk alarm anggaran
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'budget_alerts',
            'Alur Anggaran McdWallet',
            description: 'Notifikasi peringatan batas pengeluaran finansial.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
      _isLocalInitialized = true;
      debugPrint('Local Notifications initialized successfully.');
    } catch (e) {
      debugPrint('Failed to initialize Local Notifications: $e');
    }

    // 2. SETUP FCM (FIREBASE CLOUD MESSAGING)
    try {
      // Cek apakah Firebase sudah terinisialisasi
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
        
        // Minta izin push notification FCM (iOS & Android 13+)
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        // Ambil token FCM dan simpan ke profil di database Supabase
        await registerFcmToken(supabase);

        // Subscribe ke topik pembaruan rilis
        try {
          await messaging.subscribeToTopic('mcdwallet_updates');
          debugPrint('Subscribed to topic: mcdwallet_updates');
        } catch (topicError) {
          debugPrint('Failed to subscribe to topic mcdwallet_updates: $topicError');
        }

        // Listener pesan FCM saat aplikasi di foreground
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('FCM Foreground message received: ${message.notification?.title}');
          if (message.notification != null) {
            showNotification(
              message.notification!.title ?? 'Notifikasi Baru',
              message.notification!.body ?? '',
            );
          }
        });
      }
    } catch (e) {
      // Firebase belum setup/kredensial google-services.json belum ada di native
      debugPrint('Firebase FCM Listener bypass (not configured yet): $e');
    }
  }

  // Registrasi token FCM ke Supabase secara aman
  Future<void> registerFcmToken(SupabaseClient supabase) async {
    if (!_isFirebaseInitialized) return;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        
        // Simpan token ke Supabase secara aman (bypass jika kolom fcm_token belum dibuat di user DB)
        try {
          await supabase.from('profiles').update({
            'fcm_token': token,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', user.id);
          debugPrint('FCM Token registered to Supabase successfully.');
        } catch (dbError) {
          debugPrint('DB bypass: profiles table column "fcm_token" does not exist yet: $dbError');
        }
      }
    } catch (e) {
      debugPrint('Failed to register FCM Token: $e');
    }
  }

  // Tampilkan notifikasi push lokal instan
  Future<void> showNotification(String title, String body, {String? payload}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Alur Anggaran McdWallet',
      channelDescription: 'Notifikasi peringatan batas pengeluaran finansial.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        DateTime.now().hashCode,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  // Tampilkan notifikasi peringatan anggaran terlampaui
  Future<void> showBudgetExceededNotification({
    required String categoryName,
    required double limitAmount,
    required double spentAmount,
  }) async {
    final title = '⚠️ Batas Anggaran Terlampaui!';
    final body = 'Pengeluaran untuk kategori "$categoryName" telah mencapai Rp ${spentAmount.toStringAsFixed(0)} '
        'dari batas maksimal Rp ${limitAmount.toStringAsFixed(0)}.';
    
    await showNotification(title, body);
  }

  // Tampilkan notifikasi peringatan ambang batas anggaran (50%, 70%, 90%)
  Future<void> showBudgetWarningNotification({
    required String categoryName,
    required int thresholdPercentage,
    required double limitAmount,
    required double spentAmount,
  }) async {
    final title = '⚠️ Peringatan Anggaran ($thresholdPercentage%)';
    final body = 'Pengeluaran untuk "$categoryName" telah terpakai Rp ${spentAmount.toStringAsFixed(0)} '
        '($thresholdPercentage% dari batas maksimal Rp ${limitAmount.toStringAsFixed(0)}).';
    
    await showNotification(title, body);
  }
}
