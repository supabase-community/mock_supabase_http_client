/// A class that provides a Supabase-like interface for manipulating mock data
class MockSupabaseDatabase {
  final Map<String, List<Map<String, dynamic>>> _database;

  MockSupabaseDatabase(this._database);

  /// Creates a query builder for the specified table
  MockSupabaseQueryBuilder from(String table) {
    return MockSupabaseQueryBuilder(_database, table);
  }
}

/// A query builder that provides Supabase-like methods for querying and
/// manipulating data
class MockSupabaseQueryBuilder {
  final Map<String, List<Map<String, dynamic>>> _database;
  final String _table;
  final Map<String, String> _filters = {};
  int? _limitValue;
  int? _offsetValue;
  // Replace single order column and ascending flag with a list of order conditions
  final List<({String column, bool ascending})> _orderClauses = [];

  MockSupabaseQueryBuilder(this._database, this._table);

  /// Filters rows where [column] equals [value]
  MockSupabaseQueryBuilder eq(String column, dynamic value) {
    _filters[column] = 'eq.$value';
    return this;
  }

  /// Filters rows where [column] does not equal [value]
  MockSupabaseQueryBuilder neq(String column, dynamic value) {
    _filters[column] = 'neq.$value';
    return this;
  }

  /// Filters rows where [column] is greater than [value]
  MockSupabaseQueryBuilder gt(String column, dynamic value) {
    _filters[column] = 'gt.$value';
    return this;
  }

  /// Filters rows where [column] is less than [value]
  MockSupabaseQueryBuilder lt(String column, dynamic value) {
    _filters[column] = 'lt.$value';
    return this;
  }

  /// Filters rows where [column] is greater than or equal to [value]
  MockSupabaseQueryBuilder gte(String column, dynamic value) {
    _filters[column] = 'gte.$value';
    return this;
  }

  /// Filters rows where [column] is less than or equal to [value]
  MockSupabaseQueryBuilder lte(String column, dynamic value) {
    _filters[column] = 'lte.$value';
    return this;
  }

  /// Limits the number of rows returned
  MockSupabaseQueryBuilder limit(int limit) {
    _limitValue = limit;
    return this;
  }

  /// Sets the number of rows to skip
  MockSupabaseQueryBuilder offset(int offset) {
    _offsetValue = offset;
    return this;
  }

  /// Orders the results by [column] in ascending or descending order
  /// Can be called multiple times to sort by multiple columns
  MockSupabaseQueryBuilder order(String column, {bool ascending = false}) {
    _orderClauses.add((column: column, ascending: ascending));
    return this;
  }

  /// Inserts a new row or rows into the table
  List<Map<String, dynamic>> insert(dynamic data) {
    if (!_database.containsKey(_table)) {
      _database[_table] = [];
    }

    final List<Map<String, dynamic>> items = data is List
        ? List<Map<String, dynamic>>.from(data)
        : [Map<String, dynamic>.from(data)];

    _database[_table]!.addAll(items);
    return items;
  }

  /// Updates rows that match the query filters
  List<Map<String, dynamic>> update(Map<String, dynamic> data) {
    if (!_database.containsKey(_table)) return [];

    final updatedRows = <Map<String, dynamic>>[];
    for (var row in _database[_table]!) {
      if (_matchesFilters(row)) {
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow.addAll(data);
        updatedRows.add(updatedRow);
        _database[_table]![_database[_table]!.indexOf(row)] = updatedRow;
      }
    }
    return updatedRows;
  }

  /// Deletes rows that match the query filters
  List<Map<String, dynamic>> delete() {
    if (!_database.containsKey(_table)) return [];

    final deletedRows = <Map<String, dynamic>>[];
    _database[_table]!.removeWhere((row) {
      if (_matchesFilters(row)) {
        deletedRows.add(row);
        return true;
      }
      return false;
    });

    return deletedRows;
  }

  /// Selects rows that match the query filters
  List<Map<String, dynamic>> select() {
    if (!_database.containsKey(_table)) return [];

    var result =
        _database[_table]!.where((row) => _matchesFilters(row)).toList();

    if (_orderClauses.isNotEmpty) {
      result.sort((a, b) {
        for (final orderClause in _orderClauses) {
          final comparison = orderClause.ascending
              ? a[orderClause.column].compareTo(b[orderClause.column])
              : b[orderClause.column].compareTo(a[orderClause.column]);
          if (comparison != 0) return comparison;
        }
        return 0;
      });
    }

    if (_offsetValue != null) {
      result = result.skip(_offsetValue!).toList();
    }

    if (_limitValue != null) {
      result = result.take(_limitValue!).toList();
    }

    return result;
  }

  bool _matchesFilters(Map<String, dynamic> row) {
    for (var entry in _filters.entries) {
      final value = entry.value;
      if (value.startsWith('eq.')) {
        if (row[entry.key].toString() != value.substring(3)) return false;
      } else if (value.startsWith('neq.')) {
        if (row[entry.key].toString() == value.substring(4)) return false;
      } else if (value.startsWith('gt.')) {
        if (row[entry.key] <= num.parse(value.substring(3))) return false;
      } else if (value.startsWith('lt.')) {
        if (row[entry.key] >= num.parse(value.substring(3))) return false;
      } else if (value.startsWith('gte.')) {
        if (row[entry.key] < num.parse(value.substring(4))) return false;
      } else if (value.startsWith('lte.')) {
        if (row[entry.key] > num.parse(value.substring(4))) return false;
      }
    }
    return true;
  }
}
