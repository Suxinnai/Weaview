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

  @override
  void initState() {
    super.initState();
    state = WeaviewState()..load();
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
          title: '织境 Agent',
          debugShowCheckedModeBanner: false,
          themeMode: state.effectiveThemeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: baseLight,
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: accentMint,
              brightness: Brightness.light,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: baseDark,
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: accentMint,
              brightness: Brightness.dark,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          home: WeaviewHome(state: state),
        );
      },
    );
  }
}
