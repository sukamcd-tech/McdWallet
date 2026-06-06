class ProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String currency;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.currency,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      currency: json['currency'] as String? ?? 'IDR',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'currency': currency,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? currency,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
