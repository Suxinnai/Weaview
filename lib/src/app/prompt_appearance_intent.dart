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
      args['backgroundColor'] =
          _colorHexFromPrompt(prompt) ?? _backgroundForMood(prompt);
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
        if (color != null) {
          args['bubbleColor'] = color;
        } else if (!args.containsKey('bubbleStyle')) {
          args
            ..['bubbleStyle'] = 'glass'
            ..['bubbleOpacity'] = 0.16
            ..['assistantBubbleColor'] = '#DDEFE9'
            ..['userBubbleColor'] = '#E8E2F3';
        }
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

  static bool isDirectAppearanceRequest(String value) {
    if (parse(value).isEmpty) return false;
    final prompt = value.toLowerCase().trim();
    if (prompt.runes.length <= 12) return true;
    return _hasAny(prompt, const [
      '改',
      '换',
      '设置',
      '调整',
      '变成',
      '切换',
      '去掉',
      '去除',
      '取消',
      '恢复',
      '重置',
      'make ',
      'change ',
      'set ',
      'use ',
      'remove ',
      'reset',
    ]);
  }

  static String completionMessage(Map<String, dynamic> args) {
    if (args['resetTheme'] == true) {
      return '界面已经回到最初的样子，留白与颜色重新安静下来。';
    }
    final changedBackground = args.containsKey('backgroundColor');
    final changedBubble = args.keys.any(
      (key) => key.contains('Bubble') || key == 'bubbleStyle',
    );
    final changedFont = args.keys.any(
      (key) => const {
        'textColor',
        'fontFamily',
        'fontStyle',
        'fontWeight',
      }.contains(key),
    );
    final changedAlignment = args.containsKey('messageAlignment');
    final groups = <String>[
      if (changedBackground) '背景',
      if (changedBubble) '气泡',
      if (changedFont) '文字',
      if (changedAlignment) '对齐方式',
    ];
    if (groups.length > 1) {
      return '${groups.join('、')}已经一起更新，整片对话空间重新有了呼吸。';
    }
    if (changedBackground) {
      return '背景已经换成一层清浅雾色，像雨后的晨光一样安静。';
    }
    if (changedBubble) {
      return '气泡已经换上轻透的质感，柔和得像把对话盛进一层晨露。';
    }
    if (changedFont) {
      return '文字样式已经更新，用户与助手会一起保持同一种节奏。';
    }
    if (changedAlignment) return '对话的排列已经调整妥当。';
    return '界面样式已经更新。';
  }

  static bool _hasAny(String prompt, List<String> terms) {
    return terms.any(prompt.contains);
  }

  static String _backgroundForMood(String prompt) {
    if (_hasAny(prompt, const ['夜', '星空', '深色', '暗色', 'dark'])) {
      return '#17232B';
    }
    if (_hasAny(prompt, const ['暖', '奶油', '夕阳', '米色'])) {
      return '#FFF8EF';
    }
    if (_hasAny(prompt, const ['紫', '梦', '薰衣草'])) return '#F5F2FA';
    if (_hasAny(prompt, const ['蓝', '雨', '雾', '天空'])) return '#F1F7F8';
    return '#F2FAF7';
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
