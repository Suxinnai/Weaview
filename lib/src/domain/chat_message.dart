import 'message_attachment.dart';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.attachments = const [],
    this.reasoning = '',
    this.translation = '',
    this.isThinking = false,
  });

  factory ChatMessage.user(
    String content, {
    List<MessageAttachment> attachments = const [],
  }) => ChatMessage(role: 'user', content: content, attachments: attachments);

  factory ChatMessage.model(
    String content, {
    String reasoning = '',
    bool isThinking = false,
  }) => ChatMessage(
    role: 'model',
    content: content,
    reasoning: reasoning,
    isThinking: isThinking,
  );

  factory ChatMessage.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ChatMessage(
      role: map['role']?.toString() == 'model' ? 'model' : 'user',
      content: map['content']?.toString() ?? '',
      reasoning: map['reasoning']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
      attachments: (map['attachments'] as List? ?? [])
          .map(MessageAttachment.fromJson)
          .toList(),
    );
  }

  String role;
  String content;
  String reasoning;
  String translation;
  bool isThinking;
  List<MessageAttachment> attachments;

  ChatMessage copy() => ChatMessage(
    role: role,
    content: content,
    reasoning: reasoning,
    translation: translation,
    isThinking: isThinking,
    attachments: attachments.map((a) => a.copy()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'reasoning': reasoning,
    'translation': translation,
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };
}
