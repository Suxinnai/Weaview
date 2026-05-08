import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/gemini_client.dart';

void main() {
  group('GeminiClient image generation', () {
    test('posts native generateContent image requests', () async {
      String? requestPath;
      String? apiKeyHeader;
      Map<String, dynamic>? requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        requestPath = request.uri.path;
        apiKeyHeader = request.headers.value('x-goog-api-key');
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'refined prompt'},
                      {
                        'inlineData': {
                          'mimeType': 'image/png',
                          'data': 'ZmFrZS1pbWFnZQ==',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
          );
        await request.response.close();
      });

      try {
        final result = await const GeminiClient().generateImage(
          apiKey: 'test-key',
          baseUrl: 'http://127.0.0.1:${server.port}',
          model: 'gemini-3.1-flash-image-preview',
          prompt: 'a tiny glass planet',
          timeout: const Duration(seconds: 5),
        );

        expect(
          requestPath,
          '/v1beta/models/gemini-3.1-flash-image-preview:generateContent',
        );
        expect(apiKeyHeader, 'test-key');
        expect(requestBody?['generationConfig']?['responseModalities'], [
          'TEXT',
          'IMAGE',
        ]);
        expect(result.route, contains('gemini-3.1-flash-image-preview'));
        expect(result.revisedPrompt, 'refined prompt');
        expect(result.bytes, utf8.encode('fake-image'));
      } finally {
        await serving.cancel();
        await server.close(force: true);
      }
    });
  });
}
