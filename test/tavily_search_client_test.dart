import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weaview_flutter/src/data/search/tavily_search_client.dart';
import 'package:weaview_flutter/src/domain/models.dart';

void main() {
  group('TavilySearchClient', () {
    test('validates the active provider and API key before sending', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final search = TavilySearchClient(client: client);

      await expectLater(
        search.search(
          config: const SearchConfig(active: 'tavily', keys: {}),
          query: 'query',
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        search.search(
          config: const SearchConfig(active: 'other', keys: {'other': 'key'}),
          query: 'query',
          timeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('Tavily')),
        ),
      );
      expect(called, isFalse);
    });

    test('formats the answer and bounded result list', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'answer': 'A concise answer.',
            'results': [
              for (var i = 0; i < 7; i++)
                {
                  'title': 'Result $i',
                  'url': 'https://example.com/$i',
                  'content': 'Snippet $i',
                },
            ],
          }),
          200,
        );
      });

      final result = await TavilySearchClient(client: client).search(
        config: const SearchConfig(
          active: 'tavily',
          keys: {'tavily': 'search-key'},
        ),
        query: 'flutter testing',
        timeout: const Duration(seconds: 1),
      );

      expect(captured.url.toString(), 'https://api.tavily.com/search');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['api_key'], 'search-key');
      expect(body['query'], 'flutter testing');
      expect(body['max_results'], 5);
      expect(result, contains('Summary: A concise answer.'));
      expect(result, contains('Result 4'));
      expect(result, isNot(contains('Result 5')));
    });

    test('surfaces Tavily error responses', () async {
      final client = MockClient((_) async => http.Response('unavailable', 503));

      expect(
        TavilySearchClient(client: client).search(
          config: const SearchConfig(
            active: 'tavily',
            keys: {'tavily': 'search-key'},
          ),
          query: 'query',
          timeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('503')),
        ),
      );
    });
  });
}
