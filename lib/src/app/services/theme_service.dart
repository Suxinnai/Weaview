import 'package:flutter/material.dart';

import '../../core/app_utils.dart';
import '../ai_theme_guard.dart';
import '../app_constants.dart';
import '../prompt_appearance_intent.dart';
import '../weaview_preferences.dart';

class ThemeService {
  ThemeService();

  ThemeMode themeMode = ThemeMode.system;
  Color? backgroundOverride;
  Color? textOverride;
  Color? assistantBubbleOverride;
  Color? userBubbleOverride;
  Color accentColor = accentMint;
  String fontMood = 'sans';
  String fontStyleMood = 'normal';
  String fontWeightMood = 'normal';
  String bubbleStyle = 'minimal';
  String messageAlignment = 'left';
  double assistantBubbleOpacity = 0.08;
  double userBubbleOpacity = 0.12;
  int themePulse = 0;

  void load(WeaviewPreferences prefs) {
    themeMode = prefs.themeMode;
    backgroundOverride = prefs.themeBackground;
    textOverride = prefs.themeText;
    accentColor = prefs.themeAccent ?? accentMint;
    if (themeMode != ThemeMode.system && backgroundOverride != null) {
      clearGlobalThemeOverrides(prefs);
    }
    assistantBubbleOverride = prefs.assistantBubble;
    userBubbleOverride = prefs.userBubble;
    fontMood = prefs.fontFamily;
    fontStyleMood = prefs.fontStyle;
    fontWeightMood = prefs.fontWeight;
    bubbleStyle = prefs.bubbleStyle;
    messageAlignment = prefs.messageAlignment;
    assistantBubbleOpacity = prefs.assistantBubbleOpacity;
    userBubbleOpacity = prefs.userBubbleOpacity;
  }

