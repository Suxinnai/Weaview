import 'package:flutter/services.dart';

const appVersionAssetPath = 'pubspec.yaml';

class AppVersionInfo {
  const AppVersionInfo({required this.name, required this.build});

  final String name;
  final String build;

  String get display => 'Weaview v$name';
  String get tag => 'v$name';
  String get full => build.isEmpty ? name : '$name+$build';
}

const fallbackAppVersionInfo = AppVersionInfo(name: '1.0.30', build: '32');

Future<AppVersionInfo> loadAppVersionInfo({AssetBundle? bundle}) async {
  try {
    final text = await (bundle ?? rootBundle).loadString(appVersionAssetPath);
    return parseAppVersionInfo(text) ?? fallbackAppVersionInfo;
  } catch (_) {
    return fallbackAppVersionInfo;
  }
}

AppVersionInfo? parseAppVersionInfo(String pubspecText) {
  final match = RegExp(
    r'^\s*version:\s*([0-9A-Za-z.+_-]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspecText);
  final value = match?.group(1)?.trim();
  if (value == null || value.isEmpty) return null;
  final parts = value.split('+');
  final name = parts.first.trim();
  if (name.isEmpty) return null;
  return AppVersionInfo(
    name: name,
    build: parts.length > 1 ? parts.sublist(1).join('+').trim() : '',
  );
}
