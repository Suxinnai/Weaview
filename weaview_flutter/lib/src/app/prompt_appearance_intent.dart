class PromptAppearanceIntent {
  const PromptAppearanceIntent._();

  static Map<String, dynamic> parse(String value) {
    final prompt = value.toLowerCase();
    final asksBubble = _hasAny(prompt, const ['气泡', '消息泡', '对话泡', 'bubble']);
    final asksBackground = _hasAny(prompt, const [
      '背景',
      '底色',
      '画布',
      'background',
    ]);
    final asksText = _hasAny(prompt, const [
      '文字',
      '文本',
      '字体',
      '字色',
      'font',
      'text',
    ]);
    final asksAlignment = _hasAny(prompt, const [
      '对齐',
      '居中',
      '靠左',
      '靠右',
      'align',
      'center',
      'left',
      'right',
    ]);
    final asksReset = _hasAny(prompt, const [
      '恢复默认',
      '默认主题',
      '重置',
      '还原',
      'reset',
    ]);
    if (!asksBubble &&
        !asksBackground &&
        !asksText &&
        !asksAlignment &&
        !asksReset) {
      return const {};
    }

    final args = <String, dynamic>{};
    if (asksReset) {
      args['resetTheme'] = true;
    }
    if (asksText) {
      final color = _colorHexFromPrompt(prompt);
      if (color != null) args['textColor'] = color;
      if (_hasAny(prompt, const ['衬线', 'serif'])) {
        args['fontFamily'] = 'serif';
      }
      if (_hasAny(prompt, const ['无衬线', 'sans'])) {
        args['fontFamily'] = 'sans';
      }
      if (_hasAny(prompt, const ['斜体', 'italic'])) {
        args['fontStyle'] = 'italic';
      }
      if (_hasAny(prompt, const ['正常', 'normal'])) {
        args['fontStyle'] = 'normal';
      }
      if (_hasAny(prompt, const ['粗体', '加粗', 'bold'])) {
        args['fontWeight'] = 'bold';
      }
    }
    if (asksBackground) {
      args['backgroundColor'] = _colorHexFromPrompt(prompt) ?? '#F6F1FF';
      final lowerColor = args['backgroundColor']!.toString().toLowerCase();
      if (lowerColor == '#000000' ||
          lowerColor == '#111827' ||
          _hasAny(prompt, const ['黑色', '深色', '暗色', 'dark'])) {
        args['isDark'] = true;
      } else if (_hasAny(prompt, const ['白色', '浅色', '亮色', 'light'])) {
        args['isDark'] = false;
      }
    }
    if (asksBubble) {
      final removesBubble = _hasAny(prompt, const [
        '去掉',
        '去除',
        '移除',
        '取消',
        '不要',
        '无气泡',
        '隐藏',
        'remove',
        'hide',
        'no bubble',
      ]);
      final opacity = _opacityFromPrompt(prompt);
      if (removesBubble || opacity == 0) {
        args['bubbleStyle'] = 'none';
        args['bubbleOpacity'] = 0.0;
      } else {
        if (_hasAny(prompt, const ['透明', 'glass'])) {
          args['bubbleStyle'] = 'glass';
          args['bubbleOpacity'] = opacity ?? 0.18;
        }
        final color = _colorHexFromPrompt(prompt);
        if (color != null) args['bubbleColor'] = color;
      }
    }
    if (asksAlignment) {
      if (_hasAny(prompt, const ['居中', 'center'])) {
        args['messageAlignment'] = 'center';
      } else if (_hasAny(prompt, const ['靠右', 'right'])) {
        args['messageAlignment'] = 'right';
      } else if (_hasAny(prompt, const ['靠左', 'left'])) {
        args['messageAlignment'] = 'left';
      }
    }
    return args;
  }

  static bool _hasAny(String prompt, List<String> terms) {
    return terms.any(prompt.contains);
  }

  static String? _colorHexFromPrompt(String prompt) {
    const colors = {
      '粉': '#DB2777',
      'pink': '#DB2777',
      '红': '#DC2626',
      'red': '#DC2626',
      '蓝': '#2563EB',
      'blue': '#2563EB',
      '绿': '#059669',
      'green': '#059669',
      '紫': '#7C3AED',
      'purple': '#7C3AED',
      '黄': '#CA8A04',
      'yellow': '#CA8A04',
      '橙': '#EA580C',
      'orange': '#EA580C',
      '黑': '#111827',
      'black': '#111827',
      '白': '#FFFFFF',
      'white': '#FFFFFF',
      '灰': '#6B7280',
      'gray': '#6B7280',
      'grey': '#6B7280',
    };
    for (final entry in colors.entries) {
      if (prompt.contains(entry.key)) return entry.value;
    }
    final hex = RegExp(
      r'#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})',
    ).firstMatch(prompt);
    return hex?.group(0)?.toUpperCase();
  }

  static double? _opacityFromPrompt(String prompt) {
    final percent = RegExp(r'(\d{1,3})\s*%').firstMatch(prompt);
    if (percent != null) {
      final value = int.tryParse(percent.group(1)!);
      if (value != null) return (value / 100).clamp(0.0, 1.0);
    }
    final decimal = RegExp(
      r'(?:透明度|opacity)[^\d]*(0(?:\.\d+)?|1(?:\.0+)?)',
    ).firstMatch(prompt);
    if (decimal != null) {
      final value = double.tryParse(decimal.group(1)!);
      if (value != null) return value.clamp(0.0, 1.0);
    }
    if (_hasAny(prompt, const ['完全透明', '全透明'])) return 0.0;
    return null;
  }
}