  ThemeMode get effectiveThemeMode {
    if (themeMode != ThemeMode.system) return themeMode;
    final customBackground = backgroundOverride;
    if (customBackground == null) return themeMode;
    return customBackground.computeLuminance() < 0.45
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  bool isDark(BuildContext context) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    final customBackground = backgroundOverride;
    if (customBackground != null) {
      return customBackground.computeLuminance() < 0.45;
    }
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Color background(BuildContext context) {
    return backgroundOverride ?? (isDark(context) ? baseDark : baseLight);
  }

  Color layer(BuildContext context) {
    final customBackground = backgroundOverride;
    if (customBackground != null) {
      return isDark(context)
          ? Color.lerp(customBackground, Colors.white, 0.08)!
          : Color.lerp(customBackground, Colors.black, 0.035)!;
    }
    return isDark(context) ? layerDark : layerLight;
  }

  Color text(BuildContext context) {
    final candidate = textOverride ?? (isDark(context) ? textDark : textLight);
    final currentBackground = background(context);
    if (contrastRatio(currentBackground, candidate) < 4.5) {
      return readableTextFor(currentBackground);
    }
    return candidate;
  }

  Color muted(BuildContext context) {
    return isDark(context) ? mutedDark : mutedLight;
  }

  Color get secondaryAccent {
    if (accentColor.toARGB32() == accentMint.toARGB32()) return accentGreen;
    final hsl = HSLColor.fromColor(accentColor);
    return hsl
        .withHue((hsl.hue + 38) % 360)
        .withSaturation((hsl.saturation * 0.78).clamp(0.28, 0.72))
        .withLightness((hsl.lightness + 0.12).clamp(0.42, 0.74))
        .toColor();
  }

  TextStyle textStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double opacity = 1,
    double height = 1.35,
  }) => TextStyle(
    color: text(context).withValues(alpha: opacity),
    fontSize: size,
    fontWeight: weight,
    fontStyle: FontStyle.normal,
    height: height,
    fontFamily: 'Inter',
    fontFamilyFallback: const [
      'PingFang SC',
      'Microsoft YaHei',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
  );

  TextStyle personalizedTextStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double opacity = 1,
    double height = 1.35,
  }) {
    final effectiveWeight = switch (fontWeightMood) {
      'bold' when weight.value <= FontWeight.w500.value => FontWeight.w700,
      'medium' when weight.value <= FontWeight.w400.value => FontWeight.w500,
      _ => weight,
    };
    return TextStyle(
      color: text(context).withValues(alpha: opacity),
      fontSize: size,
      fontWeight: effectiveWeight,
      fontStyle: fontStyleMood == 'italic' ? FontStyle.italic : null,
      height: height,
      fontFamily: fontMood == 'serif' ? 'Noto Serif SC' : 'Inter',
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
        'Songti SC',
        'serif',
      ],
    );
  }

  void setThemeModeValue(ThemeMode mode, WeaviewPreferences? prefs) {
    themeMode = mode;
    if (mode != ThemeMode.system) {
      clearGlobalThemeOverrides(prefs);
    }
    prefs?.saveThemeMode(mode);
  }

  void setAccentColor(Color color, WeaviewPreferences? prefs) {
    accentColor = color;
    prefs?.saveThemeAccent(color);
    themePulse++;
  }

  void applyAiTheme(
    Map<String, dynamic> args, {
    String? userPrompt,
    WeaviewPreferences? prefs,
  }) {
    args = AiThemeGuard.guard(args, userPrompt: userPrompt);
    if (args.isEmpty) return;
    if (args['resetTheme'] == true) {
      resetAiTheme(prefs);
      return;
    }
    final bg = _backgroundColorFromArgs(args, userPrompt: userPrompt);
    final txt = colorFromHex(args['textColor']?.toString());
    final assistantBubble =
        colorFromHex(args['assistantBubbleColor']?.toString()) ??
        colorFromHex(args['bubbleColor']?.toString());
    final userBubble =
        colorFromHex(args['userBubbleColor']?.toString()) ??
        colorFromHex(args['bubbleColor']?.toString());
    var nextBackground = backgroundOverride;
    var nextText = textOverride;
    if (bg != null) nextBackground = bg;
    if (txt != null) nextText = txt;
    final proposedThemeMode = args['isDark'] is bool
        ? (args['isDark'] == true ? ThemeMode.dark : ThemeMode.light)
        : bg != null
        ? (bg.computeLuminance() < 0.45 ? ThemeMode.dark : ThemeMode.light)
        : themeMode;
    final fallbackBackground = switch (proposedThemeMode) {
      ThemeMode.dark => baseDark,
      ThemeMode.light => baseLight,
      ThemeMode.system => baseLight,
    };
    final effectiveBackground = nextBackground ?? fallbackBackground;
    final fallbackText = effectiveBackground.computeLuminance() < 0.45
        ? textDark
        : textLight;
    final effectiveText = nextText ?? fallbackText;
    if (contrastRatio(effectiveBackground, effectiveText) < 4.5) {
      nextText = nextText == null
          ? readableTextFor(effectiveBackground)
          : _readableVariantOf(nextText, effectiveBackground);
    }
    if (bg != null) {
      backgroundOverride = nextBackground;
      prefs?.saveThemeBackground(nextBackground!);
    }
    if (txt != null || bg != null && nextText != null) {
      textOverride = nextText;
      prefs?.saveThemeText(nextText!);
    }
    final family = args['fontFamily']?.toString();
    if (family == 'serif' || family == 'sans') {
      fontMood = family!;
      prefs?.saveFontFamily(family);
    }
    if (args['isDark'] is bool || bg != null) {
      themeMode = proposedThemeMode;
      prefs?.saveThemeMode(themeMode);
    }
    if (assistantBubble != null) {
      assistantBubbleOverride = assistantBubble;
      prefs?.saveAssistantBubble(assistantBubble);
    }
    if (userBubble != null) {
      userBubbleOverride = userBubble;
      prefs?.saveUserBubble(userBubble);
    }
    final nextAssistantOpacity =
        opacityArg(args['assistantBubbleOpacity']) ??
        opacityArg(args['bubbleOpacity']);
    if (nextAssistantOpacity != null) {
      assistantBubbleOpacity = nextAssistantOpacity;
      prefs?.saveAssistantBubbleOpacity(assistantBubbleOpacity);
    }
    final nextUserOpacity =
        opacityArg(args['userBubbleOpacity']) ??
        opacityArg(args['bubbleOpacity']);
    if (nextUserOpacity != null) {
      userBubbleOpacity = nextUserOpacity;
      prefs?.saveUserBubbleOpacity(userBubbleOpacity);
    }
    final nextBubbleStyle = enumArg(args['bubbleStyle'], const [
      'minimal',
      'none',
      'glass',
      'solid',
      'outline',
    ]);
    if (nextBubbleStyle != null) {
      bubbleStyle = nextBubbleStyle;
      prefs?.saveBubbleStyle(bubbleStyle);
    }
    final nextAlignment = enumArg(args['messageAlignment'], const [
      'left',
      'center',
      'right',
    ]);
    if (nextAlignment != null) {
      messageAlignment = nextAlignment;
      prefs?.saveMessageAlignment(messageAlignment);
    }
    final nextFontStyle = enumArg(args['fontStyle'], const [
      'normal',
      'italic',
    ]);
    if (nextFontStyle != null) {
      fontStyleMood = nextFontStyle;
      prefs?.saveFontStyle(fontStyleMood);
    }
    final nextFontWeight = enumArg(args['fontWeight'], const [
      'normal',
      'medium',
      'bold',
    ]);
    if (nextFontWeight != null) {
      fontWeightMood = nextFontWeight;
      prefs?.saveFontWeight(fontWeightMood);
    }
    themePulse++;
  }

  void resetAiTheme(WeaviewPreferences? prefs) {
    backgroundOverride = null;
    textOverride = null;
    assistantBubbleOverride = null;
    userBubbleOverride = null;
    accentColor = accentMint;
    fontMood = 'sans';
    fontStyleMood = 'normal';
    fontWeightMood = 'normal';
    bubbleStyle = 'minimal';
    messageAlignment = 'left';
    assistantBubbleOpacity = 0.08;
    userBubbleOpacity = 0.12;
    themeMode = ThemeMode.system;
    prefs?.resetThemeControls(
      fontFamily: fontMood,
      fontStyle: fontStyleMood,
      fontWeight: fontWeightMood,
      bubbleStyle: bubbleStyle,
      messageAlignment: messageAlignment,
      assistantBubbleOpacity: assistantBubbleOpacity,
      userBubbleOpacity: userBubbleOpacity,
      themeMode: themeMode,
    );
    themePulse++;
  }

  bool applyPromptAppearanceIntent(String value, WeaviewPreferences? prefs) {
    final args = PromptAppearanceIntent.parse(value);
    if (args.isEmpty) return false;
    applyAiTheme(args, userPrompt: value, prefs: prefs);
    return true;
  }

  void clearGlobalThemeOverrides(WeaviewPreferences? prefs) {
    backgroundOverride = null;
    textOverride = null;
    prefs?.clearGlobalThemeOverrides();
  }

  String currentAppearanceDirective() {
    final bg = backgroundOverride == null
        ? 'default:${themeMode.name}'
        : colorToHex(backgroundOverride!);
    final txt = textOverride == null
        ? 'auto-contrast'
        : colorToHex(textOverride!);
    final assistantBubble = assistantBubbleOverride == null
        ? 'default'
        : colorToHex(assistantBubbleOverride!);
    final userBubble = userBubbleOverride == null
        ? 'default'
        : colorToHex(userBubbleOverride!);
    return '''

[System directive: Current supported chat appearance state:
- background style: background=$bg, effectiveTheme=${effectiveThemeMode.name}
- font/text style: text=$txt, fontFamily=$fontMood, fontStyle=$fontStyleMood, fontWeight=$fontWeightMood
- bubble style: style=$bubbleStyle, assistantColor=$assistantBubble, userColor=$userBubble, assistantOpacity=${assistantBubbleOpacity.toStringAsFixed(2)}, userOpacity=${userBubbleOpacity.toStringAsFixed(2)}
- message alignment: $messageAlignment
Treat background style, font/text style, bubble style, and message alignment as independent groups. If the user names only one group, modify only that group. Removing bubbles means bubbleStyle=none and bubbleOpacity=0; it never means changing background, text, or font.]
''';
  }

  static Color _readableVariantOf(Color requested, Color background) {
    if (contrastRatio(background, requested) >= 4.5) return requested;
    final backgroundIsLight = background.computeLuminance() >= 0.45;
    final hsl = HSLColor.fromColor(requested);
    for (var i = 1; i <= 14; i++) {
      final nextLightness = backgroundIsLight
          ? (hsl.lightness - i * 0.045).clamp(0.18, 0.82)
          : (hsl.lightness + i * 0.045).clamp(0.18, 0.88);
      final candidate = hsl.withLightness(nextLightness.toDouble()).toColor();
      if (contrastRatio(background, candidate) >= 4.5) return candidate;
    }
    return readableTextFor(background);
  }

  Color? _backgroundColorFromArgs(
    Map<String, dynamic> args, {
    String? userPrompt,
  }) {
    final requested = colorFromHex(args['backgroundColor']?.toString());
    if (requested == null) return null;
    if (_isOpenEndedBackgroundPrompt(userPrompt)) {
      return _nextPoeticBackground();
    }
    return requested;
  }

  Color _nextPoeticBackground() {
    const backgrounds = [
      Color(0xFFF6F1FF),
      Color(0xFFF1F6F4),
      Color(0xFFF8F3EC),
      Color(0xFFEEF4FA),
      Color(0xFFF9F0F2),
      Color(0xFF151922),
      Color(0xFF121C1A),
      Color(0xFF1A1721),
    ];
    final current = backgroundOverride;
    if (current == null) return backgrounds.first;
    final index = backgrounds.indexWhere(
      (color) => color.toARGB32() == current.toARGB32(),
    );
    if (index < 0) return backgrounds.first;
    return backgrounds[(index + 1) % backgrounds.length];
  }

  bool _isOpenEndedBackgroundPrompt(String? userPrompt) {
    final prompt = userPrompt?.toLowerCase() ?? '';
    if (prompt.trim().isEmpty) return false;
    final asksBackground = _promptHasAny(prompt, const [
      '背景',
      '底色',
      '画布',
      '壁纸',
      'background',
      'canvas',
    ]);
    if (!asksBackground) return false;
    if (RegExp(r'#(?:[0-9a-f]{6}|[0-9a-f]{8})').hasMatch(prompt)) {
      return false;
    }
    return !_promptHasAny(prompt, const [
      '红',
      'red',
      '粉',
      'pink',
      '蓝',
      'blue',
      '绿',
      'green',
      '紫',
      'purple',
      '黄',
      'yellow',
      '橙',
      'orange',
      '黑',
      'black',
      '白',
      'white',
      '灰',
      'gray',
      'grey',
      '深色',
      '浅色',
      '暗色',
      '亮色',
      'dark',
      'light',
    ]);
  }

  bool _promptHasAny(String prompt, List<String> terms) {
    return terms.any(prompt.contains);
  }
}
