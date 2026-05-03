class ModelAssignment {
  const ModelAssignment({
    required this.provider,
    required this.model,
    required this.prompt,
  });

  factory ModelAssignment.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ModelAssignment(
      provider: map['provider']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      prompt: map['prompt']?.toString() ?? '',
    );
  }

  final String provider;
  final String model;
  final String prompt;

  static Map<String, ModelAssignment> defaults() {
    return const {
      'chat': ModelAssignment(
        provider: '',
        model: '',
        prompt: '你是一个有用、有条理、有创造力的人工智能助手。',
      ),
      'title': ModelAssignment(
        provider: '',
        model: '',
        prompt: '请用不超过10个字概括以下对话的核心内容，直接输出标题，不需要前缀。',
      ),
      'suggest': ModelAssignment(
        provider: '',
        model: '',
        prompt: '根据对话历史，简明扼要地提供3个用户可能想说的简短后续问题。',
      ),
      'translate': ModelAssignment(
        provider: '',
        model: '',
        prompt: '你是一个专业的翻译人员，请将输入的文本翻译成目标语言，保持原意，语言流畅。',
      ),
    };
  }

  ModelAssignment copyWith({String? provider, String? model, String? prompt}) {
    return ModelAssignment(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'model': model,
    'prompt': prompt,
  };
}
