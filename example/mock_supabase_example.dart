import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  late final SupabaseClient mockSupabase;
  late final MockSupabaseHttpClient mockHttpClient;
  late final SupabaseProvider supabaseProvider;
  setUpAll(() {
    // Initialize the mock HTTP client and Supabase client
    mockHttpClient = MockSupabaseHttpClient();
    mockSupabase = SupabaseClient(
      'https://mock.supabase.co',
      'supabaseKey',
      httpClient: mockHttpClient,
    );
    supabaseProvider = SupabaseProvider(supabase: mockSupabase);
  });

  tearDown(() async {
    // Reset the mock client after each test
    mockHttpClient.reset();
  });

  tearDownAll(() {
    // Close the mock client after all tests
    mockHttpClient.close();
  });

  test('insertPost works', () async {
    // Call the insertPost method
    await supabaseProvider.insertPost('Hello, world!');
    // Check if the post was inserted
    final posts = await mockSupabase.from('posts').select();
    expect(posts.length, 1);
    expect(posts.first, {'title': 'Hello, world!'});
  });

  test('getPosts works', () async {
    // Add a mock data
    await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
    // Call the getPosts method
    final posts = await supabaseProvider.getPosts();
    expect(posts.length, 1);
    expect(posts.first, {'title': 'Hello, world!'});
  });
}

/// An example class that takes a SupabaseClient as a dependency
class SupabaseProvider {
  final SupabaseClient supabase;

  SupabaseProvider({required this.supabase});

  Future<void> insertPost(String title) async {
    await supabase.from('posts').insert({'title': title});
  }

  Future<List<Map<String, dynamic>>> getPosts() async {
    return await supabase.from('posts').select();
  }
}
