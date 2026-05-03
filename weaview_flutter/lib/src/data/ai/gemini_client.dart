import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import 'chat_message_payloads.dart';

class GeminiClient {
  const GeminiClient();

  Future<String> generate({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    required String systemInstruction,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
    required Duration timeout,
  }) async {
    final contents = await geminiContents(messages);
    final first = await _callGemini(
      apiKey: apiKey,
      model: model,
      contents: contents,
      systemInstruction: systemInstruction,
      includeTools: true,
      timeout: timeout,
    );
    for (final call in first.functionCalls) {
      if (call['name'] == 'modify_ui_state') {
        final args = (call['args'] as Map?)?.cast<String, dynamic>() ?? {};
        onThemeUpdate(args);
      }
    }

    if (first.functionCalls.isEmpty) return first.text;

    final secondContents = [
      ...contents,
      {
        'role': 'model',
        'parts': [
          for (final call in first.functionCalls) {'functionCall': call},
        ],
      },
      {
        'role': 'user',
        'parts': [
          for (final call in first.functionCalls)
            {
              'functionResponse': {
                'name': call['name'],
                'response': {'success': true},
              },
            },
        ],
      },
    ];
    final second = await _callGemini(
      apiKey: apiKey,
      model: model,
      contents: secondContents,
      systemInstruction: systemInstruction,
      includeTools: false,
      timeout: timeout,
    );
    return second.text.isNotEmpty ? second.text : first.text;
  }

  Future<_GeminiResult> _callGemini({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> contents,
    required String systemInstruction,
    required bool includeTools,
    required Duration timeout,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${_normalizeGeminiModel(model)}:generateContent',
      {'key': apiKey},
    );
    final payload = <String, dynamic>{
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'generationConfig': {'temperature': 0.7},
      if (includeTools) 'tools': [_themeTool()],
    };
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List? ?? [];
    final parts = candidates.isEmpty
        ? const []
        : ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ??
              const [];
    final text = StringBuffer();
    final functionCalls = <Map<String, dynamic>>[];
    for (final part in parts) {
      final map = part as Map;
      if (map['text'] != null) {
        text.write(map['text']);
      }
      if (map['functionCall'] != null) {
        functionCalls.add((map['functionCall'] as Map).cast<String, dynamic>());
      }
    }
    return _GeminiResult(text: text.toString(), functionCalls: functionCalls);
  }

  static String _normalizeGeminiModel(String model) {
    return model.startsWith('models/') ? model.substring(7) : model;
  }

  static Map<String, dynamic> _themeTool() {
    return {
      'functionDeclarations': [
        {
          'name': 'modify_ui_state',
          'description':
              'Safely modifies supported chat appearance controls only. Keep groups independent: backgroundColor/isDark for background style, textColor/fontFamily/fontStyle/fontWeight for font and text style, bubbleStyle/bubble colors/bubble opacity for message bubble style, and messageAlignment for alignment. Do not use this for unsupported app layout, settings pages, navigation, spacing systems, or arbitrary CSS.',
          'parameters': {
            'type': 'object',
            'properties': {
              'resetTheme': {
                'type': 'boolean',
                'description':
                    'Set true only when the user asks to restore, reset, or return to the default theme.',
              },
              'backgroundColor': {
                'type': 'string',
                'description':
                    'CSS hex color for the chat background/canvas only. Do not set this for bubble-only or font-only requests.',
              },
              'textColor': {
                'type': 'string',
                'description':
                    'CSS hex color for readable message text only. Do not set this for bubble-only or background-only requests unless the user asks for text color too.',
              },
              'fontFamily': {
                'type': 'string',
                'enum': ['sans', 'serif'],
                'description': 'Font family for message text only.',
              },
              'fontStyle': {
                'type': 'string',
                'enum': ['normal', 'italic'],
                'description': 'Font style for message text only.',
              },
              'fontWeight': {
                'type': 'string',
                'enum': ['normal', 'medium', 'bold'],
                'description': 'Font weight for message text only.',
              },
              'messageAlignment': {
                'type': 'string',
                'enum': ['left', 'center', 'right'],
                'description': 'Message alignment only.',
              },
              'bubbleStyle': {
                'type': 'string',
                'enum': ['minimal', 'none', 'glass', 'solid', 'outline'],
                'description':
                    'Message bubble container style only. Use none to remove visible message bubbles, glass for transparent bubbles, solid for stronger filled bubbles, outline for border-only bubbles. Never change the background when removing bubbles.',
              },
              'bubbleColor': {
                'type': 'string',
                'description':
                    'CSS hex color applied to both assistant and user bubble containers only.',
              },
              'assistantBubbleColor': {
                'type': 'string',
                'description':
                    'CSS hex color for assistant bubble containers only.',
              },
              'userBubbleColor': {
                'type': 'string',
                'description': 'CSS hex color for user bubble containers only.',
              },
              'bubbleOpacity': {
                'type': 'number',
                'description':
                    'Opacity from 0 to 1 applied to both assistant and user bubbles.',
              },
              'assistantBubbleOpacity': {
                'type': 'number',
                'description': 'Assistant bubble opacity from 0 to 1.',
              },
              'userBubbleOpacity': {
                'type': 'number',
                'description': 'User bubble opacity from 0 to 1.',
              },
              'isDark': {'type': 'boolean'},
            },
          },
        },
      ],
    };
  }
}

class _GeminiResult {
  const _GeminiResult({required this.text, required this.functionCalls});

  final String text;
  final List<Map<String, dynamic>> functionCalls;
}
