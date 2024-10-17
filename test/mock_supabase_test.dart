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
}
