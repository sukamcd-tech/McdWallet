class SavingsGoalModel {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String color;
  final String icon;
  final String savingInterval; // 'custom', 'daily', 'weekly', 'monthly'
  final double savingAmountPerInterval;
  final DateTime createdAt;

  SavingsGoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    required this.color,
    required this.icon,
    this.savingInterval = 'custom',
    this.savingAmountPerInterval = 0.0,
    required this.createdAt,
  });

  double get percentage {
    if (targetAmount <= 0) return 0.0;
    final pct = currentAmount / targetAmount;
    return pct > 1.0 ? 1.0 : pct;
  }

  bool get isAchieved => currentAmount >= targetAmount;

  // Menghitung perkiraan sisa durasi pencapaian berdasarkan target nominal & rencana alokasi rutin
  int get remainingIntervals {
    if (savingAmountPerInterval <= 0) return 0;
    final remainingAmount = targetAmount - currentAmount;
    if (remainingAmount <= 0) return 0;
    return (remainingAmount / savingAmountPerInterval).ceil();
  }

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingsGoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0.0,
      targetDate: json['target_date'] != null ? DateTime.parse(json['target_date'] as String).toLocal() : null,
      color: json['color'] as String? ?? '#FF9500',
      icon: json['icon'] as String? ?? 'savings',
      savingInterval: json['saving_interval'] as String? ?? 'custom',
      savingAmountPerInterval: (json['saving_amount_per_interval'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate?.toIso8601String().substring(0, 10), // Hanya YYYY-MM-DD
      'color': color,
      'icon': icon,
      'saving_interval': savingInterval,
      'saving_amount_per_interval': savingAmountPerInterval,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  SavingsGoalModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? color,
    String? icon,
    String? savingInterval,
    double? savingAmountPerInterval,
    DateTime? createdAt,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      savingInterval: savingInterval ?? this.savingInterval,
      savingAmountPerInterval: savingAmountPerInterval ?? this.savingAmountPerInterval,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
