import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase/supabase.dart';

import 'handlers/rpc_handler.dart';
import 'utils/filter_parser.dart';

/// {@template mock_supabase_http_client}
/// A mock HTTP client for testing Supabase applications that simulates
/// a Supabase API requests and responses by storing data in memory.
///
/// This client implements all the core Supabase operations including:
/// * CRUD operations with filters and transformers
/// * RPC functions
/// * Custom error simulation
///
/// Example usage:
/// ```dart
/// final client = MockSupabaseHttpClient();
///
/// // Create a Supabase client with the mock HTTP client
/// final supabase = SupabaseClient(
///   'https://mock.supabase.co',
///   'mock-key',
///   httpClient: client,
/// );
///
/// // Insert data
/// await supabase.from('users').insert({
///   'id': 1,
///   'name': 'Alice',
///   'email': 'alice@example.com'
/// });
///
/// // Query data
/// final users = await supabase
///   .from('users')
///   .select()
///   .eq('name', 'Alice');
/// ```
///
/// The mock client maintains an in-memory database represented as:
/// ```dart
/// {
///   'public.users': [
///     {'id': 1, ...},
///     ...
///   ]
/// }
/// ```
///
/// You can mock edge functions using the [registerEdgeFunction] callback:
/// ```dart
/// final client = MockSupabaseHttpClient();
/// client.registerEdgeFunction(
///  'get_user_status',
/// (body, queryParameters, method, tables) {
///  return FunctionResponse(
///   data: {'status': 'active'},
///   status: 200,
/// );
///
/// final response = await supabaseClient.functions.invoke('get_user_status');
/// ```
///
/// You can simulate errors using the [postgrestExceptionTrigger] callback:
/// ```dart
/// final client = MockSupabaseHttpClient(
///   postgrestExceptionTrigger: (schema, table, data, type) {
///     if (table == 'users' && type == RequestType.insert) {
///       throw PostgrestException(
///         message: 'Email already exists',
///         code: '400',
///       );
///     }
///   },
/// );
/// ```
///
/// The client supports custom RPC functions through [registerRpcFunction]:
/// ```dart
/// client.registerRpcFunction(
///   'get_user_status',
///   (params, tables) => {'status': 'active'},
/// );
/// ```
///
/// A mock HTTP client that simulates Supabase backend operations for testing.
/// {@endtemplate}
class MockSupabaseHttpClient extends BaseClient {
  final Map<String, List<Map<String, dynamic>>> _database = {};
  final Map<
      String,
      FunctionResponse Function(
        Map<String, dynamic> body,
        Map<String, String> queryParameters,
        HttpMethod method,
        Map<String, List<Map<String, dynamic>>> tables,
      )> _edgeFunctions = {};
  final Map<
      String,
      dynamic Function(Map<String, dynamic>? params,
          Map<String, List<Map<String, dynamic>>> tables)> _rpcFunctions = {};

  /// A function that can be used to trigger errors.
  ///
  /// Throw a PostgrestException within the `postgrestExceptionTrigger` to mock an error.
  ///
  /// Example:
  /// ```dart
  /// final client = MockSupabaseHttpClient(
  ///   postgrestExceptionTrigger: (schema, table, data, type) {
  ///     if (table == 'users' && type == RequestType.insert) {
  ///       throw PostgrestException(
  ///         message: 'Email already exists', // Provide a message
  ///         code: '400', // Optionally provide a status code
  ///         details: 'Key (email)=(test@test.com) already exists', // Optionally provide details
  ///         hint: 'Change the email address', // Optionally provide a hint
  ///       );
  ///     }
  ///     // The request will succeed otherwise
  ///   },
  /// );
  /// ```
  final void Function(
    String schema,
    String? table,
    dynamic data,
    RequestType type,
  )? postgrestExceptionTrigger;

  late final RpcHandler _rpcHandler;

  /// {@macro mock_supabase_http_client}
  MockSupabaseHttpClient({
    this.postgrestExceptionTrigger,
  }) {
    _rpcHandler = RpcHandler(_rpcFunctions, _database);
  }

