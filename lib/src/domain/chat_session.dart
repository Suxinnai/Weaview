import 'chat_message.dart';

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
    this.pinned = false,
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
      pinned: map['pinned'] == true,
    );
  }

  final String id;
  final String title;
  final int updatedAt;
  final List<ChatMessage> messages;
  final bool pinned;

  ChatSession copyWith({
    String? id,
    String? title,
    int? updatedAt,
    List<ChatMessage>? messages,
    bool? pinned,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt,
    'messages': messages.map((m) => m.toJson()).toList(),
    'pinned': pinned,
  };
}
