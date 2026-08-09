import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_constants.dart';

ThemeMode decodeThemeMode(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

String enumPref(String? value, List<String> allowed, String fallback) {
  if (value == null) return fallback;
  final normalized = value.trim().toLowerCase();
  return allowed.contains(normalized) ? normalized : fallback;
}

String? enumArg(dynamic value, List<String> allowed) {
  if (value == null) return null;
  final normalized = value.toString().trim().toLowerCase();
  return allowed.contains(normalized) ? normalized : null;
}

double? opacityArg(dynamic value) {
  if (value == null) return null;
  final parsed = switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
  final normalized = parsed > 1 ? parsed / 100 : parsed;
  return normalized.clamp(0.0, 1.0).toDouble();
}

List<T> decodeList<T>(String? value, T Function(dynamic) decoder) {
  if (value == null) return [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) return decoded.map(decoder).toList();
    if (decoded is Map) return [decoder(decoded)];
    return [];
  } catch (_) {
    return [];
  }
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

Color? colorFromHex(String? value) {
  if (value == null || value.isEmpty) return null;
  final trimmed = value.trim();
  if (!trimmed.startsWith('#')) return null;
  final hex = trimmed.substring(1);
  if (hex.length != 6 && hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}

String colorToHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color providerFallbackColor(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('gemini')) return const Color(0xFF3B82F6);
  if (lower.contains('openai')) return const Color(0xFF10B981);
  if (lower.contains('deepseek')) return const Color(0xFF2563EB);
  if (lower.contains('mini')) return const Color(0xFF8B5CF6);
  if (lower.contains('anthropic')) return const Color(0xFFB45309);
  return Colors.indigo;
}

double contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance() + 0.05;
  final l2 = b.computeLuminance() + 0.05;
  return l1 > l2 ? l1 / l2 : l2 / l1;
}

Color readableTextFor(Color background) {
  return background.computeLuminance() > 0.48 ? textLight : textDark;
}

const int _maxAvatarCacheEntries = 4;
const int _maxAvatarDecodeExtent = 256;
final Map<String, ImageProvider> _avatarImageProviders = {};

void configureImageMemoryPolicy() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = 120;
  cache.maximumSizeBytes = 64 * 1024 * 1024;
}

void releaseBackgroundImageMemory() {
  final cache = PaintingBinding.instance.imageCache;
  cache.clearLiveImages();
  cache.clear();
  _avatarImageProviders.clear();
}

int thumbnailDecodeWidth(BuildContext context) {
  final logicalWidth = MediaQuery.sizeOf(context).width;
  final pixelRatio = MediaQuery.devicePixelRatioOf(context);
  return math.min(1024, math.max(480, (logicalWidth * pixelRatio).round()));
}

int previewDecodeWidth(BuildContext context) {
  final logicalWidth = MediaQuery.sizeOf(context).width;
  final pixelRatio = MediaQuery.devicePixelRatioOf(context);
  return math.min(
    2048,
    math.max(1024, (logicalWidth * pixelRatio * 1.5).round()),
  );
}

ImageProvider? avatarImage(String value) {
  if (value.isEmpty) return null;
  final cached = _avatarImageProviders[value];
  if (cached != null) return cached;
  ImageProvider? provider;
  if (value.startsWith('data:image')) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    provider = ResizeImage(
      MemoryImage(base64Decode(value.substring(comma + 1))),
      width: _maxAvatarDecodeExtent,
      height: _maxAvatarDecodeExtent,
    );
  } else {
    final file = File(value);
    if (!file.existsSync()) return null;
    provider = ResizeImage(
      FileImage(file),
      width: _maxAvatarDecodeExtent,
      height: _maxAvatarDecodeExtent,
    );
  }
  if (_avatarImageProviders.length >= _maxAvatarCacheEntries) {
    _avatarImageProviders.remove(_avatarImageProviders.keys.first);
  }
  _avatarImageProviders[value] = provider;
  return provider;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
  return '${(kb / 1024).toStringAsFixed(1)}MB';
}

String normalizeBaseUrl(String value) {
  var base = value.trim();
  final schemeMatch = RegExp(
    r'^(https?):/*',
    caseSensitive: false,
  ).firstMatch(base);
  if (schemeMatch != null) {
    final scheme = schemeMatch.group(1)!.toLowerCase();
    base = '$scheme://${base.substring(schemeMatch.end)}';
  } else if (!base.toLowerCase().startsWith('http')) {
    base = 'https://$base';
  }

  base = base.replaceFirstMapped(
    RegExp(r'^(https?)://+', caseSensitive: false),
    (match) {
      return '${match.group(1)!.toLowerCase()}://';
    },
  );
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}