  /// Clears the mock database and RPC functions.
  void reset() {
    // Clear the mock database and RPC functions
    _database.clear();
    _rpcHandler.reset();
    _edgeFunctions.clear();
  }

  /// Registers a RPC function that can be called using the `rpc` method on a `Postgrest` client.
  ///
  /// [name] is the name of the RPC function.
  ///
  /// Pass the function definition of the RPC to [function]. Use the following parameters:
  ///
  /// [params] contains the parameters passed to the RPC function.
  ///
  /// [tables] contains the mock database. It's a `Map<String, List<Map<String, dynamic>>>`
  /// where the key is `[schema].[table]` and the value is a list of rows in the table.
  /// Use it when you need to mock a RPC function that needs to modify the data in your database.
  ///
  /// Example value of `tables`:
  /// ```dart
  /// {
  ///   'public.users': [
  ///     {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'},
  ///     {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'},
  ///   ],
  ///   'public.posts': [
  ///     {'id': 1, 'title': 'First post', 'user_id': 1},
  ///     {'id': 2, 'title': 'Second post', 'user_id': 2},
  ///   ],
  /// }
  /// ```
  ///
  /// Example of registering a RPC function:
  /// ```dart
  /// mockSupabaseHttpClient.registerRpcFunction(
  ///   'get_status',
  ///   (params, tables) => {'status': 'ok'},
  /// );
  ///
  /// final mockSupabase = SupabaseClient(
  ///   'https://mock.supabase.co',
  ///   'fakeAnonKey',
  ///   httpClient: mockSupabaseHttpClient,
  /// );
  ///
  /// mockSupabase.rpc('get_status').select(); // returns {'status': 'ok'}
  /// ```
  ///
  /// Example of an RPC function that modifies the data in the database:
  /// ```dart
  /// mockSupabaseHttpClient.registerRpcFunction(
  ///   'update_post_title',
  ///   (params, tables) {
  ///     final postId = params!['id'] as int;
  ///     final newTitle = params!['title'] as String;
  ///     final post = tables['public.posts']!.firstWhere((post) => post['id'] == postId);
  ///     post['title'] = newTitle;
  ///   },
  /// );
  ///
  /// final mockSupabase = SupabaseClient(
  ///   'https://mock.supabase.co',
  ///   'fakeAnonKey',
  ///   httpClient: mockSupabaseHttpClient,
  /// );
  ///
  /// // Insert initial data
  /// await mockSupabase.from('posts').insert([
  ///   {'id': 1, 'title': 'Old title'},
  /// ]);
  ///
  /// // Call the RPC function
  /// await mockSupabase.rpc('update_post_title', params: {'id': 1, 'title': 'New title'});
  ///
  /// // Verify that the post was modified
  /// final posts = await mockSupabase.from('posts').select().eq('id', 1);
  /// expect(posts.first['title'], 'New title');
  /// ```
  void registerRpcFunction(
      String name,
      dynamic Function(Map<String, dynamic>? params,
              Map<String, List<Map<String, dynamic>>> tables)
          function) {
    _rpcFunctions[name] = function;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final functionName = _extractFunctionName(request.url);
    if (functionName != null) {
      if (_edgeFunctions.containsKey(functionName)) {
        return _handleFunctionInvocation(functionName, request);
      } else {
        return _createResponse(
          {'error': 'Function $functionName not found'},
          statusCode: 404,
          request: request,
        );
      }
    }

    // Decode the request body if it's not a GET, DELETE, or HEAD request
    dynamic body;
    if (request.method != 'GET' &&
        request.method != 'DELETE' &&
        request.method != 'HEAD' &&
        request is Request) {
      final String requestBody =
          await request.finalize().transform(utf8.decoder).join();
      if (requestBody.isNotEmpty) {
        body = jsonDecode(requestBody);
      }
    }

    // Determine request type based on method and headers
    final RequestType requestType;
    if (request.method == 'HEAD') {
      requestType = RequestType.head;
    } else

    // Check for RPC first
    if (request.url.pathSegments.contains('rpc')) {
      requestType = RequestType.rpc;
    } else if (request.method == 'GET') {
      requestType = RequestType.select;
    } else if (request.method == 'POST') {
      final preferHeader = request.headers['Prefer'];
      if (preferHeader != null &&
          preferHeader.contains('resolution=merge-duplicates')) {
        requestType = RequestType.upsert;
      } else {
        requestType = RequestType.insert;
      }
    } else if (request.method == 'PATCH') {
      requestType = RequestType.update;
    } else if (request.method == 'DELETE') {
      requestType = RequestType.delete;
    } else {
      throw UnimplementedError('HTTP method ${request.method} not supported');
    }

    // Handle regular database operations
    final (:schema, :table) = _extractTableName(
      url: request.url,
      headers: request.headers,
      method: request.method,
    );

    try {
      postgrestExceptionTrigger?.call(
        schema,
        table,
        body,
        requestType,
      );
    } on PostgrestException catch (error) {
      return _createResponse(
        error.message,
        statusCode: int.parse(error.code ?? '500'),
        request: request,
      );
    } catch (error) {
      return _createResponse(
        error.toString(),
        statusCode: 500,
        request: request,
      );
    }

    // Handle different HTTP methods
    switch (requestType) {
      case RequestType.rpc:
        final pathSegments = request.url.pathSegments;
        final restIndex = pathSegments.indexOf('v1');
        final functionName = pathSegments[restIndex + 2];
        return _rpcHandler.handleRpc(functionName, request, body);

      case RequestType.insert:
        return _handleInsert(schema, table, body, request);
      case RequestType.upsert:
        return _handleUpsert(schema, table, body, request);
      case RequestType.update:
        return _handleUpdate(schema, table, body, request);
      case RequestType.delete:
        return _handleDelete(schema, table, body, request);
      case RequestType.select:
        return _handleSelect(
            schema, table, request.url.queryParameters, request);
      case RequestType.head:
        return _handleHead(schema, table, request.url.queryParameters, request);
    }
  }

