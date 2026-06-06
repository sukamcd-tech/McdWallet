class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String type; // 'income' or 'expense'
  final String color;
  final String icon;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      color: json['color'] as String? ?? '#607D8B',
      icon: json['icon'] as String? ?? 'category',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'user_id': userId,
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  CategoryModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
