import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  });
}