  /// Extracts the schema and table name from the URL in `schema.table` format
  ({String schema, String table}) _extractTableName({
    required Uri url,
    required Map<String, String> headers,
    required String method,
  }) {
    // Extract the table name from the URL
    final pathSegments = url.pathSegments;
    final restIndex = pathSegments.indexOf('v1');
    if (restIndex != -1 && restIndex < pathSegments.length - 1) {
      final tableName = pathSegments[restIndex + 1];

      // Extract custom schema from headers
      String schemaName = 'public';
      if (method == 'GET' || method == 'HEAD') {
        schemaName = headers['Accept-Profile'] ?? 'public';
      } else {
        schemaName = headers['Content-Profile'] ?? 'public';
      }

      return (schema: schemaName, table: tableName);
    }
    throw Exception('Invalid URL format: unable to extract table name');
  }

  StreamedResponse _handleInsert(
    String schema,
    String table,
    dynamic data,
    BaseRequest request,
  ) {
    final tableKey = '$schema.$table';
    // Handle inserting data into the mock database
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (!_database.containsKey(tableKey)) {
      _database[tableKey] = [];
    }

    if (data is Map<String, dynamic>) {
      _database[tableKey]!.add(data);
      return _createResponse([data], request: request);
    } else if (data is List) {
      final List<Map<String, dynamic>> items =
          List<Map<String, dynamic>>.from(data);
      _database[tableKey]!.addAll(items);
      return _createResponse(items, request: request);
    } else {
      return _createResponse({'error': 'Invalid data format'},
          statusCode: 400, request: request);
    }
  }

