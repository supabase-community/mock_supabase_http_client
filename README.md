# MockSupabaseHttpClient

An mock http client for testing Supabase APIs.
By passing the `MockSupabaseHttpClient` to the Supabase client, you can create a mock Supabase client that you can use for unit testing your Supabase API calls without making actual network requests.

It works by intercepting the HTTP requests and returning the mock data you have inserted into the mock database. The data inserted into the mock database will be stored in memory.

```dart
import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase/supabase.dart';

final mockSupabase = SupabaseClient(
  'https://mock.supabase.co', // Does not matter what URL you pass here as long as it's a valid URL
  'fakeAnonKey', // Does not matter what string you pass here
  httpClient: MockSupabaseHttpClient(),
);
```

## Features

- Add mock data to the mock Supabase client
- Supports select, insert, update, upsert, and delete operations
- Supports filtering, ordering, and limiting results
- Supports referenced table operations
- Can reset the mock data between tests

## Installation

Add mock_supabase_http_client to your dev dependencies:
```yaml
dev_dependencies:
  mock_supabase_http_client: ^0.0.1
```

## Usage

You can insert dummy data into the mock database and then test your Supabase API calls.

```dart
import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  late final SupabaseClient mockSupabase;
  late final MockSupabaseHttpClient mockHttpClient;

  setUpAll(() {
    mockHttpClient = MockSupabaseHttpClient();

    // Pass the mock client to the Supabase client
    mockSupabase = SupabaseClient(
      'https://mock.supabase.co', // Does not matter what URL you pass here as long as it's a valid URL
      'fakeAnonKey', // Does not matter what string you pass here
      httpClient: MockSupabaseHttpClient(),
    );
  });

  tearDown(() async {
    // Reset the mock data after each test
    mockHttpClient.reset();
  });

  tearDownAll(() {
    // Close the mock client after all tests
    mockHttpClient.close();
  });

  test('inserting data works', () async {
    // Start by inserting some mock data into the mock database
    await mockSupabase.from('posts').insert({'title': 'Hello, world!'});

    // Then you can test your Supabase API calls
    final posts = await mockSupabase.from('posts').select();
    expect(posts.length, 1);
    expect(posts.first, {'title': 'Hello, world!'});
  });

  // Because the mock Supabase client does not know the table schema, 
  // referenced table data has to be inserted in a way that you want to query it.
  //
  // The following example shows an example where posts table has a many-to-one 
  // relationship with authors table and a one-to-many relationship with comments table.
  test('advanced querying with filtering and referenced tables', () async {
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

    // Query posts with filtering and include referenced author data
    final posts = await mockSupabase
        .from('posts')
        .select('*, authors(*), comments(*)')
        .eq('authors.id', 1)
        .order('id', ascending: false);

    expect(posts.length, 2);
    expect(posts, [
      {
        'id': 2,
        'title': 'Second post',
        'authors': {'id': 2, 'name': 'Author Two'},
        'comments': [
          {'id': 3, 'content': 'Third comment'},
          {'id': 4, 'content': 'Fourth comment'},
          {'id': 5, 'content': 'Fifth comment'},
        ]
      },
      {
        'id': 1,
        'title': 'First post',
        'authors': {'id': 1, 'name': 'Author One'},
        'comments': [
          {'id': 1, 'content': 'First comment'},
          {'id': 2, 'content': 'Second comment'},
        ]
      },
    ]);
  });
}
```

## Current Limitations

- The mock Supabase client does not know the table schema. This means that it does not know if the inserted mock data is a referenced table data, or just a array/JSON object. This could potentially return more data than you construct a mock data with more than one referenced table.
- Nested referenced table data is not supported.
    ```dart
    // This is fine
    final posts = await mockSupabase.from('posts').select('*, authors(*)');
    // This will not return the correct data
    final posts = await mockSupabase.from('posts').select('*, authors(*, comments(*))');
    ```
- `!inner` join is not supported.
- Renaming column names is not supported.
- count and head requests are not supported.
- aggregate functions are not supported.
- Respect nullsFirst on ordering is not supported.
- rpc support is not supported.
- The errors thrown by the mock Supabase client is not the same as the actual Supabase client.
- The mock Supabase client does not support auth, realtime, storage, or calling edge functions.
    - You can either mock those using libraries like [mockito](https://pub.dev/packages/mockito) or use the Supabase CLI to do a full integration testing. You could use our [GitHub actions](https://github.com/supabase/setup-cli) to do that.

We will work on adding more features to the mock Supabase client to make it more feature complete.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

This project is licensed under the MIT License.