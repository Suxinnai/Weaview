import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/domain/message_attachment.dart';
import 'package:weaview_flutter/src/data/ai/openai_compatible_client.dart';

void main() {
  group('OpenAiCompatibleClient image generation routing', () {
    test(
      'uses /images/generations before Responses for gpt-image models',
      () async {
        final requests = <String>[];
        final requestBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          requests.add(request.uri.path);
          requestBodies.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          if (request.uri.path == '/v1/images/generations') {
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'data': [
                    {'b64_json': 'ZmFrZS1pbWFnZQ=='},
                  ],
                }),
              );
          } else {
            request.response
              ..statusCode = 500
              ..write('unexpected route');
          }
          await request.response.close();
        });

        try {
          final result = await const OpenAiCompatibleClient().generateImage(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            prompt: 'a small test image',
            responseModel: 'gpt-5.5',
            imageModel: 'gpt-image-2',
            timeout: const Duration(seconds: 5),
          );

          expect(result.route, '/v1/images/generations');
          expect(result.bytes, utf8.encode('fake-image'));
          expect(requests, ['/v1/images/generations']);
          expect(requestBodies.single['response_format'], 'b64_json');
        } finally {
          await serving.cancel();
          await server.close(force: true);
        }
      },
    );

    test('retries transient image generation gateway failures once', () async {
      var generationAttempts = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        if (request.uri.path == '/v1/images/generations') {
          generationAttempts += 1;
          await utf8.decoder.bind(request).join();
          if (generationAttempts == 1) {
            request.response
              ..statusCode = 503
              ..headers.contentType = ContentType.json
              ..write('{"error":{"message":"temporary upstream error"}}');
          } else {
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'data': [
                    {'b64_json': 'cmV0cmllZC1pbWFnZQ=='},
                  ],
                }),
              );
          }
          await request.response.close();
          return;
        }
        request.response
          ..statusCode = 404
          ..write('unexpected route');
        await request.response.close();
      });

      try {
        final result = await const OpenAiCompatibleClient().generateImage(
          apiKey: 'test-key',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          prompt: 'a retry test image',
          responseModel: 'gpt-5.5',
          imageModel: 'gpt-image-2',
          timeout: const Duration(seconds: 5),
        );

        expect(result.bytes, utf8.encode('retried-image'));
        expect(generationAttempts, 2);
      } finally {
        await serving.cancel();
        await server.close(force: true);
      }
    });

    test('uses streaming images route after a transient gateway failure', () async {
      var generationAttempts = 0;
      final requestBodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        if (request.uri.path == '/v1/images/generations') {
          generationAttempts += 1;
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          requestBodies.add(body);
          if (generationAttempts == 1) {
            request.response
              ..statusCode = 408
              ..headers.contentType = ContentType.json
              ..write('{"error":{"message":"upstream request timeout"}}');
            await request.response.close();
            return;
          }
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('text', 'event-stream')
            ..write(
              'event: image_generation.partial_image\n'
              'data: {"type":"image_generation.partial_image","b64_json":"cGFydGlhbA=="}\n\n'
              'event: image_generation.completed\n'
              'data: {"type":"image_generation.completed","b64_json":"c3RyZWFtLWltYWdl","revised_prompt":"stream ok"}\n\n',
            );
          await request.response.close();
          return;
        }
        request.response
          ..statusCode = 404
          ..write('unexpected route');
        await request.response.close();
      });

      try {
        final result = await const OpenAiCompatibleClient().generateImage(
          apiKey: 'test-key',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          prompt: 'a streaming retry image',
          responseModel: 'gpt-5.5',
          imageModel: 'gpt-image-2',
          timeout: const Duration(seconds: 5),
        );

        expect(result.route, '/v1/images/generations?stream=true');
        expect(result.bytes, utf8.encode('stream-image'));
        expect(result.revisedPrompt, 'stream ok');
        expect(generationAttempts, 2);
        expect(requestBodies.first, isNot(contains('stream')));
        expect(requestBodies.last['stream'], isTrue);
      } finally {
        await serving.cancel();
        await server.close(force: true);
      }
    });

    test(
      'retries transient generated image URL downloads without regenerating',
      () async {
        var generationAttempts = 0;
        var downloadAttempts = 0;
        late final HttpServer server;
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          if (request.uri.path == '/v1/images/generations') {
            generationAttempts += 1;
            await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'data': [
                    {'url': 'http://127.0.0.1:${server.port}/generated.png'},
                  ],
                }),
              );
            await request.response.close();
            return;
          }
          if (request.uri.path == '/generated.png') {
            downloadAttempts += 1;
            if (downloadAttempts == 1) {
              request.response
                ..statusCode = 502
                ..write('bad gateway');
            } else {
              request.response
                ..statusCode = 200
                ..headers.contentType = ContentType('image', 'png')
                ..add(utf8.encode('downloaded-image'));
            }
            await request.response.close();
            return;
          }
          request.response
            ..statusCode = 404
            ..write('unexpected route');
          await request.response.close();
        });

        try {
          final result = await const OpenAiCompatibleClient().generateImage(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            prompt: 'a url retry test image',
            responseModel: 'gpt-5.5',
            imageModel: 'gpt-image-2',
            timeout: const Duration(seconds: 5),
          );

          expect(result.bytes, utf8.encode('downloaded-image'));
          expect(generationAttempts, 1);
          expect(downloadAttempts, 2);
        } finally {
          await serving.cancel();
          await server.close(force: true);
        }
      },
    );

    test(
      'uses /images/edits with multipart images for reference images',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('weaview-image-');
        final reference = File('${tempDir.path}/reference.png');
        await reference.writeAsBytes(utf8.encode('reference-image'));

        final requests = <String>[];
        String? contentType;
        String? multipartBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          requests.add(request.uri.path);
          contentType = request.headers.contentType?.mimeType;
          multipartBody = await latin1.decoder.bind(request).join();
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'data': [
                  {'b64_json': 'ZWRpdGVkLWltYWdl'},
                ],
              }),
            );
          await request.response.close();
        });

        try {
          final result = await const OpenAiCompatibleClient().generateImage(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            prompt: 'turn image one into image two style',
            attachments: [
              MessageAttachment(
                path: reference.path,
                name: 'reference.png',
                mimeType: 'application/octet-stream',
                kind: 'image',
                size: await reference.length(),
              ),
            ],
            responseModel: 'gpt-5.5',
            imageModel: 'qwen-image-edit',
            timeout: const Duration(seconds: 5),
          );

          expect(result.route, '/v1/images/edits');
          expect(result.bytes, utf8.encode('edited-image'));
          expect(requests, ['/v1/images/edits']);
          expect(contentType, 'multipart/form-data');
          expect(
            multipartBody,
            contains('name="image[]"; filename="reference.png"'),
          );
          expect(
            multipartBody?.toLowerCase(),
            contains('content-type: image/png'),
          );
          expect(multipartBody, contains('reference-image'));
          expect(multipartBody, contains('name="prompt"'));
          expect(
            multipartBody,
            contains('turn image one into image two style'),
          );
        } finally {
          await serving.cancel();
          await server.close(force: true);
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'uses Responses image tool before image edits for gpt-image reference images',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('weaview-image-');
        final reference = File('${tempDir.path}/reference.png');
        await reference.writeAsBytes(utf8.encode('reference-image'));

        final requests = <String>[];
        String? responsesBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          requests.add(request.uri.path);
          if (request.uri.path == '/v1/responses') {
            responsesBody = await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'output': [
                    {
                      'type': 'image_generation_call',
                      'result': 'ZmFsbGJhY2staW1hZ2U=',
                    },
                  ],
                }),
              );
            await request.response.close();
            return;
          }
          request.response
            ..statusCode = 500
            ..write('unexpected route');
          await request.response.close();
        });

        try {
          final result = await const OpenAiCompatibleClient().generateImage(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            prompt: 'keep composition and change color',
            attachments: [
              MessageAttachment(
                path: reference.path,
                name: 'reference.png',
                mimeType: 'application/octet-stream',
                kind: 'image',
                size: await reference.length(),
              ),
            ],
            responseModel: 'gpt-5.5',
            imageModel: 'gpt-image-2',
            timeout: const Duration(seconds: 5),
          );

          expect(result.route, '/v1/responses?stream=true');
          expect(result.bytes, utf8.encode('fallback-image'));
          expect(requests, ['/v1/responses']);
          expect(responsesBody, contains('data:image/png;base64,'));
          expect(responsesBody, contains('"action":"edit"'));
          expect(responsesBody, contains('"stream":true'));
          expect(responsesBody, contains('"partial_images":3'));
          expect(
            responsesBody,
            contains('"tool_choice":{"type":"image_generation"}'),
          );
          expect(responsesBody, contains('"model":"gpt-image-2"'));
          expect(responsesBody, contains('keep composition and change color'));
        } finally {
          await serving.cancel();
          await server.close(force: true);
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'falls back to image edits when Responses image tool is transiently unavailable',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('weaview-image-');
        final reference = File('${tempDir.path}/reference.png');
        await reference.writeAsBytes(utf8.encode('reference-image'));

        final requests = <String>[];
        var responsesAttempts = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          requests.add(request.uri.path);
          if (request.uri.path == '/v1/images/edits') {
            await latin1.decoder.bind(request).join();
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'data': [
                    {'b64_json': 'ZWRpdHMtZmFsbGJhY2s='},
                  ],
                }),
              );
            await request.response.close();
            return;
          }
          if (request.uri.path == '/v1/responses') {
            responsesAttempts += 1;
            await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 502
              ..headers.contentType = ContentType.json
              ..write('{"error":{"message":"temporary upstream error"}}');
            await request.response.close();
            return;
          }
          request.response.statusCode = 404;
          await request.response.close();
        });

        try {
          final result = await const OpenAiCompatibleClient().generateImage(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            prompt: 'keep ratio',
            attachments: [
              MessageAttachment(
                path: reference.path,
                name: 'reference.png',
                mimeType: 'image/png',
                kind: 'image',
                size: await reference.length(),
              ),
            ],
            responseModel: 'gpt-5.5',
            imageModel: 'gpt-image-2',
            timeout: const Duration(seconds: 5),
          );

          expect(result.route, '/v1/images/edits');
          expect(result.bytes, utf8.encode('edits-fallback'));
          expect(responsesAttempts, 2);
          expect(requests, [
            '/v1/responses',
            '/v1/responses',
            '/v1/images/edits',
          ]);
        } finally {
          await serving.cancel();
          await server.close(force: true);
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('retries context canceled image edits once', () async {
      final tempDir = await Directory.systemTemp.createTemp('weaview-image-');
      final reference = File('${tempDir.path}/reference.png');
      await reference.writeAsBytes(utf8.encode('reference-image'));

      var editAttempts = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        if (request.uri.path == '/v1/images/edits') {
          editAttempts += 1;
          await latin1.decoder.bind(request).join();
          if (editAttempts == 1) {
            request.response
              ..statusCode = 408
              ..headers.contentType = ContentType.json
              ..write('{"error":{"message":"context canceled"}}');
          } else {
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'data': [
                    {'b64_json': 'cmV0cmllZC1lZGl0'},
                  ],
                }),
              );
          }
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });

      try {
        final result = await const OpenAiCompatibleClient().generateImage(
          apiKey: 'test-key',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          prompt: 'edit this image',
          attachments: [
            MessageAttachment(
              path: reference.path,
              name: 'reference.png',
              mimeType: 'image/png',
              kind: 'image',
              size: await reference.length(),
            ),
          ],
          responseModel: 'gpt-5.5',
          imageModel: 'qwen-image-edit',
          timeout: const Duration(seconds: 5),
        );

        expect(result.route, '/v1/images/edits');
        expect(result.bytes, utf8.encode('retried-edit'));
        expect(editAttempts, 2);
      } finally {
        await serving.cancel();
        await server.close(force: true);
        await tempDir.delete(recursive: true);
      }
    });

    test('falls back to Responses image tool without tool_choice', () async {
      final tempDir = await Directory.systemTemp.createTemp('weaview-image-');
      final reference = File('${tempDir.path}/reference.png');
      await reference.writeAsBytes(utf8.encode('reference-image'));

      var responsesAttempts = 0;
      final responseBodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        if (request.uri.path == '/v1/responses') {
          responsesAttempts += 1;
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          responseBodies.add(body);
          if (responsesAttempts == 1) {
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.json
              ..write(
                '{"error":{"message":"tool_choice is not supported by this gateway"}}',
              );
            await request.response.close();
            return;
          }
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'output': [
                  {
                    'type': 'image_generation_call',
                    'result': 'Y29tcGF0LWltYWdl',
                  },
                ],
              }),
            );
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });

      try {
        final result = await const OpenAiCompatibleClient().generateImage(
          apiKey: 'test-key',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          prompt: 'keep ratio',
          attachments: [
            MessageAttachment(
              path: reference.path,
              name: 'reference.png',
              mimeType: 'image/png',
              kind: 'image',
              size: await reference.length(),
            ),
          ],
          responseModel: 'gpt-5.5',
          imageModel: 'gpt-image-2',
          timeout: const Duration(seconds: 5),
        );

        expect(result.route, '/v1/responses?stream=true');
        expect(result.bytes, utf8.encode('compat-image'));
        expect(responsesAttempts, 2);
        expect(responseBodies.first['tool_choice'], {
          'type': 'image_generation',
        });
        expect(responseBodies.last, isNot(contains('tool_choice')));
        expect(jsonEncode(responseBodies.last), contains('image_generation'));
        expect(
          jsonEncode(responseBodies.last),
          contains('"model":"gpt-image-2"'),
        );
        expect(
          jsonEncode(responseBodies.last),
          contains('Use the following text as the complete prompt'),
        );
      } finally {
        await serving.cancel();
        await server.close(force: true);
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'falls back to Responses without tool_choice on 408 compatibility error',
      () async {
        final requests = <String>[];
        final responseBodies = <Map<String, dynamic>>[];
        var responsesAttempts = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          requests.add(request.uri.path);
          if (request.uri.path == '/v1/images/generations') {
            await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 408
              ..headers.contentType = ContentType.json
              ..write('{"error":{"message":"upstream request timeout"}}');
            await request.response.close();
            return;
          }
          if (request.uri.path == '/v1/responses') {
            responsesAttempts += 1;
            final body =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            responseBodies.add(body);
            if (responsesAttempts == 1) {
              request.response
                ..statusCode = 408
                ..headers.contentType = ContentType.json
                ..write(
                  jsonEncode({
                    'error': {
                      'message':
                          "Tool choice 'image_generation' not found in 'tools' parameter.",
                    },
                  }),
                );
              await request.response.close();
              return;
            }
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'output': [
                    {
                      'type': 'image_generation_call',
                      'result': 'dG9vbC1jaG9pY2UtY29tcGF0',
                    },
                  ],
                }),
              );
            await request.response.close();
            return;
          }
          request.response.statusCode = 404;
          await request.response.close();
        });

        try {
          final result = await const OpenAiCompatibleClient().generateImage(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            prompt: 'a direct image generation prompt',
            responseModel: 'gpt-5.5',
            imageModel: 'gpt-image-2',
            timeout: const Duration(seconds: 5),
          );

          expect(result.route, '/v1/responses?stream=true');
          expect(result.bytes, utf8.encode('tool-choice-compat'));
          expect(requests, [
            '/v1/images/generations',
            '/v1/images/generations',
            '/v1/responses',
            '/v1/responses',
          ]);
          expect(responseBodies.first['tool_choice'], {
            'type': 'image_generation',
          });
          expect(responseBodies.last, isNot(contains('tool_choice')));
          expect(
            jsonEncode(responseBodies.last),
            contains('"model":"gpt-image-2"'),
          );
        } finally {
          await serving.cancel();
          await server.close(force: true);
        }
      },
    );

    test(
      'uses partial Responses stream image when final completion is missing',
      () async {
        final requests = <String>[];
        final responseBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.listen((request) async {
          requests.add(request.uri.path);
          if (request.uri.path == '/v1/images/generations') {
            await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 408
              ..headers.contentType = ContentType.json
              ..write('{"error":{"message":"upstream request timeout"}}');
            await request.response.close();
            return;
          }
          if (request.uri.path == '/v1/responses') {
            final body =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            responseBodies.add(body);
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType('text', 'event-stream')
              ..write(
                'event: response.image_generation_call.partial_image\n'
                'data: {"type":"response.image_generation_call.partial_image","partial_image_b64":"cGFydGlhbC1pbWFnZQ==","output_format":"png"}\n\n',
              );
            await request.response.close();
            return;
          }
          request.response.statusCode = 404;
          await request.response.close();
        });

        try {
          final result = await const OpenAiCompatibleClient().generateImage(
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            prompt: 'a long poster prompt',
            responseModel: 'gpt-5.5',
            imageModel: 'gpt-image-2',
            timeout: const Duration(seconds: 5),
          );

          expect(result.route, '/v1/responses?stream=true');
          expect(result.bytes, utf8.encode('partial-image'));
          expect(requests, [
            '/v1/images/generations',
            '/v1/images/generations',
            '/v1/responses',
          ]);
          expect(responseBodies.single['stream'], isTrue);
          expect(
            jsonEncode(responseBodies.single),
            contains('"partial_images":3'),
          );
        } finally {
          await serving.cancel();
          await server.close(force: true);
        }
      },
    );
  });
}
