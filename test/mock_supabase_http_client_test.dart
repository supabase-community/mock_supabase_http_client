import 'dart:typed_data';

import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  late SupabaseClient mockSupabase;
  late MockSupabaseHttpClient mockHttpClient;

  setUpAll(() {
    // Initialize the mock HTTP client and Supabase client
    mockHttpClient = MockSupabaseHttpClient();
    mockSupabase = SupabaseClient(
      'https://mock.supabase.co',
      'supabaseKey',
      httpClient: mockHttpClient,
    );
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

    test('Insert then select', () async {
      // Test inserting a record
      final posts = await mockSupabase
          .from('posts')
          .insert({'title': 'Hello, world!'}).select();
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Upsert', () async {
      // Test upserting a record
      await mockSupabase
          .from('posts')
          .upsert({'id': 1, 'title': 'Initial post'});
      final posts = await mockSupabase.from('posts').select();
      expect(posts.first, {'id': 1, 'title': 'Initial post'});
      await mockSupabase
          .from('posts')
          .upsert({'id': 1, 'title': 'Updated post'});
      final postsUfterUpdate = await mockSupabase.from('posts').select();
      expect(postsUfterUpdate.length, 1);
      expect(postsUfterUpdate.first, {'id': 1, 'title': 'Updated post'});
    });

    test('Upsert with single onConflict column, not id', () async {
      final data = {'user_id': 1, 'name': 'John Doe'};
      const table = 'users';
      // Insert a record
      await mockSupabase.from(table).insert(data);
      final users = await mockSupabase.from(table).select();
      expect(users.first, data);

      final updatedData = {
        ...data,
        'name': 'James Bond',
      };
      await mockSupabase.from(table).upsert(
            updatedData,
            onConflict: 'user_id',
          );
      final usersAfterUpdate =
          await mockSupabase.from(table).select().eq('user_id', 1);
      expect(usersAfterUpdate.length, 1);
      expect(usersAfterUpdate.first, updatedData);
    });

    test('Upsert with multiple onConflict columns', () async {
      final data = {'user': 2, 'post': 1, 'title': 'Initial post'};
      // Test upserting a record
      await mockSupabase.from('posts').insert(data);
      final posts = await mockSupabase.from('posts').select();
      expect(posts.first, data);

      final updatedData = {
        ...data,
        'title': 'Updated post',
      };
      await mockSupabase.from('posts').upsert(
            updatedData,
            onConflict: 'user, post',
          );
      final postsAfterUpdate =
          await mockSupabase.from('posts').select().eq('user', 2).eq('post', 1);
      expect(postsAfterUpdate.length, 1);
      expect(postsAfterUpdate.first, updatedData);
    });

    test('Upsert then select', () async {
      // Test upserting a record
      await mockSupabase
          .from('posts')
          .upsert({'id': 1, 'title': 'Initial post'});
      final posts = await mockSupabase.from('posts').select();
      expect(posts.first, {'id': 1, 'title': 'Initial post'});
      final postsAfterUpdate = await mockSupabase
          .from('posts')
          .upsert({'id': 1, 'title': 'Updated post'}).select();
      expect(postsAfterUpdate.length, 1);
      expect(postsAfterUpdate.first, {'id': 1, 'title': 'Updated post'});
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

    test('Update then select', () async {
      // Test updating a record
      await mockSupabase
          .from('posts')
          .insert({'id': 1, 'title': 'Original title'});
      final posts = await mockSupabase
          .from('posts')
          .update({'title': 'Updated title'})
          .eq('id', 1)
          .select();
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

    test('Delete then select', () async {
      // Test deleting a record
      await mockSupabase
          .from('posts')
          .insert({'id': 1, 'title': 'To be deleted'});
      final deleted =
          await mockSupabase.from('posts').delete().eq('id', 1).select();
      expect(deleted.length, 1);
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 0);
    });

    test('Select after deleting all items', () async {
      // Insert an item
      await mockSupabase
          .from('posts')
          .insert({'id': 1, 'title': 'To be deleted'});
      await mockSupabase.from('posts').delete().eq('id', 1);
      final posts = await mockSupabase.from('posts').select().eq('id', 1);
      expect(posts.length, 0);
    });

    test('Select with a referenced table filter after deleting all items',
        () async {
      // Insert an item
      await mockSupabase.from('posts').insert({
        'id': 1,
        'title': 'To be deleted',
        'authors': {'id': 1, 'name': 'Author One'}
      });
      await mockSupabase.from('posts').delete().eq('id', 1);
      final posts = await mockSupabase
          .from('posts')
          .select('*, authors(*)')
          .eq('authors.name', 'Author One');
      expect(posts.length, 0);
    });

    test('Select with chained filters where the first returns no rows',
        () async {
      // Insert an item
      await mockSupabase.from('posts').insert({'id': 1, 'title': 'First post'});
      final posts = await mockSupabase
          .from('posts')
          .select()
          .eq('id', 2)
          .eq('title', 'First post');
      expect(posts.length, 0);
    });

    test('Select all columns', () async {
      // Test selecting all records
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post', 'content': 'Content of first post'},
        {'id': 2, 'title': 'Second post', 'content': 'Content of second post'}
      ]);
      final posts = await mockSupabase.from('posts').select().order('id');
      expect(posts.length, 2);

      // Order by id descending by default
      expect(posts[0], {
        'id': 2,
        'title': 'Second post',
        'content': 'Content of second post'
      });
      expect(posts[1],
          {'id': 1, 'title': 'First post', 'content': 'Content of first post'});
    });

    test('Select specific columns', () async {
      // Test selecting specific columns
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post', 'content': 'Content of first post'},
        {'id': 2, 'title': 'Second post', 'content': 'Content of second post'}
      ]);
      final titlesOnly =
          await mockSupabase.from('posts').select('id, title').order('id');
      expect(titlesOnly.length, 2);
      expect(titlesOnly[0], {'id': 2, 'title': 'Second post'});
      expect(titlesOnly[1], {'id': 1, 'title': 'First post'});
    });
  });

  group('custom schema basic CRUD tests', () {
    test('Insert', () async {
      // Test inserting a record
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .insert({'title': 'Hello, world!'});
      final posts =
          await mockSupabase.schema('custom_schema').from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'title': 'Hello, world!'});
    });

    test('Upsert', () async {
      // Test upserting a record
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .upsert({'id': 1, 'title': 'Initial post'});
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .upsert({'id': 1, 'title': 'Updated post'});
      final posts =
          await mockSupabase.schema('custom_schema').from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'id': 1, 'title': 'Updated post'});
    });

    test('Update', () async {
      // Test updating a record
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .insert({'id': 1, 'title': 'Original title'});
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .update({'title': 'Updated title'}).eq('id', 1);
      final posts =
          await mockSupabase.schema('custom_schema').from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'id': 1, 'title': 'Updated title'});
    });

    test('Delete', () async {
      // Test deleting a record
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .insert({'id': 1, 'title': 'To be deleted'});
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .delete()
          .eq('id', 1);
      final posts =
          await mockSupabase.schema('custom_schema').from('posts').select();
      expect(posts.length, 0);
    });

    test('Select all columns', () async {
      // Test selecting all records
      await mockSupabase.schema('custom_schema').from('posts').insert([
        {'id': 1, 'title': 'First post', 'content': 'Content of first post'},
        {'id': 2, 'title': 'Second post', 'content': 'Content of second post'}
      ]);
      final posts = await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .select()
          .order('id');
      expect(posts.length, 2);

      // Order by id descending by default
      expect(posts[0], {
        'id': 2,
        'title': 'Second post',
        'content': 'Content of second post'
      });
      expect(posts[1],
          {'id': 1, 'title': 'First post', 'content': 'Content of first post'});
    });

    test('Select specific columns', () async {
      // Test selecting specific columns
      await mockSupabase.schema('custom_schema').from('posts').insert([
        {'id': 1, 'title': 'First post', 'content': 'Content of first post'},
        {'id': 2, 'title': 'Second post', 'content': 'Content of second post'}
      ]);
      final titlesOnly = await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .select('id, title')
          .order('id');
      expect(titlesOnly.length, 2);
      expect(titlesOnly[0], {'id': 2, 'title': 'Second post'});
      expect(titlesOnly[1], {'id': 1, 'title': 'First post'});
    });

    test('No mixing with default schema', () async {
      // Insert into custom schema
      await mockSupabase
          .schema('custom_schema')
          .from('posts')
          .insert({'id': 1, 'title': 'Custom schema post'});

      // Insert into default schema
      await mockSupabase
          .from('posts')
          .insert({'id': 2, 'title': 'Default schema post'});

      // Check custom schema
      final customPosts =
          await mockSupabase.schema('custom_schema').from('posts').select();
      expect(customPosts.length, 1);
      expect(customPosts.first, {'id': 1, 'title': 'Custom schema post'});

      // Check default schema
      final defaultPosts = await mockSupabase.from('posts').select();
      expect(defaultPosts.length, 1);
      expect(defaultPosts.first, {'id': 2, 'title': 'Default schema post'});
    });
  });

  group('Filter tests', () {
    test('Filter by equality', () async {
      // Test filtering by equality
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts = await mockSupabase.from('posts').select().eq('id', 2);
      expect(posts.length, 1);
      expect(posts.first, {'id': 2, 'title': 'Second post'});
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
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
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

    test('Filter by greater than', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts = await mockSupabase.from('posts').select().gt('id', 1);
      expect(posts.length, 1);
      expect(posts.first, {'id': 2, 'title': 'Second post'});
    });

    test('Filter by less than', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts = await mockSupabase.from('posts').select().lt('id', 2);
      expect(posts.length, 1);
      expect(posts.first, {'id': 1, 'title': 'First post'});
    });

    test('Filter by greater than or equal', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts = await mockSupabase.from('posts').select().gte('id', 1);
      expect(posts.length, 2);
    });

    test('Filter by less than or equal', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts = await mockSupabase.from('posts').select().lte('id', 2);
      expect(posts.length, 2);
    });

    test('Filter by in', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts =
          await mockSupabase.from('posts').select().inFilter('id', [1, 2]);
      expect(posts.length, 2);
    });
    group('Not filters', () {
      setUp(() async {
        await mockSupabase.from('posts').insert([
          {
            'id': 1,
            'title': 'First post',
            'views': 100,
            'tags': ['tag1', 'tag2']
          },
          {
            'id': 2,
            'title': 'Second post',
            'views': 200,
            'tags': ['tag2', 'tag3']
          },
          {
            'id': 3,
            'title': 'Third post',
            'views': 300,
            'tags': ['tag3', 'tag4']
          }
        ]);
      });

      test('Filter by not equal', () async {
        final posts =
            await mockSupabase.from('posts').select().not('id', 'eq', 1);
        expect(posts.length, 2);
        expect(posts.map((post) => post['id']), containsAll([2, 3]));
      });

      test('Filter by not greater than', () async {
        final posts =
            await mockSupabase.from('posts').select().not('views', 'gt', 200);
        expect(posts.length, 2);
        expect(posts.map((post) => post['id']), containsAll([1, 2]));
      });

      test('Filter by not less than', () async {
        final posts =
            await mockSupabase.from('posts').select().not('views', 'lt', 200);
        expect(posts.length, 2);
        expect(posts.map((post) => post['id']), containsAll([2, 3]));
      });

      test('Filter by not like', () async {
        final posts = await mockSupabase
            .from('posts')
            .select()
            .not('title', 'like', '%Second%');
        expect(posts.length, 2);
        expect(posts.map((post) => post['id']), containsAll([1, 3]));
      });

      test('Filter by not in', () async {
        final posts =
            await mockSupabase.from('posts').select().not('id', 'in', '(1,2)');
        expect(posts.length, 1);
        expect(posts.first['id'], 3);
      });

      test('Filter by not contains', () async {
        final posts = await mockSupabase
            .from('posts')
            .select()
            .not('tags', 'cs', '{"tag1"}');
        expect(posts.length, 2);
        expect(posts.map((post) => post['id']), containsAll([2, 3]));
      });

      test('Combine not with and', () async {
        final posts = await mockSupabase
            .from('posts')
            .select()
            .not('id', 'eq', 1)
            .not('views', 'gt', 250);
        expect(posts.length, 1);
        expect(posts.first['id'], 2);
      });

      test('Combine not with or', () async {
        final posts = await mockSupabase
            .from('posts')
            .select()
            .or('id.not.eq.1,views.not.lte.200');
        expect(posts.length, 2);
        expect(posts.map((post) => post['id']), containsAll([2, 3]));
      });
    });

    test('Filter by contains', () async {
      await mockSupabase.from('posts').insert([
        {
          'id': 1,
          'tags': ['tag1', 'tag2']
        },
        {
          'id': 2,
          'tags': ['tag1', 'tag3']
        },
        {
          'id': 3,
          'tags': ['tag2', 'tag3']
        },
      ]);
      final posts =
          await mockSupabase.from('posts').select().contains('tags', ['tag1']);
      expect(posts.length, 2);
      expect(posts.map((post) => post['id']), containsAll([1, 2]));
    });

    test('Filter by contained by', () async {
      await mockSupabase.from('posts').insert({
        'tags': ['tag1']
      });
      final posts = await mockSupabase
          .from('posts')
          .select()
          .containedBy('tags', ['tag1', 'tag2']);
      expect(posts.length, 1);
      expect(posts.first, {
        'tags': ['tag1']
      });
    });

    test('Filter by overlap', () async {
      await mockSupabase.from('posts').insert({
        'tags': ['tag1', 'tag2']
      });
      final posts =
          await mockSupabase.from('posts').select().overlaps('tags', ['tag2']);
      expect(posts.length, 1);
      expect(posts.first, {
        'tags': ['tag1', 'tag2']
      });
    });

    test('Filter by full text search', () async {
      await mockSupabase.from('posts').insert({'content': 'Hello world'});
      final posts = await mockSupabase
          .from('posts')
          .select()
          .textSearch('content', 'Hello');
      expect(posts.length, 1);
      expect(posts.first, {'content': 'Hello world'});
    });

    test('Filter by match', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post', 'content': 'Hello world'},
        {'id': 2, 'title': 'More Posts', 'content': 'Hello world'},
        {'id': 3, 'title': 'More Posts', 'content': 'Hello world'}
      ]);
      final posts = await mockSupabase
          .from('posts')
          .select()
          .match({'title': 'More Posts', 'content': 'Hello world'});
      expect(posts.length, 2);
      expect(posts.map((post) => post['id']), containsAll([2, 3]));
    });
  });

  group('Modifier tests', () {
    test('Limit', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts = await mockSupabase.from('posts').select().limit(1);
      expect(posts.length, 1);
    });

    test('limit with a filter', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post', 'author_id': 1},
        {'id': 2, 'title': 'Second post', 'author_id': 2},
        {'id': 3, 'title': 'Third post', 'author_id': 1}
      ]);
      final posts =
          await mockSupabase.from('posts').select().eq('author_id', 1).limit(1);
      expect(posts.length, 1);
    });

    test('Order', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      final posts = await mockSupabase
          .from('posts')
          .select()
          .order('id', ascending: false);
      expect(posts.length, 2);
      expect(posts.first, {'id': 2, 'title': 'Second post'});
    });

    test('Range', () async {
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'},
        {'id': 3, 'title': 'Third post'},
        {'id': 4, 'title': 'Fourth post'},
      ]);
      final posts = await mockSupabase.from('posts').select().range(1, 2);
      expect(posts.length, 2);
      expect(posts.first, {'id': 2, 'title': 'Second post'});
      expect(posts.last, {'id': 3, 'title': 'Third post'});
    });
    test('Single', () async {
      await mockSupabase.from('posts').insert({'id': 1, 'title': 'First post'});
      final post = await mockSupabase.from('posts').select().single();
      expect(post, {'id': 1, 'title': 'First post'});
    });

    test('maybeSingle', () async {
      // Test with one record
      await mockSupabase.from('posts').insert({'id': 1, 'title': 'First post'});
      var post = await mockSupabase.from('posts').select().maybeSingle();
      expect(post, {'id': 1, 'title': 'First post'});

      // Test with no records
      await mockSupabase.from('posts').delete().eq('id', 1);
      post = await mockSupabase.from('posts').select().maybeSingle();
      expect(post, null);

      // Test with multiple records
      await mockSupabase.from('posts').insert([
        {'id': 1, 'title': 'First post'},
        {'id': 2, 'title': 'Second post'}
      ]);
      expect(() => mockSupabase.from('posts').select().maybeSingle(),
          throwsException);
    });
  });

  group('Referenced table queries', () {
    setUp(() async {
      // posts table has a many-to-one relationship with authors table
      // posts table has a one-to-many relationship with comments table
      await mockSupabase.from('posts').insert([
        {
          'id': 1,
          'title': 'First post',
          'authors': {'id': 1, 'name': 'Author One'},
          'comments': [
            {'id': 1, 'content': 'First comment'},
            {'id': 2, 'content': 'Second comment'}
          ]
        },
        {
          'id': 2,
          'title': 'Second post',
          'authors': {'id': 2, 'name': 'Author Two'},
          'comments': [
            {'id': 3, 'content': 'Third comment'},
            {'id': 4, 'content': 'Fourth comment'},
            {'id': 5, 'content': 'Fifth comment'}
          ]
        }
      ]);
    });

    test('Join with referenced table', () async {
      // Test joining with the referenced table
      final posts = await mockSupabase
          .from('posts')
          .select('*, authors(*)')
          .order('id', ascending: true);
      expect(posts.length, 2);
      expect(posts[0]['authors']['name'], 'Author One');
      expect(posts[1]['authors']['name'], 'Author Two');
    });

    test('Filter by referenced table column', () async {
      // Test filtering by a column in the referenced table
      final posts = await mockSupabase
          .from('posts')
          .select('*, authors(*)')
          .eq('authors.name', 'Author One')
          .order('id', ascending: true);
      print(posts);
      expect(posts.length, 2);
      expect(posts.first['title'], 'First post');
      expect(posts.first['authors'], {'id': 1, 'name': 'Author One'});
      expect(posts.last['authors'], null);
    });

    test('Order by referenced table column', () async {
      // Test ordering by a column in the referenced table
      final posts = await mockSupabase
          .from('posts')
          .select('*, comments(*)')
          .order('id', ascending: false, referencedTable: 'comments');
      expect(posts.length, 2);
      expect(posts.first['comments'].first['id'], 2);
    });

    test('Limit with referenced table', () async {
      // Test limiting results with referenced table
      final posts =
          await mockSupabase.from('posts').select('*, authors(*)').limit(1);
      expect(posts.length, 1);
    });

    test('Limit on the referenced table', () async {
      // Test limiting results with referenced table
      final posts = await mockSupabase
          .from('posts')
          .select('*, comments(*)')
          .limit(1, referencedTable: 'comments');
      expect(posts.first['comments'].length, 1);
      expect(posts[1]['comments'].length, 1);
    });

    test('Range with referenced table', () async {
      // Test range with referenced table
      final posts = await mockSupabase
          .from('posts')
          .select('*, authors(*)')
          .order('id', ascending: true, referencedTable: 'comments')
          .range(1, 2, referencedTable: 'comments');
      expect(posts.length, 2);
      expect(posts[0]['comments'].length, 1);
      expect(posts[1]['comments'].length, 2);
      expect(posts[1]['comments'].first['content'], 'Fourth comment');
    });
  });

  group('count', () {
    test('count', () async {
      await mockSupabase.from('posts').insert([
        {'title': 'First post'},
        {'title': 'Second post'}
      ]);

      final count = await mockSupabase.from('posts').count();
      expect(count, 2);
    });

    test('count with data', () async {
      await mockSupabase.from('posts').insert([
        {'title': 'First post'},
        {'title': 'Second post'}
      ]);
      final response = await mockSupabase.from('posts').select().count();
      expect(response.data.length, 2);
      expect(response.data.first['title'], 'First post');
      expect(response.count, 2);
    });

    test('count with filter', () async {
      await mockSupabase.from('posts').insert([
        {'title': 'First post', 'author_id': 1},
        {'title': 'Second post', 'author_id': 2},
        {'title': 'Third post', 'author_id': 1}
      ]);
      final count = await mockSupabase.from('posts').count().eq('author_id', 1);
      expect(count, 2);
    });

    test('count with gt filter with datetime format', () async {
      await mockSupabase.from('data').insert([
        {
          'title': 'First post',
          'author_id': 1,
          'createdAt': '2021-08-01 11:26:15.307+00'
        },
        {
          'title': 'Second post',
          'author_id': 2,
          'createdAt': '2021-08-02 11:26:15.307+00'
        },
        {
          'title': 'Third post',
          'author_id': 1,
          'createdAt': '2021-08-03 11:26:15.307+00'
        },
        {
          'title': 'Fourth post',
          'author_id': 2,
          'createdAt': '2021-08-04 11:26:15.307+00'
        }
      ]);
      final count = await mockSupabase
          .from('data')
          .count()
          .gt('createdAt', '2021-08-02 11:26:15.307+00');

      expect(count, 2);
    });

    test('count with gte filter with datetime format', () async {
      await mockSupabase.from('data').insert([
        {
          'title': 'First post',
          'author_id': 1,
          'createdAt': '2021-08-01 11:26:15.307+00'
        },
        {
          'title': 'Second post',
          'author_id': 2,
          'createdAt': '2021-08-02 11:26:15.307+00'
        },
        {
          'title': 'Third post',
          'author_id': 1,
          'createdAt': '2021-08-03 11:26:15.307+00'
        },
        {
          'title': 'Fourth post',
          'author_id': 2,
          'createdAt': '2021-08-04 11:26:15.307+00'
        }
      ]);

      final count = await mockSupabase
          .from('data')
          .count()
          .gte('createdAt', '2021-08-02 11:26:15.307+00');

      expect(count, 3);
    });

    test('count with lt filter with datetime format', () async {
      await mockSupabase.from('data').insert([
        {
          'title': 'First post',
          'author_id': 1,
          'createdAt': '2021-08-01 11:26:15.307+00'
        },
        {
          'title': 'Second post',
          'author_id': 2,
          'createdAt': '2021-08-02 11:26:15.307+00'
        },
        {
          'title': 'Third post',
          'author_id': 1,
          'createdAt': '2021-08-03 11:26:15.307+00'
        },
        {
          'title': 'Fourth post',
          'author_id': 2,
          'createdAt': '2021-08-04 11:26:15.307+00'
        }
      ]);
      final count = await mockSupabase
          .from('data')
          .count()
          .lt('createdAt', '2021-08-03 11:26:15.307+00');

      expect(count, 2);
    });

    test('count with lte filter with datetime format', () async {
      await mockSupabase.from('data').insert([
        {
          'title': 'First post',
          'author_id': 1,
          'createdAt': '2021-08-01 11:26:15.307+00'
        },
        {
          'title': 'Second post',
          'author_id': 2,
          'createdAt': '2021-08-02 11:26:15.307+00'
        },
        {
          'title': 'Third post',
          'author_id': 1,
          'createdAt': '2021-08-03 11:26:15.307+00'
        },
        {
          'title': 'Fourth post',
          'author_id': 2,
          'createdAt': '2021-08-04 11:26:15.307+00'
        }
      ]);

      final count = await mockSupabase
          .from('data')
          .count()
          .lte('createdAt', '2021-08-03 11:26:15.307+00');

      expect(count, 3);
    });

    test('count with data and filter', () async {
      await mockSupabase.from('posts').insert([
        {'title': 'First post', 'author_id': 1},
        {'title': 'Second post', 'author_id': 2},
        {'title': 'Third post', 'author_id': 1}
      ]);
      final response =
          await mockSupabase.from('posts').select().eq('author_id', 1).count();
      expect(response.data.length, 2);
      expect(response.data.first['title'], 'First post');
      expect(response.count, 2);
    });

    test('count with filter and modifier', () async {
      await mockSupabase.from('posts').insert([
        {'title': 'First post', 'author_id': 1},
        {'title': 'Second post', 'author_id': 2},
        {'title': 'Third post', 'author_id': 1}
      ]);
      final response = await mockSupabase
          .from('posts')
          .select()
          .eq('author_id', 1)
          .limit(1)
          .count();
      expect(response.data.length, 1);
      expect(response.data.first['title'], 'First post');
      expect(response.count, 2);
    });
  });

  group('non-ASCII characters tests', () {
    test('Insert Japanese text', () async {
      await mockSupabase.from('posts').insert({'title': 'こんにちは'});
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'title': 'こんにちは'});
    });

    test('Insert emoji', () async {
      await mockSupabase.from('posts').insert({'title': '😀'});
      final posts = await mockSupabase.from('posts').select();
      expect(posts.length, 1);
      expect(posts.first, {'title': '😀'});
    });
  });

  group('RPC function tests', () {
    setUp(() {
      // Register RPC functions
      mockHttpClient.registerRpcFunction(
        'get_server_time',
        (params, tables) => {'current_time': DateTime.now().toIso8601String()},
      );

      mockHttpClient.registerRpcFunction(
        'calculate_sum',
        (params, tables) =>
            {'sum': (params!['a'] as int) + (params['b'] as int)},
      );

      mockHttpClient.registerRpcFunction(
        'get_recent_posts',
        (params, tables) => [
          {'id': 1, 'title': 'Recent Post 1'},
          {'id': 2, 'title': 'Recent Post 2'},
        ],
      );

      mockHttpClient.registerRpcFunction(
        'process_order',
        (params, tables) {
          final order = params!['order'] as Map<String, dynamic>;
          final items = List<Map<String, dynamic>>.from(order['items']);
          final total = items.fold<int>(
            0,
            (sum, item) =>
                sum + (item['price'] as int) * (item['quantity'] as int),
          );
          return {
            'processed_order': {
              'status': 'processed',
              'total': total,
            }
          };
        },
      );

      mockHttpClient.registerRpcFunction(
        'update_user_points',
        (params, tables) {
          final userId = params!['user_id'] as int;
          final pointsToAdd = params['points_to_add'] as int;
          final users = tables['public.users']!;
          final userIndex = users.indexWhere((user) => user['id'] == userId);
          if (userIndex != -1) {
            users[userIndex]['points'] =
                (users[userIndex]['points'] as int) + pointsToAdd;
            return {'success': true, 'new_points': users[userIndex]['points']};
          }
          return {'success': false};
        },
      );

      // Add new RPC function for custom schema
      mockHttpClient.registerRpcFunction(
        'update_custom_schema_user_points',
        (params, tables) {
          final userId = params!['user_id'] as int;
          final pointsToAdd = params['points_to_add'] as int;
          final users = tables['custom_schema.users']!;
          final userIndex = users.indexWhere((user) => user['id'] == userId);
          if (userIndex != -1) {
            users[userIndex]['points'] =
                (users[userIndex]['points'] as int) + pointsToAdd;
            return {'success': true, 'new_points': users[userIndex]['points']};
          }
          return {'success': false};
        },
      );

      mockHttpClient.registerRpcFunction(
        'transfer_points_between_schemas',
        (params, tables) {
          final fromUserId = params!['from_user_id'] as int;
          final toUserId = params['to_user_id'] as int;
          final points = params['points'] as int;

          // Get users from both schemas
          final publicUsers = tables['public.users']!;
          final customUsers = tables['custom_schema.users']!;

          final fromUserIndex =
              publicUsers.indexWhere((user) => user['id'] == fromUserId);
          final toUserIndex =
              customUsers.indexWhere((user) => user['id'] == toUserId);

          if (fromUserIndex != -1 && toUserIndex != -1) {
            // Check if source user has enough points
            if (publicUsers[fromUserIndex]['points'] as int >= points) {
              // Deduct points from source user
              publicUsers[fromUserIndex]['points'] =
                  (publicUsers[fromUserIndex]['points'] as int) - points;
              // Add points to destination user
              customUsers[toUserIndex]['points'] =
                  (customUsers[toUserIndex]['points'] as int) + points;

              return {
                'success': true,
                'from_user_points': publicUsers[fromUserIndex]['points'],
                'to_user_points': customUsers[toUserIndex]['points']
              };
            }
          }
          return {'success': false};
        },
      );
    });

    test('Call RPC function without parameters', () async {
      final result = await mockSupabase.rpc('get_server_time');
      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('current_time', isA<String>()));
    });

    test('Call RPC function with parameters', () async {
      final result =
          await mockSupabase.rpc('calculate_sum', params: {'a': 5, 'b': 3});
      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('sum', 8));
    });

    test('Call RPC function that returns a list', () async {
      final result = await mockSupabase.rpc('get_recent_posts');
      expect(result, isA<List>());
      expect(result, hasLength(greaterThan(0)));
      expect(result.first, isA<Map<String, dynamic>>());
      expect(result.first, containsPair('id', isA<int>()));
      expect(result.first, containsPair('title', isA<String>()));
    });

    test('Call RPC function with complex parameters and return value',
        () async {
      final result = await mockSupabase.rpc('process_order', params: {
        'order': {
          'id': 1001,
          'customer': 'John Doe',
          'items': [
            {'product': 'Widget A', 'price': 10, 'quantity': 2},
            {'product': 'Widget B', 'price': 15, 'quantity': 1},
          ],
        }
      });
      expect(result, isA<Map<String, dynamic>>());
      expect(
          result, containsPair('processed_order', isA<Map<String, dynamic>>()));
      expect(result['processed_order'], containsPair('status', 'processed'));
      expect(result['processed_order'], containsPair('total', 35));
    });

    test('Call non-existent RPC function', () async {
      expect(() => mockSupabase.rpc('non_existent_function'),
          throwsA(isA<Exception>()));
    });

    test('Call RPC function that modifies database', () async {
      // Insert initial data
      await mockSupabase.from('users').insert([
        {'id': 1, 'name': 'Alice', 'points': 100},
        {'id': 2, 'name': 'Bob', 'points': 150},
      ]);

      // Call RPC function to update user points
      final result = await mockSupabase.rpc('update_user_points',
          params: {'user_id': 1, 'points_to_add': 50});

      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('success', true));
      expect(result, containsPair('new_points', 150));

      // Verify the database was updated
      final updatedUser =
          await mockSupabase.from('users').select().eq('id', 1).single();
      expect(updatedUser, isA<Map<String, dynamic>>());
      expect(updatedUser, containsPair('name', 'Alice'));
      expect(updatedUser, containsPair('points', 150));

      // Verify other users were not affected
      final otherUser =
          await mockSupabase.from('users').select().eq('id', 2).single();
      expect(otherUser, isA<Map<String, dynamic>>());
      expect(otherUser, containsPair('name', 'Bob'));
      expect(otherUser, containsPair('points', 150));
    });

    test('Call RPC function that modifies custom schema data', () async {
      // Insert initial data in custom schema
      await mockSupabase.schema('custom_schema').from('users').insert([
        {'id': 1, 'name': 'Alice', 'points': 100},
        {'id': 2, 'name': 'Bob', 'points': 150},
      ]);

      // Call RPC function to update user points in custom schema
      final result = await mockSupabase.rpc('update_custom_schema_user_points',
          params: {'user_id': 1, 'points_to_add': 50});

      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('success', true));
      expect(result, containsPair('new_points', 150));

      // Verify the database was updated in custom schema
      final updatedUser = await mockSupabase
          .schema('custom_schema')
          .from('users')
          .select()
          .eq('id', 1)
          .single();
      expect(updatedUser, isA<Map<String, dynamic>>());
      expect(updatedUser, containsPair('name', 'Alice'));
      expect(updatedUser, containsPair('points', 150));

      // Verify other users were not affected
      final otherUser = await mockSupabase
          .schema('custom_schema')
          .from('users')
          .select()
          .eq('id', 2)
          .single();
      expect(otherUser, isA<Map<String, dynamic>>());
      expect(otherUser, containsPair('name', 'Bob'));
      expect(otherUser, containsPair('points', 150));
    });

    test('Call RPC function that modifies data across schemas', () async {
      // Insert initial data in public schema
      await mockSupabase.from('users').insert([
        {'id': 1, 'name': 'Alice', 'points': 100},
      ]);

      // Insert initial data in custom schema
      await mockSupabase.schema('custom_schema').from('users').insert([
        {'id': 1, 'name': 'Bob', 'points': 50},
      ]);

      // Transfer points from public schema user to custom schema user
      final result = await mockSupabase.rpc('transfer_points_between_schemas',
          params: {'from_user_id': 1, 'to_user_id': 1, 'points': 30});

      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('success', true));
      expect(result, containsPair('from_user_points', 70));
      expect(result, containsPair('to_user_points', 80));

      // Verify public schema user was updated
      final publicUser =
          await mockSupabase.from('users').select().eq('id', 1).single();
      expect(publicUser, containsPair('points', 70));

      // Verify custom schema user was updated
      final customUser = await mockSupabase
          .schema('custom_schema')
          .from('users')
          .select()
          .eq('id', 1)
          .single();
      expect(customUser, containsPair('points', 80));
    });

    test('RPC function fails when transferring more points than available',
        () async {
      // Insert initial data in public schema
      await mockSupabase.from('users').insert([
        {'id': 1, 'name': 'Alice', 'points': 100},
      ]);

      // Insert initial data in custom schema
      await mockSupabase.schema('custom_schema').from('users').insert([
        {'id': 1, 'name': 'Bob', 'points': 50},
      ]);

      // Attempt to transfer more points than available
      final result = await mockSupabase.rpc('transfer_points_between_schemas',
          params: {'from_user_id': 1, 'to_user_id': 1, 'points': 150});

      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('success', false));

      // Verify no changes were made to either user
      final publicUser =
          await mockSupabase.from('users').select().eq('id', 1).single();
      expect(publicUser, containsPair('points', 100));

      final customUser = await mockSupabase
          .schema('custom_schema')
          .from('users')
          .select()
          .eq('id', 1)
          .single();
      expect(customUser, containsPair('points', 50));
    });
  });

  group('Edge Functions Client', () {
    test('invoke registered edge function with POST', () async {
      mockHttpClient.registerEdgeFunction('greet',
          (body, queryParams, method, tables) {
        return FunctionResponse(
          data: {'message': 'Hello, ${body['name']}!'},
          status: 200,
        );
      });

      final response = await mockSupabase.functions.invoke(
        'greet',
        body: {'name': 'Alice'},
      );

      expect(response.status, 200);
      expect(response.data, {'message': 'Hello, Alice!'});
    });

    test('invoke edge function with different HTTP methods', () async {
      mockHttpClient.registerEdgeFunction('say-hello',
          (body, queryParams, method, tables) {
        final name = switch (method) {
          HttpMethod.patch => 'Linda',
          HttpMethod.post => 'Bob',
          _ => 'Unknown'
        };
        return FunctionResponse(
          data: {'hello': name},
          status: 200,
        );
      });

      var patchResponse = await mockSupabase.functions
          .invoke('say-hello', method: HttpMethod.patch);
      expect(patchResponse.data, {'hello': 'Linda'});

      var postResponse = await mockSupabase.functions
          .invoke('say-hello', method: HttpMethod.post);
      expect(postResponse.data, {'hello': 'Bob'});
    });

    test('edge function receives query params and body', () async {
      mockHttpClient.registerEdgeFunction('params-test',
          (body, queryParams, method, tables) {
        final city = queryParams['city'];
        final street = body['street'] as String;
        return FunctionResponse(
          data: {'address': '$street, $city'},
          status: 200,
        );
      });

      final response = await mockSupabase.functions.invoke(
        'params-test',
        body: {'street': '123 Main St'},
        queryParameters: {'city': 'Springfield'},
      );

      expect(response.data, {'address': '123 Main St, Springfield'});
    });

    test('edge function returns different content types', () async {
      mockHttpClient.registerEdgeFunction('binary',
          (body, queryParams, method, tables) {
        return FunctionResponse(
          data: Uint8List.fromList([1, 2, 3]),
          status: 200,
        );
      });

      var response = await mockSupabase.functions.invoke('binary');
      expect(response.data is Uint8List, true);
      expect((response.data as Uint8List).length, 3);

      mockHttpClient.registerEdgeFunction('text',
          (body, queryParams, method, tables) {
        return FunctionResponse(
          data: 'Hello, world!',
          status: 200,
        );
      });

      response = await mockSupabase.functions.invoke('text');
      expect(response.data, 'Hello, world!');

      mockHttpClient.registerEdgeFunction('json',
          (body, queryParams, method, tables) {
        return FunctionResponse(
          data: {'key': 'value'},
          status: 200,
        );
      });

      response = await mockSupabase.functions.invoke('json');
      expect(response.data, {'key': 'value'});
    });

    test('invoke non-existent edge function returns 404', () async {
      expect(
        () async => await mockSupabase.functions.invoke('not-found'),
        throwsA(isA<FunctionException>().having(
          (e) => e.status,
          'statusCode',
          404,
        )),
      );
    });

    test('edge function modifies mock database', () async {
      mockHttpClient.registerEdgeFunction('add-user',
          (body, queryParams, method, tables) {
        final users = tables['public.users'] ?? [];
        final newUser = {
          'id': users.length + 1,
          'name': body['name'],
        };
        users.add(newUser);
        tables['public.users'] = users;
        return FunctionResponse(data: newUser, status: 201);
      });

      var users = await mockSupabase.from('users').select();
      expect(users, isEmpty);

      final response = await mockSupabase.functions.invoke(
        'add-user',
        body: {'name': 'Alice'},
      );
      expect(response.status, 201);
      expect(response.data, {'id': 1, 'name': 'Alice'});

      users = await mockSupabase.from('users').select();
      expect(users, [
        {'id': 1, 'name': 'Alice'}
      ]);
    });
  });

  group('mock exceptions', () {
    group('basic operation exceptions', () {
      test('select throws PostgrestException', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (type == RequestType.select) {
              throw PostgrestException(
                code: '400',
                message: 'Error during select',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase.from('users').select();
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '400');
          expect(error.message, 'Error during select');
        }
      });

      test('insert throws PostgrestException', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (type == RequestType.insert) {
              throw PostgrestException(
                code: '409',
                message: 'Duplicate key violation',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase.from('users').insert({'id': 1, 'name': 'Test'});
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '409');
          expect(error.message, 'Duplicate key violation');
        }
      });

      test('update throws PostgrestException', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (type == RequestType.update) {
              throw PostgrestException(
                code: '404',
                message: 'Record not found',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase
              .from('users')
              .update({'name': 'Updated'}).eq('id', 999);
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '404');
          expect(error.message, 'Record not found');
        }
      });

      test('delete throws PostgrestException', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (type == RequestType.delete) {
              throw PostgrestException(
                code: '403',
                message: 'Permission denied',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase.from('users').delete().eq('id', 1);
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '403');
          expect(error.message, 'Permission denied');
        }
      });

      test('upsert throws PostgrestException', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (type == RequestType.upsert) {
              throw PostgrestException(
                code: '422',
                message: 'Validation error',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase.from('users').upsert({'id': 1, 'name': 'Test'});
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '422');
          expect(error.message, 'Validation error');
        }
      });

      test('rpc throws PostgrestException', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (type == RequestType.rpc) {
              throw PostgrestException(
                code: '500',
                message: 'RPC function error',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase.rpc('test_function', params: {'param': 'value'});
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '500');
          expect(error.message, 'RPC function error');
        }
      });
    });

    group('conditional exceptions', () {
      test('throws when age is negative', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (type == RequestType.insert && data is Map) {
              if (data['age'] != null && data['age'] < 0) {
                throw PostgrestException(
                  code: '400',
                  message: 'Age cannot be negative',
                );
              }
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase.from('users').insert({'name': 'Test', 'age': -1});
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '400');
          expect(error.message, 'Age cannot be negative');
        }
      });

      test('throws when email is invalid', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if ((type == RequestType.insert || type == RequestType.update) &&
                data is Map) {
              if (data['email'] != null && !data['email'].contains('@')) {
                throw PostgrestException(
                  code: '422',
                  message: 'Invalid email format',
                );
              }
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase
              .from('users')
              .insert({'name': 'Test', 'email': 'invalid-email'});
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '422');
          expect(error.message, 'Invalid email format');
        }
      });

      test('throws when table does not exist', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (table == 'non_existent_table') {
              throw PostgrestException(
                code: '404',
                message: 'Table "non_existent_table" does not exist',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase.from('non_existent_table').select();
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '404');
          expect(error.message, 'Table "non_existent_table" does not exist');
        }
      });

      test('throws when schema does not exist', () async {
        mockHttpClient = MockSupabaseHttpClient(
          postgrestExceptionTrigger: (schema, table, data, type) {
            if (schema == 'non_existent_schema') {
              throw PostgrestException(
                code: '404',
                message: 'Schema "non_existent_schema" does not exist',
              );
            }
          },
        );
        mockSupabase = SupabaseClient(
          'https://mock.supabase.co',
          'supabaseKey',
          httpClient: mockHttpClient,
        );

        try {
          await mockSupabase
              .schema('non_existent_schema')
              .from('users')
              .select();
          fail('Expected PostgrestException to be thrown');
        } catch (error) {
          expect(error, isA<PostgrestException>());
          expect((error as PostgrestException).code, '404');
          expect(error.message, 'Schema "non_existent_schema" does not exist');
        }
      });
    });
  });
}