  StreamedResponse _handleUpdate(
    String schema,
    String table,
    dynamic data,
    BaseRequest request,
  ) {
    final tableKey = '$schema.$table';
    // Handle updating data in the mock database
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (data is! Map<String, dynamic>) {
      return _createResponse({'error': 'Invalid data format'},
          statusCode: 400, request: request);
    }

    // Get query parameters for filtering
    final queryParams = request.url.queryParameters;
    var updated = false;

    // Track updated rows
    final updatedRows = [];

    // Update items that match the filters
    if (_database.containsKey(tableKey)) {
      for (var row in _database[tableKey]!) {
        if (_matchesFilters(row: row, filters: queryParams)) {
          row.addAll(data);
          updated = true;
          updatedRows.add(row);
        }
      }
    }

    if (updated) {
      return _createResponse(updatedRows, request: request);
    } else {
      return _createResponse({'error': 'Not found'},
          statusCode: 404, request: request);
    }
  }

  bool _matchesFilters({
    required Map<String, dynamic> row,
    required Map<String, String> filters,
  }) {
    for (var columnName in filters.keys) {
      final filter = FilterParser.parseFilter(
        columnName: columnName,
        postrestFilter: filters[columnName]!,
        targetRow: row,
      );
      if (!filter(row)) {
        return false;
      }
    }
    return true;
  }

  StreamedResponse _handleUpsert(
    String schema,
    String table,
    dynamic data,
    BaseRequest request,
  ) {
    final tableKey = '$schema.$table';
    // Handle upserting data into the mock database
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (!_database.containsKey(tableKey)) {
      _database[tableKey] = [];
    }

    // Convert data to a list of items
    final List<Map<String, dynamic>> items = data is List
        ? List<Map<String, dynamic>>.from(data)
        : [Map<String, dynamic>.from(data)];

    // Get the onConflict columns
    final onConflictColumns =
        (request.url.queryParameters['on_conflict'] ?? 'id')
            .split(',')
            .map((e) => e.trim())
            .toList();

    // Upsert each item
    final results = items.map((item) {
      // Check if all onConflictColumns are set in item
      final shouldUpdate =
          onConflictColumns.every((column) => item[column] != null);

      if (shouldUpdate) {
        // Find the index for an item that matches all onConflictColumns
        final index = _database[tableKey]!.indexWhere((dbItem) =>
            onConflictColumns
                .every((column) => dbItem[column] == item[column]));

        if (index != -1) {
          // Update the item in the database
          _database[tableKey]![index] = {
            ..._database[tableKey]![index],
            ...item
          };
          return _database[tableKey]![index];
        }
      }
      _database[tableKey]!.add(item);
      return item;
    }).toList();

    return _createResponse(results, request: request);
  }

  StreamedResponse _handleDelete(
    String schema,
    String table,
    dynamic data,
    BaseRequest request,
  ) {
    final tableKey = '$schema.$table';
    // Handle deleting data from the mock database
    final queryParams = request.url.queryParameters;
    if (queryParams.isEmpty) {
      return _createResponse({'error': 'No query parameters provided'},
          statusCode: 400, request: request);
    }

    List removedItems = [];
    if (_database.containsKey(tableKey)) {
      _database[tableKey]!.removeWhere((row) {
        final matched = _matchesFilters(row: row, filters: queryParams);
        if (matched) {
          removedItems.add(row);
        }
        return matched;
      });
    }

    return _createResponse(removedItems, request: request);
  }

