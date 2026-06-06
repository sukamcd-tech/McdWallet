class WalletModel {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final String color;
  final String icon;
  final DateTime createdAt;
  final String currencyCode; // Kode mata uang dasar dompet (IDR, USD, dll.)

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.currencyCode = 'IDR',
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num).toDouble(),
      color: json['color'] as String? ?? '#4CAF50',
      icon: json['icon'] as String? ?? 'account_balance_wallet',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      currencyCode: json['currency_code'] as String? ?? 'IDR',
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'user_id': userId,
      'name': name,
      'balance': balance,
      'color': color,
      'icon': icon,
      'created_at': createdAt.toUtc().toIso8601String(),
      'currency_code': currencyCode,
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  WalletModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? balance,
    String? color,
    String? icon,
    DateTime? createdAt,
    String? currencyCode,
  }) {
    return WalletModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
