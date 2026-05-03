import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

part 'src/app_state.dart';
part 'src/models.dart';
part 'src/ai_gateway.dart';
part 'src/chat_home.dart';
part 'src/message_widgets.dart';
part 'src/sidebar_overlay.dart';
part 'src/settings_sheet.dart';
part 'src/shared_widgets.dart';

const _baseLight = Color(0xFFFCFCFD);
const _layerLight = Color(0xFFF5F7FA);
const _textLight = Color(0xFF2C3E50);
const _mutedLight = Color(0xFF95A5A6);
const _baseDark = Color(0xFF121415);
const _layerDark = Color(0xFF1A1C1E);
const _textDark = Color(0xFFE5E7EB);
const _mutedDark = Color(0xFF6B7280);
const _accentMint = Color(0xFFB5EAEA);
const _accentGreen = Color(0xFFE2F0CB);
const _sendGreen = Color(0xFF10B981);
const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

const defaultSystemInstruction = '''
You are the AI presence in "Weaview" (织境), an ultra-minimalist, poetic, and highly aesthetic chat environment.
Your tone should be elegant, helpful, and concise. Avoid robotic language.
When formulating responses, keep formatting clean and standardized. Use strict Markdown format:
- Use proper headings (##, ###) for structure
- Use bullet lists (-) or numbered lists (1.) for multiple items
- Emphasize important text with **bold** or *italics*
- Wrap code, file names, and technical terms in `backticks`
- Use code blocks for multiple lines of code
Ensure proper line breaks and spacing between paragraphs.
You have the power to change the UI theme when appropriate.
If the user asks to change the theme to something specific (e.g. "make it look like a starry night", "I want a warm reading mode"), CALL the `modify_ui_state` tool with appropriate colors.
If the user suddenly switches to a topic that has a strong mood (e.g. reciting an ancient poem, discussing deep sea biology), you may subtly change the UI to match (e.g. using a serif font for poetry).
If tool calling is unavailable, output exactly one hidden theme command like `<modify_ui_state>{"backgroundColor":"#121415","textColor":"#E5E7EB","fontFamily":"sans","isDark":true}</modify_ui_state>` and then continue normally.
Always return beautifully written, well-formatted text.
''';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const WeaviewApp());
}

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
          title: 'Weaview',
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: _baseLight,
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: _accentMint,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: _baseDark,
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: _accentMint,
              brightness: Brightness.dark,
            ),
          ),
          home: WeaviewHome(state: state),
        );
      },
    );
  }
}