  StreamedResponse _handleSelect(
    String schema,
    String table,
    Map<String, String> queryParams,
    BaseRequest request,
  ) {
    final tableKey = '$schema.$table';
    // Handle selecting data from the mock database
    if (!_database.containsKey(tableKey)) {
      return _createResponse([], request: request);
    }

    var returningRows = List<Map<String, dynamic>>.from(_database[tableKey]!);

    // Handle basic filtering
    queryParams.forEach((key, value) {
      if (key != 'select' &&
          key != 'order' &&
          key != 'limit' &&
          key != 'range') {
        if (key.contains('.')) {
          // referenced table filtering
          final parts = key.split('.');
          final referencedTableName = parts[0];
          final referencedColumnName = parts[1];
          final filter = FilterParser.parseFilter(
            columnName: referencedColumnName,
            postrestFilter: value,
            targetRow: returningRows.first[referencedTableName] is List
                ? returningRows.first[referencedTableName].first
                : returningRows.first[referencedTableName],
          );
          // apply the filter to the target column of the returning rows
          returningRows = returningRows.map((row) {
            if (row.containsKey(referencedTableName)) {
              if (row[referencedTableName] is List) {
                row[referencedTableName] = (row[referencedTableName] as List)
                    .where((item) => filter(item))
                    .toList();
              } else if (row[referencedTableName] is Map) {
                final filterResult = filter(row[referencedTableName]);
                print(filterResult);
                row[referencedTableName] = filter(row[referencedTableName])
                    ? row[referencedTableName]
                    : null;
                print(row);
              } else {
                throw Exception(
                    'Invalid type ${row[referencedTableName].runtimeType} found');
              }
            } else {
              throw Exception(
                  'Invalid query: referenced table $referencedTableName not found');
            }
            return row;
          }).toList();
        } else if (key.contains('!inner')) {
          // referenced table filtering with !inner
        } else {
          // Regular filtering on the top level table
          final filter = FilterParser.parseFilter(
            columnName: key,
            postrestFilter: value,
            targetRow: returningRows.first,
          );
          returningRows = returningRows.where((item) => filter(item)).toList();
        }
      }
    });

    // Get the count value before any limiting
    final countValue = returningRows.length;

    // Handle top level table ordering
    if (queryParams.containsKey('order')) {
      final orderParams = queryParams['order']!.split('.');

      // Handle top-level table ordering
      final ascending = orderParams.length == 1 || orderParams[1] != 'desc';

      final field = orderParams[0];
      returningRows.sort((a, b) => ascending
          ? a[field].compareTo(b[field])
          : b[field].compareTo(a[field]));
    }

    // Handle referenced table ordering
    queryParams.keys.where((key) => key.contains('.order')).forEach((key) {
      final referencedTable = key.split('.')[0];
      final orderParams = queryParams[key]!.split('.');
      final ascending = orderParams.length == 1 || orderParams[1] != 'desc';
      final field = orderParams[0];
      returningRows = returningRows.map((row) {
        if (row.containsKey(referencedTable)) {
          if (row[referencedTable] is List) {
            final referencedTableRows = (row[referencedTable] as List);
            referencedTableRows.sort((a, b) => ascending
                ? a[field].compareTo(b[field])
                : b[field].compareTo(a[field]));
            return {...row, referencedTable: referencedTableRows};
          }
        }
        return row;
      }).toList();
    });

    final offset = queryParams.containsKey('offset')
        ? int.parse(queryParams['offset']!)
        : 0;

    // Handle top level table offset
    if (offset > 0) {
      returningRows = returningRows.skip(offset).toList();
    }

    // Handle referenced table offset
    queryParams.keys.where((key) => key.contains('.offset')).forEach((key) {
      // Handle limiting on a referenced table
      final referencedTable = key.split('.')[0];
      final offset = int.parse(queryParams[key]!);
      returningRows = returningRows.map((row) {
        if (row[referencedTable] is List) {
          return {
            ...row,
            referencedTable:
                (row[referencedTable] as List).skip(offset).toList()
          };
        }
        return row;
      }).toList();
    });

    // Handle top level table limiting
    if (queryParams.containsKey('limit')) {
      final limit = int.parse(queryParams['limit']!);
      returningRows = returningRows.take(limit).toList();
    }

    // Handle limiting on a referenced table
    queryParams.keys.where((key) => key.contains('.limit')).forEach((key) {
      // Handle limiting on a referenced table
      final referencedTable = key.split('.')[0];
      final limit = int.parse(queryParams[key]!);
      returningRows = returningRows.map((row) {
        if (row[referencedTable] is List) {
          return {
            ...row,
            referencedTable: (row[referencedTable] as List).take(limit).toList()
          };
        }
        return row;
      }).toList();
    });

    // Handle column selection and referenced table selection
    if (queryParams.containsKey('select')) {
      final selectedColumns = queryParams['select']!.split(',');

      // Handle referenced table selection
      for (var column in selectedColumns) {
        if (column.contains('(')) {
          final referencedTableName = column.split('(')[0];
          final referencedColumns =
              column.split('(')[1].split(')')[0].split(',');

          returningRows = returningRows.map((row) {
            if (row.containsKey(referencedTableName)) {
              if (referencedColumns.contains('*')) {
                // Return all columns for the referenced table
                return row;
              } else {
                // Filter columns for the referenced table
                var filteredReferencedTable = Map<String, dynamic>.fromEntries(
                    (row[referencedTableName] as Map<String, dynamic>)
                        .entries
                        .where(
                            (entry) => referencedColumns.contains(entry.key)));
                return {...row, referencedTableName: filteredReferencedTable};
              }
            }
            return row;
          }).toList();
        }
      }

      // Handle top level column selection
      if (!selectedColumns.contains('*')) {
        returningRows = returningRows.map((row) {
          return Map<String, dynamic>.fromEntries(row.entries
              .where((entry) => selectedColumns.contains(entry.key)));
        }).toList();
      }
    }

    // Handle count
    final preferHeader = request.headers['Prefer'];
    final isCountRequest =
        preferHeader != null && preferHeader.contains('count=');

    if (isCountRequest) {
      final countType =
          preferHeader.contains('count=exact') ? 'exact' : 'planned';

      return _createResponse(returningRows, request: request, headers: {
        'content-range': '$offset-${offset + returningRows.length}/$countValue',
        'content-profile': tableKey,
        'preference-applied': 'count=$countType'
      });
    }

    // Handle single
    if (request.headers['Accept'] == 'application/vnd.pgrst.object+json') {
      if (returningRows.length == 1) {
        return _createResponse(returningRows.first, request: request);
      } else {
        return _createResponse({
          'error': '${returningRows.length} rows were found for single query'
        }, request: request);
      }
    }

    // Handle maybeSingle
    if (request.headers['Accept'] == 'application/json') {
      if (returningRows.isEmpty) {
        return _createResponse(null, request: request);
      } else if (returningRows.length == 1) {
        return _createResponse(returningRows.first, request: request);
      } else {
        return _createResponse({
          'error':
              '${returningRows.length} rows were found for maybeSingle query'
        }, statusCode: 405, request: request);
      }
    }

    return _createResponse(returningRows, request: request);
  }

