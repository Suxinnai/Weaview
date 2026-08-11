import 'package:flutter/material.dart';

import '../features/chat/chat_home.dart';
import 'app_constants.dart';
import 'weaview_state.dart';

class WeaviewApp extends StatefulWidget {
  const WeaviewApp({super.key});

  @override
  State<WeaviewApp> createState() => _WeaviewAppState();
}

class _WeaviewAppState extends State<WeaviewApp> {
  late final WeaviewState state;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    state = WeaviewState();
    // Let Flutter paint the startup surface before platform preferences are
    // opened. Large conversation archives can make SharedPreferences warm-up
    // slow on older devices; deferring it keeps the native splash responsive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadState();
    });
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'Weaview',
          debugShowCheckedModeBanner: false,
          themeMode: state.effectiveThemeMode,
          theme: _buildTheme(Brightness.light, state.accents.first),
          darkTheme: _buildTheme(Brightness.dark, state.accents.first),
          themeAnimationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          themeAnimationCurve: Curves.easeOutCubic,
          home: state.loaded
              ? WeaviewHome(state: state)
              : _WeaviewStartupGate(error: _loadError, onRetry: _loadState),
        );
      },
    );
  }

  Future<void> _loadState() async {
    setState(() => _loadError = null);
    try {
      await state.load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  ThemeData _buildTheme(Brightness brightness, Color accent) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      surface: dark ? layerDark : Colors.white,
    );
    final subtleBorder = dark
        ? Colors.white.withValues(alpha: 0.10)
        : textLight.withValues(alpha: 0.10);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? baseDark : baseLight,
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: dark ? Colors.white.withValues(alpha: 0.055) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: subtleBorder),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: subtleBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.055)
            : const Color(0xFFF7F9FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(44, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          side: BorderSide(color: subtleBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? layerDark : baseLight,
        modalBackgroundColor: dark ? layerDark : baseLight,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return dark
              ? Colors.white.withValues(alpha: 0.15)
              : textLight.withValues(alpha: 0.12);
        }),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
    );
  }
}

class _WeaviewStartupGate extends StatelessWidget {
  const _WeaviewStartupGate({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasError = error != null;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 30,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                hasError ? 'Weaview 初始化失败' : 'Weaview 正在准备中',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasError ? '本地会话或配置加载失败，请重试。' : '正在加载会话、模型与个性化配置。',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 20),
              if (hasError)
                FilledButton.icon(
                  onPressed: () => onRetry(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新加载'),
                )
              else
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
