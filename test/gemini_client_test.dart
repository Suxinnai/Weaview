import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/gemini_client.dart';
import 'package:weaview_flutter/src/domain/message_attachment.dart';

void main() {
  test('fetches native Gemini models and merges image presets', () async {
    String? requestPath;
    String? apiKeyHeader;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      requestPath = request.uri.path;
      apiKeyHeader = request.headers.value('x-goog-api-key');
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.1-flash-image',
                'displayName': 'Gemini 3.1 Flash Image',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/gemini-3.1-flash',
                'displayName': 'Gemini 3.1 Flash',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
        );
      await request.response.close();
    });

    try {
      final models = await const GeminiClient().fetchModels(
        apiKey: 'test-key',
        baseUrl: 'http://127.0.0.1:${server.port}/v1beta/openai',
        timeout: const Duration(seconds: 5),
      );

      expect(requestPath, '/v1beta/models');
      expect(apiKeyHeader, 'test-key');
      expect(
        models.map((model) => model.id),
        containsAll([
          'gemini-3.1-flash',
          'gemini-3.1-flash-lite-image',
          'gemini-3.1-flash-image',
          'gemini-3-pro-image',
          'gemini-2.5-flash-image',
        ]),
      );
    } finally {
      await serving.cancel();
      await server.close(force: true);
    }
  });

  group('GeminiClient image generation', () {
    test('posts native Interactions image requests', () async {
      String? requestPath;
      String? apiKeyHeader;
      Map<String, dynamic>? requestBody;
      final tempDir = await Directory.systemTemp.createTemp('weaview-gemini-');
      final reference = File('${tempDir.path}/reference.png');
      await reference.writeAsBytes(utf8.encode('reference-image'));
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
              'steps': [
                {
                  'type': 'model_output',
                  'content': [
                    {'type': 'text', 'text': 'refined prompt'},
                    {
                      'type': 'image',
                      'mime_type': 'image/png',
                      'data': 'ZmFrZS1pbWFnZQ==',
                    },
                  ],
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
          model: 'gemini-3.1-flash-image',
          prompt: 'a tiny glass planet',
          attachments: [
            MessageAttachment(
              path: reference.path,
              name: 'reference.png',
              mimeType: 'application/octet-stream',
              kind: 'image',
              size: await reference.length(),
            ),
          ],
          timeout: const Duration(seconds: 5),
        );

        expect(requestPath, '/v1beta/interactions');
        expect(apiKeyHeader, 'test-key');
        expect(requestBody?['model'], 'gemini-3.1-flash-image');
        expect(requestBody?['response_format'], {'type': 'image'});
        final parts = requestBody?['input'] as List;
        expect(parts, hasLength(2));
        expect(parts.last['type'], 'image');
        expect(parts.last['mime_type'], 'image/png');
        expect(
          parts.last['data'],
          base64Encode(utf8.encode('reference-image')),
        );
        expect(result.route, '/v1beta/interactions');
        expect(result.revisedPrompt, 'refined prompt');
        expect(result.bytes, utf8.encode('fake-image'));
      } finally {
        await serving.cancel();
        await server.close(force: true);
        await tempDir.delete(recursive: true);
      }
    });

    test('returns multiple outputs and skips thought images', () async {
      var requestCount = 0;
      Map<String, dynamic>? requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        requestCount += 1;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'steps': [
                {
                  'type': 'thought',
                  'summary': [
                    {
                      'type': 'image',
                      'mime_type': 'image/png',
                      'data': base64Encode(utf8.encode('draft-image')),
                    },
                  ],
                },
                {
                  'type': 'model_output',
                  'content': [
                    {'type': 'text', 'text': 'final variants'},
                    {
                      'type': 'image',
                      'mime_type': 'image/png',
                      'data': base64Encode(utf8.encode('image-one')),
                    },
                    {
                      'type': 'image',
                      'mime_type': 'image/webp',
                      'data': base64Encode(utf8.encode('image-two')),
                    },
                  ],
                },
              ],
            }),
          );
        await request.response.close();
      });

      try {
        final results = await const GeminiClient().generateImages(
          apiKey: 'test-key',
          baseUrl: 'http://127.0.0.1:${server.port}',
          model: 'gemini-3.1-flash-image',
          prompt: 'two tiny planets',
          outputCount: 2,
          aspectRatio: '16:9',
          imageSize: '2K',
          timeout: const Duration(seconds: 5),
        );

        expect(requestCount, 1);
        expect(results, hasLength(2));
        expect(results.map((result) => utf8.decode(result.bytes)), [
          'image-one',
          'image-two',
        ]);
        expect(results.last.mimeType, 'image/webp');
        expect(requestBody?['response_format'], {
          'type': 'image',
          'aspect_ratio': '16:9',
          'image_size': '2K',
        });
      } finally {
        await serving.cancel();
        await server.close(force: true);
      }
    });

    test(
      'issues additional requests when one response has one image',
      () async {
        var requestCount = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          requestCount += 1;
          await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'steps': [
                  {
                    'type': 'model_output',
                    'content': [
                      {
                        'type': 'image',
                        'mime_type': 'image/png',
                        'data': base64Encode(
                          utf8.encode('image-$requestCount'),
                        ),
                      },
                    ],
                  },
                ],
              }),
            );
          await request.response.close();
        });

        try {
          final results = await const GeminiClient().generateImages(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}',
            model: 'gemini-3.1-flash-lite-image',
            prompt: 'three variants',
            outputCount: 3,
            timeout: const Duration(seconds: 5),
          );

          expect(requestCount, 3);
          expect(results, hasLength(3));
        } finally {
          await serving.cancel();
          await server.close(force: true);
        }
      },
    );
  });
}
