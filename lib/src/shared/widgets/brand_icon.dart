import 'package:flutter/material.dart';

import '../../domain/models.dart';

class BrandIcon extends StatelessWidget {
  const BrandIcon._({
    required this.label,
    required this.assetPath,
    required this.color,
    required this.size,
    required this.radius,
    required this.padding,
  });

  factory BrandIcon.provider({
    required AiProvider provider,
    double size = 36,
    double radius = 14,
    double padding = 7,
  }) {
    return BrandIcon._(
      label: provider.name,
      assetPath: BrandIconRegistry.assetForProvider(provider.name),
      color: provider.color,
      size: size,
      radius: radius,
      padding: padding,
    );
  }

  factory BrandIcon.model({
    required AiModel model,
    AiProvider? provider,
    String? providerName,
    Color? color,
    double size = 36,
    double radius = 14,
    double padding = 7,
  }) {
    final label = model.name.trim().isEmpty ? model.id : model.name;
    final resolvedProviderName = provider?.name ?? providerName;
    final fallbackSeed = [
      resolvedProviderName,
      model.name,
      model.id,
    ].whereType<String>().join(' ');
    return BrandIcon._(
      label: label,
      assetPath: BrandIconRegistry.assetForModel(
        model: model,
        providerName: resolvedProviderName,
      ),
      color:
          color ??
          provider?.color ??
          BrandIconRegistry.fallbackColorFor(fallbackSeed),
      size: size,
      radius: radius,
      padding: padding,
    );
  }

  factory BrandIcon.named({
    required String label,
    required Color color,
    double size = 36,
    double radius = 14,
    double padding = 7,
  }) {
    return BrandIcon._(
      label: label,
      assetPath: BrandIconRegistry.assetForProvider(label),
      color: color,
      size: size,
      radius: radius,
      padding: padding,
    );
  }

  final String label;
  final String? assetPath;
  final Color color;
  final double size;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: assetPath == null
          ? _FallbackBrandMark(label: label, color: color)
          : Image.asset(
              assetPath!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) =>
                  _FallbackBrandMark(label: label, color: color),
            ),
    );
  }
}

class BrandIconRegistry {
  const BrandIconRegistry._();

  static String? assetForProvider(String providerName) {
    final text = _searchText([providerName]);
    return _matchAsset(text);
  }

  static String? assetForModel({required AiModel model, String? providerName}) {
    final text = _searchText([providerName, model.id, model.name]);
    return _matchAsset(text);
  }

  static Color fallbackColorFor(String seed) {
    const colors = [
      Color(0xFF14B8A6),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF97316),
      Color(0xFF10B981),
      Color(0xFF64748B),
      Color(0xFFEC4899),
    ];
    final normalized = seed.trim();
    final hash = normalized.runes.fold<int>(0, (value, unit) {
      return (value * 31 + unit) & 0x7fffffff;
    });
    return colors[hash % colors.length];
  }

  static String _searchText(Iterable<String?> values) {
    return values
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ')
        .toLowerCase();
  }

  static String? _matchAsset(String text) {
    if (_has(text, const ['nano-banana', 'nanobanana'])) {
      return 'assets/icons/nanobanana-color.png';
    }
    if (_has(text, const ['codex'])) return 'assets/icons/codex-color.png';
    if (_has(text, const ['claude'])) return 'assets/icons/claude-color.png';
    if (_has(text, const ['anthropic'])) return 'assets/icons/anthropic.png';
    if (_has(text, const ['deepseek'])) {
      return 'assets/icons/deepseek-color.png';
    }
    if (_has(text, const ['gemini'])) return 'assets/icons/gemini-color.png';
    if (_has(text, const ['google'])) return 'assets/icons/google-color.png';
    if (_has(text, const ['minimax', 'mini-max'])) {
      return 'assets/icons/minimax-color.png';
    }
    if (_has(text, const ['gpt-image', 'dall-e', 'openai', 'chatgpt'])) {
      return 'assets/icons/openai.png';
    }
    if (_has(text, const ['openrouter'])) return 'assets/icons/openrouter.png';
    if (_has(text, const ['kimi'])) return 'assets/icons/kimi-color.png';
    if (_has(text, const ['moonshot'])) return 'assets/icons/moonshot.png';
    if (_has(text, const ['grok'])) return 'assets/icons/grok.png';
    if (_has(text, const ['x-ai', 'xai'])) return 'assets/icons/xai.png';
    if (_has(text, const ['qwen', 'tongyi'])) {
      return 'assets/icons/qwen-color.png';
    }
    if (_has(text, const ['bailian', 'dashscope', 'aliyun', 'alibaba'])) {
      return 'assets/icons/bailian-color.png';
    }
    if (_has(text, const ['stepfun', 'step-'])) {
      return 'assets/icons/stepfun-color.png';
    }
    if (_has(text, const ['newapi', 'new-api'])) {
      return 'assets/icons/newapi-color.png';
    }
    if (_has(text, const ['tavily'])) return 'assets/icons/tavily-color.png';
    if (_has(text, const ['z-ai', 'zai', 'zhipu', 'glm'])) {
      return 'assets/icons/zai.png';
    }
    return null;
  }

  static bool _has(String text, List<String> needles) {
    return needles.any((needle) => text.contains(needle));
  }
}

class _FallbackBrandMark extends StatelessWidget {
  const _FallbackBrandMark({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = _initial(label);
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }

  static String _initial(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
