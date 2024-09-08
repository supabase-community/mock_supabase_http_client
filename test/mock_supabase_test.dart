import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  late final SupabaseClient mockSupabase;
  late final MockSupabaseHttpClient mockHttpClient;

  setUpAll(() {
    // Initialize the mock HTTP client and Supabase client
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
    // Close the mock client after all tests
    mockHttpClient.close();
  });

  group('basic CRUD tests', () {
    test('Insert', () async {
      // Test inserting a record
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Upsert', () async {
      // Test upserting a record
      await mockSupabase
          .from('posts')
          .upsert({'id': 1, 'title': 'Initial post'});
      await mockSupabase
          .from('posts')
          .upsert({'id': 1, 'title': 'Updated post'});
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'id': 1, 'title': 'Updated post'});
    });

    test('Update', () async {
      // Test updating a record
      await mockSupabase
          .from('posts')
          .insert({'id': 1, 'title': 'Original title'});
      await mockSupabase
          .from('posts')
          .update({'title': 'Updated title'}).eq('id', 1);
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'id': 1, 'title': 'Updated title'});
    });

    test('Delete', () async {
      // Test deleting a record
      await mockSupabase
          .from('posts')
          .insert({'id': 1, 'title': 'To be deleted'});
      await mockSupabase.from('posts').delete().eq('id', 1);
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 0);
    });

    test('Select', () async {
      // Test selecting records
      await mockSupabase.from('posts').insert({'id': 1, 'title': 'First post'});
      await mockSupabase
          .from('posts')
          .insert({'id': 2, 'title': 'Second post'});
      final posts = await mockSupabase.from('posts').select().order('id');
      expect(posts.length, 2);
      expect(posts[0], {'id': 1, 'title': 'First post'});
      expect(posts[1], {'id': 2, 'title': 'Second post'});
    });
  });

  group('Filter tests', () {
    test('Filter by equality', () async {
      // Test filtering by equality
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts = await mockSupabase
          .from('posts')
          .select()
          .eq('title', 'Hello, world!');
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Filter by inequality', () async {
      // Test filtering by inequality
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts = await mockSupabase
          .from('posts')
          .select()
          .neq('title', 'Goodbye, world!');
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Filter by range', () async {
      // Test filtering by range
      await mockSupabase.from('posts').insert({'id': 1, 'title': 'First post'});
      await mockSupabase
          .from('posts')
          .insert({'id': 2, 'title': 'Second post'});
      final posts =
          await mockSupabase.from('posts').select().gte('id', 1).lte('id', 2);
      expect(posts.length, 2);
    });

    test('Filter by like', () async {
      // Test filtering by like
      await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
      final posts =
          await mockSupabase.from('posts').select().like('title', '%world%');
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Filter by is null', () async {
      // Test filtering by is null
      await mockSupabase.from('posts').insert({'title': null});
      final posts =
          await mockSupabase.from('posts').select().isFilter('title', null);
      expect(posts.length, 1);
      expect(posts.first, {'title': null});
    });
  });
}
