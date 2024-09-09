# MockSupabaseHttpClient

By passing the `MockSupabaseHttpClient` to the Supabase client, you can create a mock Supabase client that you can use for unit testing your Supabase API calls without making actual network requests.

## Features

- Add mock data to the mock Supabase client
- Supports basic CRUD operations (Create, Read, Update, Delete)
- Handles upsert operations
- Supports filtering, ordering, and limiting results
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
      'https://mock.supabase.co',
      'supabaseKey',
      httpClient: mockHttpClient,
    );
  });

  tearDown(() async {
    // You can reset the mock client to clear the database state between tests
    mockHttpClient.reset();
  });

  tearDownAll(() {
    // Close the mock client after all tests
    mockHttpClient.close();
  });

  test('Insert', () async {
    // Insert a record into the mock database
    await mockSupabase.from('posts').insert({'title': 'Hello, world!'});
    final posts = await mockSupabase.from('posts').select();
    expect(posts.length, 1);
    expect(posts.first, {'title': 'Hello, world!'});
  });
}
```

## Limitations

- The mock Supabase client does not support embedded resources (querying related tables).
- Renaming column names
- count and head requests
- aggregate functions
- The mock Supabase client does not support auth, realtime, storage, or calling edge functions.
    - You can either mock those using libraries like [mockito](https://pub.dev/packages/mockito) or use the Supabase CLI to do a full integration testing. You could use our [GitHub actions](https://github.com/supabase/setup-cli) to do that.


## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

This project is licensed under the MIT License.