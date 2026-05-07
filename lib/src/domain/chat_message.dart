import 'message_attachment.dart';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.attachments = const [],
    this.reasoning = '',
    this.translation = '',
    this.isThinking = false,
    this.activity = '',
  });

  factory ChatMessage.user(
    String content, {
    List<MessageAttachment> attachments = const [],
  }) => ChatMessage(role: 'user', content: content, attachments: attachments);

  factory ChatMessage.model(
    String content, {
    String reasoning = '',
    bool isThinking = false,
    String activity = '',
  }) => ChatMessage(
    role: 'model',
    content: content,
    reasoning: reasoning,
    isThinking: isThinking,
    activity: activity,
  );

  factory ChatMessage.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ChatMessage(
      role: map['role']?.toString() == 'model' ? 'model' : 'user',
      content: map['content']?.toString() ?? '',
      reasoning: map['reasoning']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
      activity: map['activity']?.toString() ?? '',
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
  String activity;
  List<MessageAttachment> attachments;

  bool get isImageGenerating => isThinking && activity == 'imageGeneration';

  ChatMessage copy() => ChatMessage(
    role: role,
    content: content,
    reasoning: reasoning,
    translation: translation,
    isThinking: isThinking,
    activity: activity,
    attachments: attachments.map((a) => a.copy()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'reasoning': reasoning,
    'translation': translation,
    'activity': activity,
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };
}
