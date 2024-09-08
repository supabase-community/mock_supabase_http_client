import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    late final SupabaseClient mockSupabase;
    late final MockSupabaseHttpClient mockHttpClient;
    setUpAll(() {
      mockHttpClient = MockSupabaseHttpClient();
      mockSupabase = SupabaseClient(
        'https://mock.supabase.co',
        'supabaseKey',
        httpClient: mockHttpClient,
      );
    });
    setUp(() {
      // Additional setup goes here.
    });

    tearDown(() async {
      // Reset the mock client after each test
      mockHttpClient.reset();
    });

    tearDownAll(() {
      mockHttpClient.close();
    });

    test('First Test', () async {
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Filter by equality', () async {
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts = await mockSupabase
          .from('posts')
          .select()
          .eq('title', 'Hello, world!');
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Filter by inequality', () async {
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts = await mockSupabase
          .from('posts')
          .select()
          .neq('title', 'Goodbye, world!');
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Filter by range', () async {
      await mockSupabase.from('posts').insert({'id': 1, 'title': 'First post'});
      await mockSupabase
          .from('posts')
          .insert({'id': 2, 'title': 'Second post'});
      final posts =
          await mockSupabase.from('posts').select().gte('id', 1).lte('id', 2);
      expect(posts.length, 2);
    });

    test('Filter by like', () async {
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts =
          await mockSupabase.from('posts').select().like('title', '%world%');
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Filter by is null', () async {
      await mockSupabase.from('posts').insert({'title': null});
      final posts =
          await mockSupabase.from('posts').select().isFilter('title', null);
      expect(posts.length, 1);
      expect(posts.first, {'title': null});
    });
  });
}
