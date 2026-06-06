class ChatMessageModel {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
