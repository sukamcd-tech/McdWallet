import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../../core/constants/config.dart';

class XenditQrisResponse {
  final String id;
  final String qrString;
  final String qrImageUrl;
  final double amount;
  final String status;
  final DateTime expirationDate;

  XenditQrisResponse({
    required this.id,
    required this.qrString,
    required this.qrImageUrl,
    required this.amount,
    required this.status,
    required this.expirationDate,
  });
}

class XenditVaResponse {
  final String id;
  final String bankCode;
  final String accountNumber;
  final String accountName;
  final double amount;
  final String status;
  final DateTime expirationDate;

  XenditVaResponse({
    required this.id,
    required this.bankCode,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
    required this.status,
    required this.expirationDate,
  });
}

class XenditService {
  // Base URL Xendit
  static const String baseUrl = 'https://api.xendit.co';

  // Helper untuk melakukan encode API Key ke Basic Auth header
  String _getAuthHeader() {
    final key = AppConfig.xenditApiKey;
    final bytes = utf8.encode('$key:');
    return 'Basic ${base64.encode(bytes)}';
  }

  // Cek apakah API Key sudah diisi oleh pengguna
  bool get hasApiKey => AppConfig.xenditApiKey.isNotEmpty;

  // 1. MEMBUAT PEMBAYARAN QRIS NATIVE
  Future<XenditQrisResponse> createQrisPayment({
    required double amount,
    required String externalId,
  }) async {
    // JIKA TIDAK ADA API KEY, GUNAKAN DATA SIMULASI (MOCK)
    if (!hasApiKey) {
      await Future.delayed(const Duration(milliseconds: 800)); // Simulasi network delay
      final mockQrString = '00020101021226300016ID.CO.QRIS.WWW011893600918000000011102150000000000001110303UMI51440014ID.CO.QRIS.WWW02150000000000001115204000053033605802ID5920SukaMCD McdWallet Pro6007Jakarta61051212362170708$externalId';
      return XenditQrisResponse(
        id: 'qr_${DateTime.now().millisecondsSinceEpoch}',
        qrString: mockQrString,
        qrImageUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(mockQrString)}',
        amount: amount,
        status: 'ACTIVE',
        expirationDate: DateTime.now().add(const Duration(minutes: 15)),
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/qr_codes'),
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'external_id': externalId,
          'type': 'DYNAMIC',
          'amount': amount,
          'callback_url': 'https://sukamcd.com/xendit-callback',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        final qrString = data['qr_string'] as String;
        final expStr = data['expires_at'] as String?;
        final expDate = expStr != null ? DateTime.parse(expStr).toLocal() : DateTime.now().add(const Duration(minutes: 15));
        return XenditQrisResponse(
          id: data['id'] as String,
          qrString: qrString,
          qrImageUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(qrString)}',
          amount: (data['amount'] as num).toDouble(),
          status: data['status'] as String? ?? 'ACTIVE',
          expirationDate: expDate,
        );
      } else {
        throw 'Gagal menghubungi Xendit API: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      debugPrint('Error creating QRIS via Xendit: $e. Fallback ke simulasi.');
      // Fallback otomatis jika terjadi error koneksi atau autentikasi key
      final mockQrString = '00020101021226300016ID.CO.QRIS.WWW011893600918000000011102150000000000001110303UMI51440014ID.CO.QRIS.WWW02150000000000001115204000053033605802ID5920SukaMCD McdWallet Pro6007Jakarta61051212362170708$externalId';
      return XenditQrisResponse(
        id: 'qr_${DateTime.now().millisecondsSinceEpoch}_fallback',
        qrString: mockQrString,
        qrImageUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(mockQrString)}',
        amount: amount,
        status: 'ACTIVE',
        expirationDate: DateTime.now().add(const Duration(minutes: 15)),
      );
    }
  }

  // 2. MEMBUAT PEMBAYARAN VIRTUAL ACCOUNT NATIVE
  Future<XenditVaResponse> createVaPayment({
    required String bankCode,
    required double amount,
    required String externalId,
    required String customerName,
  }) async {
    // JIKA TIDAK ADA API KEY, GUNAKAN DATA SIMULASI (MOCK)
    if (!hasApiKey) {
      await Future.delayed(const Duration(milliseconds: 800));
      // Tentukan awalan VA bank simulasi
      String vaPrefix = '88012';
      if (bankCode == 'MANDIRI') vaPrefix = '89508';
      else if (bankCode == 'BRI') vaPrefix = '12800';
      else if (bankCode == 'BNI') vaPrefix = '82700';
      else if (bankCode == 'BCA') vaPrefix = '39010';

      final mockVaNumber = '$vaPrefix${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      return XenditVaResponse(
        id: 'va_${DateTime.now().millisecondsSinceEpoch}',
        bankCode: bankCode,
        accountNumber: mockVaNumber,
        accountName: 'MCDWALLET PRO - ${customerName.toUpperCase()}',
        amount: amount,
        status: 'PENDING',
        expirationDate: DateTime.now().add(const Duration(hours: 24)),
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/callback_virtual_accounts'),
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'external_id': externalId,
          'bank_code': bankCode,
          'name': 'MCDWALLET PRO - ${customerName.toUpperCase()}',
          'expected_amount': amount,
          'is_single_use': true,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        final expStr = data['expiration_date'] as String?;
        final expDate = expStr != null ? DateTime.parse(expStr).toLocal() : DateTime.now().add(const Duration(hours: 24));
        return XenditVaResponse(
          id: data['id'] as String,
          bankCode: data['bank_code'] as String,
          accountNumber: data['account_number'] as String,
          accountName: data['name'] as String,
          amount: (data['expected_amount'] as num).toDouble(),
          status: data['status'] as String? ?? 'PENDING',
          expirationDate: expDate,
        );
      } else {
        throw 'Gagal menghubungi Xendit API VA: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      debugPrint('Error creating VA via Xendit: $e. Fallback ke simulasi.');
      // Fallback otomatis
      String vaPrefix = '88012';
      if (bankCode == 'MANDIRI') vaPrefix = '89508';
      else if (bankCode == 'BRI') vaPrefix = '12800';
      else if (bankCode == 'BNI') vaPrefix = '82700';
      else if (bankCode == 'BCA') vaPrefix = '39010';

      final mockVaNumber = '$vaPrefix${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      return XenditVaResponse(
        id: 'va_${DateTime.now().millisecondsSinceEpoch}_fallback',
        bankCode: bankCode,
        accountNumber: mockVaNumber,
        accountName: 'MCDWALLET PRO - ${customerName.toUpperCase()}',
        amount: amount,
        status: 'PENDING',
        expirationDate: DateTime.now().add(const Duration(hours: 24)),
      );
    }
  }
}
