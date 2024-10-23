import 'dart:convert';

import 'package:http/http.dart';

import 'mock_supabase_database.dart';

class MockSupabaseHttpClient extends BaseClient {
  final Map<String, List<Map<String, dynamic>>> _database = {};
  final Map<
          String,
          dynamic Function(
              MockSupabaseDatabase database, Map<String, dynamic>? params)>
      _rpcFunctions = {};

  MockSupabaseHttpClient();

  void reset() {
    // Clear the mock database and RPC functions
    _database.clear();
    _rpcFunctions.clear();
  }

  void registerRpcFunction(
      String name,
      dynamic Function(
              MockSupabaseDatabase database, Map<String, dynamic>? params)
          function) {
    _rpcFunctions[name] = function;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
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

    // Extract the table name or RPC function name from the URL
    final pathSegments = request.url.pathSegments;
    final restIndex = pathSegments.indexOf('v1');
    if (restIndex != -1 && restIndex < pathSegments.length - 1) {
      final resourceName = pathSegments[restIndex + 1];

      if (resourceName == 'rpc') {
        // Handle RPC call
        if (pathSegments.length > restIndex + 2) {
          final functionName = pathSegments[restIndex + 2];
          return _handleRpc(functionName, request, body);
        } else {
          return _createResponse({'error': 'RPC function name not provided'},
              statusCode: 400, request: request);
        }
      } else {
        // Handle regular database operations
        final tableName = _extractTableName(
          url: request.url,
          headers: request.headers,
          method: request.method,
        );

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
            return _handleSelect(
                tableName, request.url.queryParameters, request);
          case 'HEAD':
            return _handleHead(tableName, request.url.queryParameters, request);
          default:
            return _createResponse({'error': 'Method not allowed'},
                statusCode: 405, request: request);
        }
      }
    }
    throw Exception('Invalid URL format: unable to extract table name');
  }

  String _extractTableName({
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
      String? customSchema;
      if (method == 'GET' || method == 'HEAD') {
        customSchema = headers['Accept-Profile'];
      } else {
        customSchema = headers['Content-Profile'];
      }

      // Prepend custom schema if present
      if (customSchema != null && customSchema.isNotEmpty) {
        return '$customSchema.$tableName';
      }

      return tableName;
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
    if (data is Map<String, dynamic>) {
      _database[tableName]!.add(data);
      return _createResponse(data, request: request);
    } else if (data is List) {
      final List<Map<String, dynamic>> items =
          List<Map<String, dynamic>>.from(data);
      _database[tableName]!.addAll(items);
      return _createResponse(items, request: request);
    } else {
      return _createResponse({'error': 'Invalid data format'},
          statusCode: 400, request: request);
    }
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
        if (_matchesFilters(row: row, filters: queryParams)) {
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
  /// [row] The item to check against the filters.
  /// [filters] A map of filter keys and their corresponding values.
  /// Returns true if the item matches all filters, false otherwise.
  bool _matchesFilters({
    required Map<String, dynamic> row,
    required Map<String, String> filters,
  }) {
    // Check if an item matches the provided filters
    for (var columnName in filters.keys) {
      final filter = _parseFilter(
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
      _database[tableName]!.removeWhere(
          (row) => _matchesFilters(row: row, filters: queryParams));
    }

    return _createResponse({'message': 'Deleted'}, request: request);
  }

  StreamedResponse _handleSelect(
    String tableName,
    Map<String, String> queryParams,
    BaseRequest request,
  ) {
    // Handle selecting data from the mock database
    if (!_database.containsKey(tableName)) {
      return _createResponse([], request: request);
    }

    var returningRows = List<Map<String, dynamic>>.from(_database[tableName]!);

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
          final filter = _parseFilter(
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
          final filter = _parseFilter(
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
        'content-profile': tableName,
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
      String tableName, Map<String, String> queryParams, BaseRequest request) {
    // Perform the same filtering as in _handleSelect
    var returningRows =
        List<Map<String, dynamic>>.from(_database[tableName] ?? []);

    // Apply filters (you may want to extract this to a separate method)
    queryParams.forEach((key, value) {
      if (key != 'select' &&
          key != 'order' &&
          key != 'limit' &&
          key != 'range') {
        final filter = _parseFilter(
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
          'content-profile': tableName,
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
        'content-profile': tableName,
      },
      request: request,
    );
  }

  bool Function(Map<String, dynamic> row) _parseFilter({
    required String columnName,
    required String postrestFilter,
    required Map<String, dynamic> targetRow,
  }) {
    // Parse filters from query parameters
    if (columnName == 'or') {
      final orFilters =
          postrestFilter.substring(1, postrestFilter.length - 1).split(',');
      return (row) {
        return orFilters.any((filter) {
          final parts = filter.split('.');
          final subColumnName = parts[0];
          final operator = parts[1];
          final value = parts.sublist(2).join('.');
          final subFilter = _parseFilter(
              columnName: subColumnName,
              postrestFilter: '$operator.$value',
              targetRow: row);
          return subFilter(row);
        });
      };
    } else if (postrestFilter.startsWith('eq.')) {
      final value = postrestFilter.substring(3);
      return (row) => row[columnName].toString() == value;
    } else if (postrestFilter.startsWith('neq.')) {
      final value = postrestFilter.substring(4);
      return (row) => row[columnName].toString() != value;
    } else if (postrestFilter.startsWith('gt.')) {
      return _handleComparison(
        operator: 'gt',
        value: postrestFilter.substring(3),
        columnName: columnName,
      );
    } else if (postrestFilter.startsWith('lt.')) {
      return _handleComparison(
        operator: 'lt',
        value: postrestFilter.substring(3),
        columnName: columnName,
      );
    } else if (postrestFilter.startsWith('gte.')) {
      return _handleComparison(
        operator: 'gte',
        value: postrestFilter.substring(4),
        columnName: columnName,
      );
    } else if (postrestFilter.startsWith('lte.')) {
      return _handleComparison(
        operator: 'lte',
        value: postrestFilter.substring(4),
        columnName: columnName,
      );
    } else if (postrestFilter.startsWith('like.')) {
      final value = postrestFilter.substring(5);
      final regex = RegExp(value.replaceAll('%', '.*'));
      return (row) => regex.hasMatch(row[columnName]);
    } else if (postrestFilter == 'is.null') {
      return (row) => row[columnName] == null;
    } else if (postrestFilter.startsWith('in.')) {
      final value = postrestFilter.substring(3);
      final values = value.substring(1, value.length - 1).split(',');
      return (row) => values.contains(row[columnName].toString());
    } else if (postrestFilter.startsWith('cs.')) {
      final value = postrestFilter.substring(3);
      if (value.startsWith('{') && value.endsWith('}')) {
        // Array case
        final values = value.substring(1, value.length - 1).split(',');
        return (row) => values.every((v) {
              final decodedValue = v.startsWith('"') && v.endsWith('"')
                  ? jsonDecode(v)
                  : v.toString();
              return (row[columnName] as List).contains(decodedValue);
            });
      } else {
        throw UnimplementedError(
            'JSON and range operators in contains is not yet supported');
      }
    } else if (postrestFilter.startsWith('containedBy.')) {
      final value = postrestFilter.substring(12);
      final values = jsonDecode(value);
      return (row) =>
          values.every((v) => (row[columnName] as List).contains(v));
    } else if (postrestFilter.startsWith('overlaps.')) {
      final value = postrestFilter.substring(9);
      final values = jsonDecode(value);
      return (row) =>
          (row[columnName] as List).any((element) => values.contains(element));
    } else if (postrestFilter.startsWith('fts.')) {
      final value = postrestFilter.substring(4);
      return (row) => (row[columnName] as String).contains(value);
    } else if (postrestFilter.startsWith('match.')) {
      final value = jsonDecode(postrestFilter.substring(6));
      return (row) {
        if (row[columnName] is! Map) return false;
        final rowMap = row[columnName] as Map<String, dynamic>;
        return value.entries.every((entry) => rowMap[entry.key] == entry.value);
      };
    } else if (postrestFilter.startsWith('not.')) {
      final parts = postrestFilter.split('.');
      final operator = parts[1];
      final value = parts.sublist(2).join('.');
      final filter = _parseFilter(
        columnName: columnName,
        postrestFilter: '$operator.$value',
        targetRow: targetRow,
      );
      return (row) => !filter(row);
    }
    return (row) => true;
  }

  /// Handles comparison operations for date and numeric values.
  ///
  /// This function creates a filter based on the given comparison [operator],
  /// [value], and [columnName]. It supports both date and numeric comparisons.
  ///
  /// [operator] can be 'gt', 'lt', 'gte', or 'lte'.
  /// [value] is the string representation of the value to compare against.
  /// [columnName] is the name of the column to compare in each row.
  ///
  /// Returns a function that takes a row and returns a boolean indicating
  /// whether the row matches the comparison criteria.
  bool Function(Map<String, dynamic> row) _handleComparison({
    required String operator,
    required String value,
    required String columnName,
  }) {
    // Check if the value is a valid date
    if (DateTime.tryParse(value) != null) {
      final dateTime = DateTime.parse(value);
      return (row) {
        final rowDate = DateTime.tryParse(row[columnName].toString());
        if (rowDate == null) return false;
        // Perform date comparison based on the operator
        switch (operator) {
          case 'gt':
            return rowDate.isAfter(dateTime);
          case 'lt':
            return rowDate.isBefore(dateTime);
          case 'gte':
            return rowDate.isAtSameMomentAs(dateTime) ||
                rowDate.isAfter(dateTime);
          case 'lte':
            return rowDate.isAtSameMomentAs(dateTime) ||
                rowDate.isBefore(dateTime);
          default:
            throw UnimplementedError('Unsupported operator: $operator');
        }
      };
    }
    // Check if the value is a valid number
    else if (num.tryParse(value) != null) {
      final numValue = num.parse(value);
      return (row) {
        final rowValue = num.tryParse(row[columnName].toString());
        if (rowValue == null) return false;
        // Perform numeric comparison based on the operator
        switch (operator) {
          case 'gt':
            return rowValue > numValue;
          case 'lt':
            return rowValue < numValue;
          case 'gte':
            return rowValue >= numValue;
          case 'lte':
            return rowValue <= numValue;
          default:
            throw UnimplementedError('Unsupported operator: $operator');
        }
      };
    }
    // Throw an error if the value is neither a date nor a number
    else {
      throw UnimplementedError('Unsupported value type');
    }
  }

  StreamedResponse _createResponse(dynamic data,
      {int statusCode = 200,
      required BaseRequest request,
      Map<String, String>? headers}) {
    final responseHeaders = {
      'content-type': 'application/json; charset=utf-8',
      ...?headers,
    };

    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(data))),
      statusCode,
      headers: responseHeaders,
      request: request,
    );
  }

  StreamedResponse _handleRpc(
      String functionName, BaseRequest request, dynamic body) {
    if (!_rpcFunctions.containsKey(functionName)) {
      return _createResponse({'error': 'RPC function not found'},
          statusCode: 404, request: request);
    }

    final function = _rpcFunctions[functionName]!;

    try {
      final mockDatabase = MockSupabaseDatabase(_database);
      final result = function(mockDatabase, body);
      return _createResponse(result, request: request);
    } catch (e) {
      return _createResponse({'error': 'RPC function execution failed: $e'},
          statusCode: 500, request: request);
    }
  }
}
