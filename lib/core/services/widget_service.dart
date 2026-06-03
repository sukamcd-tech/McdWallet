import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.sukamcd.wallet/widget');

  /// Memperbarui data widget di homescreen dengan total pengeluaran hari ini
  static Future<void> updateTodayExpense(double amount) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      await _channel.invokeMethod('updateTodayExpense', {
        'amount': amount,
        'date': dateStr,
      });
    } on PlatformException catch (_) {
      // Hiraukan error jika channel tidak terdaftar (misalnya berjalan di platform non-Android)
    }
  }

  /// Simpan user_id ke SharedPreferences agar widget bisa query Supabase secara mandiri
  static Future<void> saveUserId(String userId) async {
    try {
      await _channel.invokeMethod('saveUserId', {'userId': userId});
    } on PlatformException catch (_) {}
  }

  /// Hapus user_id saat logout agar widget tidak menampilkan data pengguna lain
  static Future<void> clearUserId() async {
    try {
      await _channel.invokeMethod('clearUserId');
    } on PlatformException catch (_) {}
  }
}

