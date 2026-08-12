import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weaview_flutter/src/data/ai/ai_gateway.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test('custom Gemini chat uses OpenAI-compatible chat completions', () async {
    String? requestPath;
    String? authorization;
    Map<String, dynamic>? requestBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      requestPath = request.uri.path;
      authorization = request.headers.value('authorization');
      requestBody =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'WEAVIEW_OK'},
              },
            ],
          }),
        );
      await request.response.close();
    });

    try {
      final provider = _proxyProvider(
        server.port,
        model: 'gemini-3.6-flash-high',
      );
      final result = await AiGateway.generate(
        messages: [ChatMessage.user('hello')],
        systemInstruction: 'Reply briefly.',
        provider: provider,
        assignment: const ModelAssignment(
          provider: 'Gemini',
          model: 'gemini-3.6-flash-high',
          prompt: '',
        ),
        onThemeUpdate: (_) {},
      );

      expect(requestPath, '/v1/chat/completions');
      expect(authorization, 'Bearer test-key');
      expect(requestBody?['model'], 'gemini-3.6-flash-high');
      expect(result, 'WEAVIEW_OK');
    } finally {
      await serving.cancel();
      await server.close(force: true);
    }
  });

  test(
    'custom Gemini images parse message.images and fill output count',
    () async {
      var requestCount = 0;
      final requestPaths = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        requestCount += 1;
        requestPaths.add(request.uri.path);
        final requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(request.headers.value('authorization'), 'Bearer test-key');
        expect(requestBody['model'], 'gemini-3.1-flash-image');
        final imageNode = {
          'type': 'image_url',
          'image_url': {
            'url':
                'data:image/jpeg;base64,${base64Encode(utf8.encode('image-$requestCount'))}',
          },
          'index': 0,
        };
        if (requestBody['stream'] == true) {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('text', 'event-stream');
          request.response.write(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'role': 'assistant', 'images': [imageNode]},
                },
              ],
            })}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
        } else {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'role': 'assistant',
                      'content': '',
                      'images': [imageNode],
                    },
                  },
                ],
              }),
            );
        }
        await request.response.close();
      });

      try {
        final provider = _proxyProvider(
          server.port,
          model: 'gemini-3.1-flash-image',
          capabilities: const ['image_generation', 'vision'],
        );
        final result = await AiGateway.generateImages(
          provider: provider,
          assignment: const ModelAssignment(
            provider: 'Gemini',
            model: 'gemini-3.1-flash-image',
            prompt: '',
          ),
          prompt: 'a tiny glass planet',
          outputCount: 2,
          aspectRatio: '1:1',
        );

        expect(requestCount, 2);
        expect(requestPaths, everyElement('/v1/chat/completions'));
        expect(result.images, hasLength(2));
        expect(result.images.map((image) => utf8.decode(image.bytes)), [
          'image-1',
          'image-2',
        ]);
        expect(
          result.images.map((image) => image.route),
          everyElement('/v1/chat/completions#message.images'),
        );
        expect(
          result.images.map((image) => image.mimeType),
          everyElement('image/jpeg'),
        );
      } finally {
        await serving.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'streaming chat images parse delta.images without legacy fallback',
    () async {
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        requestCount += 1;
        final requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(requestBody['stream'], isTrue);
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('text', 'event-stream');
        request.response.write(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {
                  'role': 'assistant',
                  'content': null,
                  'images': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url':
                            'data:image/png;base64,${base64Encode(utf8.encode('streamed-image'))}',
                      },
                    },
                  ],
                },
              },
            ],
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      try {
        final provider = _proxyProvider(
          server.port,
          model: 'gemini-3.1-flash-image',
          capabilities: const ['image_generation', 'vision'],
        );
        final result = await AiGateway.generateImages(
          provider: provider,
          assignment: const ModelAssignment(
            provider: 'Gemini',
            model: 'gemini-3.1-flash-image',
            prompt: '',
          ),
          prompt: 'a tiny glass planet',
          outputCount: 1,
          aspectRatio: '1:1',
        );

        expect(requestCount, 1);
        expect(result.images, hasLength(1));
        expect(utf8.decode(result.images.single.bytes), 'streamed-image');
        expect(
          result.images.single.route,
          '/v1/chat/completions#message.images',
        );
        expect(result.images.single.mimeType, 'image/png');
      } finally {
        await serving.cancel();
        await server.close(force: true);
      }
    },
  );

  test('custom Gemini model discovery uses bearer authentication', () async {
    String? requestPath;
    String? authorization;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      requestPath = request.uri.path;
      authorization = request.headers.value('authorization');
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'data': [
              {'id': 'gemini-3.6-flash-high'},
              {
                'id': 'gemini-3.1-flash-image',
                'capabilities': ['image_generation'],
              },
            ],
          }),
        );
      await request.response.close();
    });

    try {
      final models = await AiGateway.fetchModels(
        apiKey: 'test-key',
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        providerName: 'Gemini',
      );

      expect(requestPath, '/v1/models');
      expect(authorization, 'Bearer test-key');
      expect(
        models.map((model) => model.id),
        containsAll(['gemini-3.6-flash-high', 'gemini-3.1-flash-image']),
      );
    } finally {
      await serving.cancel();
      await server.close(force: true);
    }
  });
}

AiProvider _proxyProvider(
  int port, {
  required String model,
  List<String> capabilities = const ['chat'],
}) {
  return AiProvider(
    name: 'Gemini',
    status: '已配置',
    current: true,
    color: Colors.blue,
    apiKey: 'test-key',
    baseUrl: 'http://127.0.0.1:$port/v1',
    models: [AiModel(id: model, name: model, capabilities: capabilities)],
    imageApi: ImageApiKind.gemini,
  );
}
