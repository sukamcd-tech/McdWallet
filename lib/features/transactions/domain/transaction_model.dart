import 'wallet_model.dart';
import 'category_model.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String walletId;
  final String? categoryId; // Null if type = 'transfer'
  final double amount;
  final double? amountInIdr; // Setara Rupiah saat transaksi terjadi (untuk valas)
  final double? targetAmount; // Nilai nominal terkonversi yang diterima di dompet tujuan (untuk transfer valas)
  final String type; // 'income', 'expense', 'transfer'
  final String? description;
  final DateTime date;
  final String? attachmentPath;
  final String? toWalletId; // Only if type = 'transfer'
  final double? adminFee; // Admin fee for transfer
  final DateTime createdAt;
  
  // Joined Models (Optional, loaded via DB select joins if required)
  final WalletModel? wallet;
  final WalletModel? toWallet;
  final CategoryModel? category;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.walletId,
    this.categoryId,
    required this.amount,
    this.amountInIdr,
    this.targetAmount,
    required this.type,
    this.description,
    required this.date,
    this.attachmentPath,
    this.toWalletId,
    this.adminFee,
    required this.createdAt,
    this.wallet,
    this.toWallet,
    this.category,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      walletId: json['wallet_id'] as String,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      amountInIdr: json['amount_in_idr'] != null ? (json['amount_in_idr'] as num).toDouble() : null,
      targetAmount: json['target_amount'] != null ? (json['target_amount'] as num).toDouble() : null,
      type: json['type'] as String,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String).toLocal(),
      attachmentPath: json['attachment_path'] as String?,
      toWalletId: json['to_wallet_id'] as String?,
      adminFee: json['admin_fee'] != null ? (json['admin_fee'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      wallet: json['wallets'] != null ? WalletModel.fromJson(json['wallets'] as Map<String, dynamic>) : null,
      toWallet: json['to_wallets'] != null ? WalletModel.fromJson(json['to_wallets'] as Map<String, dynamic>) : null,
      category: json['categories'] != null ? CategoryModel.fromJson(json['categories'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'user_id': userId,
      'wallet_id': walletId,
      'category_id': categoryId,
      'amount': amount,
      'amount_in_idr': amountInIdr,
      'target_amount': targetAmount,
      'type': type,
      'description': description,
      'date': date.toUtc().toIso8601String(),
      'attachment_path': attachmentPath,
      'to_wallet_id': toWalletId,
      'admin_fee': adminFee,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? walletId,
    String? categoryId,
    double? amount,
    double? amountInIdr,
    double? targetAmount,
    String? type,
    String? description,
    DateTime? date,
    String? attachmentPath,
    String? toWalletId,
    double? adminFee,
    DateTime? createdAt,
    WalletModel? wallet,
    WalletModel? toWallet,
    CategoryModel? category,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      amountInIdr: amountInIdr ?? this.amountInIdr,
      targetAmount: targetAmount ?? this.targetAmount,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      toWalletId: toWalletId ?? this.toWalletId,
      adminFee: adminFee ?? this.adminFee,
      createdAt: createdAt ?? this.createdAt,
      wallet: wallet ?? this.wallet,
      toWallet: toWallet ?? this.toWallet,
      category: category ?? this.category,
    );
  }
}