  StreamedResponse _handleHead(
    String schema,
    String table,
    Map<String, String> queryParams,
    BaseRequest request,
  ) {
    final tableKey = '$schema.$table';
    // Perform the same filtering as in _handleSelect
    var returningRows =
        List<Map<String, dynamic>>.from(_database[tableKey] ?? []);

    // Apply filters (you may want to extract this to a separate method)
    queryParams.forEach((key, value) {
      if (key != 'select' &&
          key != 'order' &&
          key != 'limit' &&
          key != 'range') {
        final filter = FilterParser.parseFilter(
          columnName: key,
          postrestFilter: value,
          targetRow: returningRows.isNotEmpty ? returningRows.first : {},
        );
        returningRows = returningRows.where((item) => filter(item)).toList();
      }
    });

    // Handle count
    final preferHeader = request.headers['Prefer'];
    final isCountRequest =
        preferHeader != null && preferHeader.contains('count=');

    if (isCountRequest) {
      final count = returningRows.length;
      final countType =
          preferHeader.contains('count=exact') ? 'exact' : 'planned';

      // Return only headers for HEAD request
      return StreamedResponse(
        Stream.value([]), // Empty body for HEAD request
        200,
        headers: {
          'content-range': '0-$count/$count',
          'content-profile': tableKey,
          'preference-applied': 'count=$countType'
        },
        request: request,
      );
    }

    // If it's not a count request, return basic headers
    return StreamedResponse(
      Stream.value([]), // Empty body for HEAD request
      200,
      headers: {
        'content-profile': tableKey,
      },
      request: request,
    );
  }

