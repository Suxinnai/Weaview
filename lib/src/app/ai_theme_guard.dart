class AiThemeGuard {
  const AiThemeGuard._();

  static Map<String, dynamic> guard(
    Map<String, dynamic> args, {
    String? userPrompt,
  }) {
    final prompt = userPrompt?.toLowerCase() ?? '';
    if (prompt.isEmpty) return args;
    final asksBubble = _promptHasAny(prompt, const [
      '气泡',
      '消息泡',
      '对话泡',
      'bubble',
      'bubbles',
    ]);
    final asksBackground = _promptHasAny(prompt, const [
      '背景',
      '底色',
      '画布',
      '壁纸',
      'background',
      'canvas',
      '深色',
      '浅色',
      '暗色',
      '亮色',
      '黑色背景',
      '白色背景',
    ]);
    final asksText = _promptHasAny(prompt, const [
      '文字',
      '文本',
      '字体',
      '字色',
      '字号',
      '白字',
      '黑字',
      '红字',
      '蓝字',
      'font',
      'text',
      'serif',
      'sans',
      '粗体',
      '斜体',
    ]);
    final asksAlignment = _promptHasAny(prompt, const [
      '对齐',
      '居中',
      '靠左',
      '靠右',
      'align',
      'center',
      'left',
      'right',
    ]);
    final hasSpecificStyleGroup =
        asksBubble || asksBackground || asksText || asksAlignment;
    if (!hasSpecificStyleGroup) return args;

    final removesBubble =
        asksBubble &&
        _promptHasAny(prompt, const [
          '去掉',
          '去除',
          '移除',
          '取消',
          '不要',
          '无气泡',
          '隐藏',
          'remove',
          'hide',
          'disable',
          'without bubble',
          'no bubble',
        ]);

    final asksReset = _promptHasAny(prompt, const [
      '恢复默认',
      '默认主题',
      '重置',
      '还原',
      'reset',
      'default',
      'restore',
    ]);
    final asksWholeTheme = _promptHasAny(prompt, const [
      '主题',
      'theme',
      '全局',
      '整体',
      '全部',
      '所有',
      '整套',
    ]);
    final guarded = Map<String, dynamic>.from(args);
    if (!asksReset || hasSpecificStyleGroup && !asksWholeTheme) {
      guarded.remove('resetTheme');
    }
    if (!asksBackground) {
      guarded.remove('backgroundColor');
      guarded.remove('isDark');
    }
    if (!asksText) {
      guarded.remove('textColor');
      guarded.remove('fontFamily');
      guarded.remove('fontStyle');
      guarded.remove('fontWeight');
    }
    if (!asksAlignment) guarded.remove('messageAlignment');
    if (!asksBubble) {
      guarded.remove('bubbleStyle');
      guarded.remove('bubbleColor');
      guarded.remove('assistantBubbleColor');
      guarded.remove('userBubbleColor');
      guarded.remove('bubbleOpacity');
      guarded.remove('assistantBubbleOpacity');
      guarded.remove('userBubbleOpacity');
    } else if (removesBubble) {
      guarded['bubbleStyle'] = 'none';
      guarded['bubbleOpacity'] = 0.0;
      guarded.remove('bubbleColor');
      guarded.remove('assistantBubbleColor');
      guarded.remove('userBubbleColor');
    }
    return guarded;
  }

  static bool _promptHasAny(String prompt, List<String> terms) {
    return terms.any(prompt.contains);
  }
}
