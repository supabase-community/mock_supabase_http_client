import 'dart:convert';

import 'package:http/http.dart';

class MockSupabaseHttpClient extends BaseClient {
  final Map<String, List<Map<String, dynamic>>> _database = {};

  MockSupabaseHttpClient();

  void reset() {
    // Clear the mock database
    _database.clear();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Extract the table name from the URL
    final tableName = _extractTableName(request.url);

    // Decode the request body if it's not a GET request
    final body = (request.method != 'GET' && request.method != 'DELETE') &&
            request is Request
        ? jsonDecode(await request.finalize().transform(utf8.decoder).join())
        : null;

    // Handle different HTTP methods
    switch (request.method) {
      case 'POST':
        // Handle upsert if the Prefer header is set
        final preferHeader = request.headers['Prefer'];
        if (preferHeader != null &&
            preferHeader.contains('resolution=merge-duplicates')) {
          return _handleUpsert(tableName, body, request);
        }
        return _handleInsert(tableName, body, request);
      case 'PATCH':
        return _handleUpdate(tableName, body, request);
      case 'DELETE':
        return _handleDelete(tableName, body, request);
      case 'GET':
        return _handleSelect(tableName, request.url.queryParameters, request);
      default:
        return _createResponse({'error': 'Method not allowed'},
            statusCode: 405, request: request);
    }
  }

  String _extractTableName(Uri url) {
    // Extract the table name from the URL
    final pathSegments = url.pathSegments;
    final restIndex = pathSegments.indexOf('v1');
    if (restIndex != -1 && restIndex < pathSegments.length - 1) {
      return pathSegments[restIndex + 1];
    }
    throw Exception('Invalid URL format: unable to extract table name');
  }

  StreamedResponse _handleInsert(
      String tableName, dynamic data, BaseRequest request) {
    // Handle inserting data into the mock database
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (!_database.containsKey(tableName)) {
      _database[tableName] = [];
    }
    if (data is! Map<String, dynamic>) {
      return _createResponse({'error': 'Invalid data format'},
          statusCode: 400, request: request);
    }
    _database[tableName]!.add(data);
    return _createResponse(data, request: request);
  }

  StreamedResponse _handleUpdate(
      String tableName, dynamic data, BaseRequest request) {
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

    // Update items that match the filters
    if (_database.containsKey(tableName)) {
      for (var row in _database[tableName]!) {
        if (_matchesFilters(row, queryParams)) {
          row.addAll(data);
          updated = true;
        }
      }
    }

    if (updated) {
      return _createResponse(data, request: request);
    } else {
      return _createResponse({'error': 'Not found'},
          statusCode: 404, request: request);
    }
  }

  /// Checks if a given item matches the provided filters.
  ///
  /// This method iterates through each filter in the `filters` map,
  /// parses the filter using `_parseFilter`, and applies it to the `item`.
  /// If any filter doesn't match, the method returns false.
  /// If all filters match, it returns true.
  ///
  /// [item] The item to check against the filters.
  /// [filters] A map of filter keys and their corresponding values.
  /// Returns true if the item matches all filters, false otherwise.
  bool _matchesFilters(Map<String, dynamic> item, Map<String, String> filters) {
    // Check if an item matches the provided filters
    for (var key in filters.keys) {
      final filter = _parseFilter(key, filters[key]!);
      if (!filter(item)) {
        return false;
      }
    }
    return true;
  }

  StreamedResponse _handleUpsert(
      String tableName, dynamic data, BaseRequest request) {
    // Handle upserting data into the mock database
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (!_database.containsKey(tableName)) {
      _database[tableName] = [];
    }

    // Convert data to a list of items
    final List<Map<String, dynamic>> items = data is List
        ? List<Map<String, dynamic>>.from(data)
        : [Map<String, dynamic>.from(data)];

    // Upsert each item
    final results = items.map((item) {
      final id = item['id'];
      if (id != null) {
        final index =
            _database[tableName]!.indexWhere((dbItem) => dbItem['id'] == id);
        if (index != -1) {
          _database[tableName]![index] = {
            ..._database[tableName]![index],
            ...item
          };
          return _database[tableName]![index];
        }
      }
      _database[tableName]!.add(item);
      return item;
    }).toList();

    return _createResponse(results, request: request);
  }

  StreamedResponse _handleDelete(
      String tableName, dynamic data, BaseRequest request) {
    // Handle deleting data from the mock database
    final queryParams = request.url.queryParameters;
    if (queryParams.isEmpty) {
      return _createResponse({'error': 'No query parameters provided'},
          statusCode: 400, request: request);
    }

    if (_database.containsKey(tableName)) {
      _database[tableName]!
          .removeWhere((item) => _matchesFilters(item, queryParams));
    }

    return _createResponse({'message': 'Deleted'}, request: request);
  }

  StreamedResponse _handleSelect(
      String tableName, Map<String, String> queryParams, BaseRequest request) {
    // Handle selecting data from the mock database
    if (!_database.containsKey(tableName)) {
      return _createResponse([], request: request);
    }

    var result = List<Map<String, dynamic>>.from(_database[tableName]!);

    // Handle basic filtering
    queryParams.forEach((key, value) {
      if (key != 'select') {
        final filter = _parseFilter(key, value);
        result = result.where((item) => filter(item)).toList();
      }
    });

    return _createResponse(result, request: request);
  }

  Function(Map<String, dynamic>) _parseFilter(String key, String value) {
    // Parse filters from query parameters
    if (key.contains('eq.')) {
      final field = key.split('eq.')[1];
      return (item) => item[field] == value;
    } else if (key.contains('neq.')) {
      final field = key.split('neq.')[1];
      return (item) => item[field] != value;
    } else if (key.contains('gte.')) {
      final field = key.split('gte.')[1];
      return (item) => item[field] >= num.tryParse(value);
    } else if (key.contains('lte.')) {
      final field = key.split('lte.')[1];
      return (item) => item[field] <= num.tryParse(value);
    } else if (key.contains('like.')) {
      final field = key.split('like.')[1];
      final regex = RegExp(value.replaceAll('%', '.*'));
      return (item) => regex.hasMatch(item[field]);
    } else if (key.contains('is.')) {
      final field = key.split('is.')[1];
      return (item) => item[field] == null;
    }
    return (item) => true;
  }

  StreamedResponse _createResponse(dynamic data,
      {int statusCode = 200, required BaseRequest request}) {
    // Create a response for the mock client
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(data))),
      statusCode,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