  StreamedResponse _createResponse(
    dynamic data, {
    int statusCode = 200,
    required BaseRequest request,
    Map<String, String>? headers,
  }) {
    final responseHeaders = {
      'content-type': 'application/json; charset=utf-8',
      ...?headers,
    };
    Stream<List<int>> stream;
    if (data is Uint8List) {
      stream = Stream.value(data);
      responseHeaders['content-type'] = _getContentType(data);
    } else if (data is String) {
      stream = Stream.value(utf8.encode(data));
      responseHeaders['content-type'] = _getContentType(data);
    } else {
      final jsonData = jsonEncode(data);
      stream = Stream.value(utf8.encode(jsonData));
    }

    return StreamedResponse(
      stream,
      statusCode,
      headers: responseHeaders,
      request: request,
    );
  }

  /// Registers an edge function with the given name and handler.
  ///
  /// The [name] parameter specifies the name of the edge function.
  ///
  /// The [handler] parameter is a function that takes the following parameters:
  /// - [body]: A map containing the body of the request.
  /// - [queryParameters]: A map containing the query parameters of the request.
  /// - [method]: The HTTP method of the request.
  /// - [tables]: A map containing lists of maps representing the tables involved in the request.
  ///
  /// The [handler] function should return a [FunctionResponse].
  void registerEdgeFunction(
    String name,
    FunctionResponse Function(
      Map<String, dynamic> body,
      Map<String, String> queryParameters,
      HttpMethod method,
      Map<String, List<Map<String, dynamic>>> tables,
    ) handler,
  ) {
    _edgeFunctions[name] = handler;
  }

  String? _extractFunctionName(Uri url) {
    final pathSegments = url.pathSegments;
    // Handle functions endpoint: /functions/v1/{function_name}
    if (pathSegments.length >= 3 &&
        pathSegments[0] == 'functions' &&
        pathSegments[1] == 'v1') {
      return pathSegments[2];
    }
    return null;
  }

  Future<StreamedResponse> _handleFunctionInvocation(
    String functionName,
    BaseRequest request,
  ) async {
    if (!_edgeFunctions.containsKey(functionName)) {
      return _createResponse(
        {'error': 'Edge function $functionName not found'},
        statusCode: 404,
        request: request,
      );
    }

    // Parse request data
    final tables = _database;
    final body = await _parseRequestBody(request);
    final queryParams = request.url.queryParameters;
    final method = _parseMethod(request.method);

    // Call handler
    final response = _edgeFunctions[functionName]!(
      body ?? {},
      queryParams,
      method,
      tables,
    );

    return _createResponse(
      response.data,
      statusCode: response.status,
      request: request,
      headers: {
        'content-type': _getContentType(response.data),
      },
    );
  }

  Future<dynamic> _parseRequestBody(BaseRequest request) async {
    if (request is! Request) return null;
    final content = await request.finalize().transform(utf8.decoder).join();
    return content.isEmpty ? null : jsonDecode(content);
  }

  HttpMethod _parseMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PATCH':
        return HttpMethod.patch;
      case 'DELETE':
        return HttpMethod.delete;
      case 'PUT':
        return HttpMethod.put;
      default:
        return HttpMethod.get;
    }
  }

  String _getContentType(dynamic data) {
    if (data is Uint8List) return 'application/octet-stream';
    if (data is String) return 'text/plain';
    if (data is Stream<List<int>>) return 'text/event-stream';
    return 'application/json';
  }
}

/// Represents the different types of HTTP requests that can be made to the Supabase API
enum RequestType {
  /// Represents a SELECT query to retrieve data from a table
  select,

  /// Represents an INSERT query to add new data to a table
  insert,

  /// Represents an UPDATE query to modify existing data in a table
  update,

  /// Represents a DELETE query to remove data from a table
  delete,

  /// Represents an UPSERT query to insert or update data in a table
  upsert,

  /// Represents a HEAD request to get metadata without retrieving data
  head,

  /// Represents a Remote Procedure Call (RPC) to execute custom functions
  rpc,
}
