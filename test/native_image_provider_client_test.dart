import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weaview_flutter/src/data/ai/native_image_provider_client.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  test(
    'Ark uses the native generations route and exact output controls',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      late Map<String, dynamic> requestBody;
      final handled = server.first.then((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v3/images/generations');
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {
                  'b64_json': base64Encode(const [1, 2, 3]),
                },
              ],
            }),
          );
        await request.response.close();
      });

      final images = await const NativeImageProviderClient().generate(
        kind: ImageApiKind.ark,
        apiKey: 'ark-key',
        baseUrl: 'http://127.0.0.1:${server.port}/api/v3',
        model: 'doubao-seedream-5-0-lite-260128',
        prompt: '一张简洁海报',
        timeout: const Duration(seconds: 5),
        outputCount: 1,
        size: '1536x1024',
      );
      await handled;

      expect(requestBody['model'], 'doubao-seedream-5-0-lite-260128');
      expect(requestBody['size'], '1536x1024');
      expect(requestBody['sequential_image_generation'], 'disabled');
      expect(requestBody['response_format'], 'b64_json');
      expect(images.single.bytes, [1, 2, 3]);
    },
  );

  test('Ideogram V4 sends the documented multipart request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    late String multipartBody;
    server.listen((request) async {
      if (request.uri.path.endsWith('/generate')) {
        expect(request.method, 'POST');
        expect(request.uri.path, '/v1/ideogram-v4/generate');
        expect(request.headers.contentType?.mimeType, 'multipart/form-data');
        multipartBody = await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {'url': 'http://127.0.0.1:${server.port}/result.png'},
              ],
            }),
          );
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('image', 'png')
          ..add(const [4, 5, 6]);
      }
      await request.response.close();
    });

    final images = await const NativeImageProviderClient().generate(
      kind: ImageApiKind.ideogram,
      apiKey: 'ideogram-key',
      baseUrl: 'http://127.0.0.1:${server.port}',
      model: 'ideogram-v4',
      prompt: 'A clean poster',
      timeout: const Duration(seconds: 5),
      outputCount: 1,
      size: '1024x1536',
    );

    expect(multipartBody, contains('name="text_prompt"'));
    expect(multipartBody, contains('A clean poster'));
    expect(multipartBody, contains('name="resolution"'));
    expect(multipartBody, contains('1024x1536'));
    expect(images.single.bytes, [4, 5, 6]);
  });

  test('FLUX.2 sends multiple reference images and polls the result', () async {
    final temp = await Directory.systemTemp.createTemp('weaview-flux-test-');
    addTearDown(() => temp.delete(recursive: true));
    final first = File('${temp.path}${Platform.pathSeparator}first.png');
    final second = File('${temp.path}${Platform.pathSeparator}second.png');
    await first.writeAsBytes(const [1, 2]);
    await second.writeAsBytes(const [3, 4]);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    late Map<String, dynamic> requestBody;
    server.listen((request) async {
      if (request.uri.path == '/v1/flux-2-pro-preview') {
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'id': 'request-1',
              'polling_url': 'http://127.0.0.1:${server.port}/poll',
            }),
          );
      } else if (request.uri.path == '/poll') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'Ready',
              'result': {
                'sample': 'http://127.0.0.1:${server.port}/result.png',
              },
            }),
          );
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('image', 'png')
          ..add(const [7, 8, 9]);
      }
      await request.response.close();
    });

    final images = await const NativeImageProviderClient().generate(
      kind: ImageApiKind.bfl,
      apiKey: 'bfl-key',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'flux-2-pro-preview',
      prompt: 'Combine both references',
      attachments: [
        MessageAttachment(
          path: first.path,
          name: 'first.png',
          mimeType: 'image/png',
          kind: 'image',
          size: 2,
        ),
        MessageAttachment(
          path: second.path,
          name: 'second.png',
          mimeType: 'image/png',
          kind: 'image',
          size: 2,
        ),
      ],
      timeout: const Duration(seconds: 5),
      outputCount: 1,
      size: '1536x1024',
    );

    expect(requestBody['input_image'], base64Encode(const [1, 2]));
    expect(requestBody['input_image_2'], base64Encode(const [3, 4]));
    expect(requestBody['width'], 1536);
    expect(requestBody['height'], 1024);
    expect(images.single.bytes, [7, 8, 9]);
  });
}
