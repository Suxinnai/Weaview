import 'message_attachment.dart';
import 'model_comparison_result.dart';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.attachments = const [],
    this.reasoning = '',
    this.translation = '',
    this.isThinking = false,
    this.activity = '',
    this.comparisonResults = const [],
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

  factory ChatMessage.modelComparison({
    required List<ModelComparisonResult> results,
    bool isThinking = true,
  }) => ChatMessage(
    role: 'model',
    content: '',
    isThinking: isThinking,
    activity: 'modelComparison',
    comparisonResults: results,
  );

  factory ChatMessage.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ChatMessage(
      role: map['role']?.toString() == 'model' ? 'model' : 'user',
      content: map['content']?.toString() ?? '',
      reasoning: map['reasoning']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
      activity: map['activity']?.toString() ?? '',
      comparisonResults: (map['comparisonResults'] as List? ?? [])
          .map(ModelComparisonResult.fromJson)
          .toList(),
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
  List<ModelComparisonResult> comparisonResults;

  bool get isImageGenerating => isThinking && activity == 'imageGeneration';
  bool get isModelComparison => activity == 'modelComparison';

  ChatMessage copy() => ChatMessage(
    role: role,
    content: content,
    reasoning: reasoning,
    translation: translation,
    isThinking: isThinking,
    activity: activity,
    comparisonResults: comparisonResults,
    attachments: attachments.map((a) => a.copy()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'reasoning': reasoning,
    'translation': translation,
    'activity': activity,
    'comparisonResults': comparisonResults
        .map((item) => item.toJson())
        .toList(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };
}
