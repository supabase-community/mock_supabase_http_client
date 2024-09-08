import 'dart:convert';

import 'package:http/http.dart';

class MockSupabaseHttpClient extends BaseClient {
  final Map<String, List<Map<String, dynamic>>> _database = {};

  MockSupabaseHttpClient();

  void reset() {
    _database.clear();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final tableName = _extractTableName(request.url);

    final body = request.method != 'GET' && request is Request
        ? jsonDecode(await request.finalize().transform(utf8.decoder).join())
        : null;

    switch (request.method) {
      case 'POST':
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
    final pathSegments = url.pathSegments;
    final restIndex = pathSegments.indexOf('v1');
    if (restIndex != -1 && restIndex < pathSegments.length - 1) {
      return pathSegments[restIndex + 1];
    }
    throw Exception('Invalid URL format: unable to extract table name');
  }

  StreamedResponse _handleInsert(
      String tableName, dynamic data, BaseRequest request) {
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
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (data is! Map<String, dynamic>) {
      return _createResponse({'error': 'Invalid data format'},
          statusCode: 400, request: request);
    }
    final id = data['id'];
    final index =
        _database[tableName]?.indexWhere((item) => item['id'] == id) ?? -1;
    if (index != -1) {
      _database[tableName]![index] = {..._database[tableName]![index], ...data};
      return _createResponse(_database[tableName]![index], request: request);
    }
    return _createResponse({'error': 'Not found'},
        statusCode: 404, request: request);
  }

  StreamedResponse _handleUpsert(
      String tableName, dynamic data, BaseRequest request) {
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (data is! List) {
      return _createResponse({'error': 'Invalid data format'},
          statusCode: 400, request: request);
    }
    if (!_database.containsKey(tableName)) {
      _database[tableName] = [];
    }

    final results = data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid item format in upsert data');
      }
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
    if (data == null) {
      return _createResponse({'error': 'No data provided'},
          statusCode: 400, request: request);
    }
    if (data is! Map<String, dynamic>) {
      return _createResponse({'error': 'Invalid data format'},
          statusCode: 400, request: request);
    }
    final id = data['id'];
    _database[tableName]?.removeWhere((item) => item['id'] == id);
    return _createResponse({'message': 'Deleted'}, request: request);
  }

  StreamedResponse _handleSelect(
      String tableName, Map<String, String> queryParams, BaseRequest request) {
    if (!_database.containsKey(tableName)) {
      return _createResponse([], request: request);
    }

    var result = List<Map<String, dynamic>>.from(_database[tableName]!);

    // Handle basic filtering
    queryParams.forEach((key, value) {
      if (key != 'select') {
        result = result.where((item) => item[key].toString() == value).toList();
      }
    });

    return _createResponse(result, request: request);
  }

  StreamedResponse _createResponse(dynamic data,
      {int statusCode = 200, required BaseRequest request}) {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(data))),
      statusCode,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
