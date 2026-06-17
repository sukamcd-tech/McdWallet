class ProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String currency;
  final String subscriptionTier; // 'free' or 'pro'
  final String subscriptionStatus; // 'active', 'inactive', etc.
  final DateTime? subscriptionExpiresAt;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.currency,
    required this.subscriptionTier,
    required this.subscriptionStatus,
    this.subscriptionExpiresAt,
    required this.createdAt,
  });

  bool get isPro => subscriptionTier == 'pro' && subscriptionStatus == 'active';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      currency: json['currency'] as String? ?? 'IDR',
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      subscriptionStatus: json['subscription_status'] as String? ?? 'inactive',
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String).toLocal()
          : null,
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
      'subscription_tier': subscriptionTier,
      'subscription_status': subscriptionStatus,
      'subscription_expires_at': subscriptionExpiresAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? currency,
    String? subscriptionTier,
    String? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currency: currency ?? this.currency,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
