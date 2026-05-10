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
          expect(result.bytes, utf8.encode('edited-image'));
          expect(requests, ['/v1/images/edits']);
          expect(contentType, 'multipart/form-data');
          expect(
            multipartBody,
            contains('name="image"; filename="reference.png"'),
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
  });
}
