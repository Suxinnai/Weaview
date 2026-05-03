import 'chat_message.dart';

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  factory ChatSession.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ChatSession(
      id: map['id']?.toString() ?? DateTime.now().toString(),
      title: map['title']?.toString() ?? '未命名梦境',
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      messages: (map['messages'] as List? ?? [])
          .map(ChatMessage.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final int updatedAt;
  final List<ChatMessage> messages;

  ChatSession copyWith({
    String? id,
    String? title,
    int? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
}
