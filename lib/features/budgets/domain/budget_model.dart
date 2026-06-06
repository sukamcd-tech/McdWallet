import '../../transactions/domain/category_model.dart';

class BudgetModel {
  final String id;
  final String userId;
  final String? categoryId; // Null berarti anggaran global bulanan
  final double amountLimit;
  final String period; // 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  
  // Joined Model
  final CategoryModel? category;

  BudgetModel({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.amountLimit,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.category,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String?,
      amountLimit: (json['amount_limit'] as num).toDouble(),
      period: json['period'] as String? ?? 'monthly',
      startDate: DateTime.parse(json['start_date'] as String).toLocal(),
      endDate: DateTime.parse(json['end_date'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      category: json['categories'] != null ? CategoryModel.fromJson(json['categories'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'user_id': userId,
      'category_id': categoryId,
      'amount_limit': amountLimit,
      'period': period,
      'start_date': startDate.toIso8601String().substring(0, 10), // Hanya YYYY-MM-DD
      'end_date': endDate.toIso8601String().substring(0, 10),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    double? amountLimit,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    CategoryModel? category,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      amountLimit: amountLimit ?? this.amountLimit,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
    );
  }
}
