import 'dart:convert';

/// A utility class for parsing and handling Postgrest filters
class FilterParser {
  /// Parses a filter string and returns a function that can be used to filter rows
  /// based on the parsed conditions.
  ///
  /// [columnName] The name of the column to filter on
  /// [postrestFilter] The filter string in Postgrest format
  /// [targetRow] A sample row used to determine data types
  static bool Function(Map<String, dynamic> row) parseFilter({
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
          final subFilter = parseFilter(
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
      return (row) => regex.hasMatch(row[columnName].toString());
    } else if (postrestFilter == 'is.null') {
      return (row) => row[columnName] == null;
    } else if (postrestFilter.startsWith('in.')) {
      final value = postrestFilter.substring(3);
      final values = _parseList(value.substring(1, value.length - 1));
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
      final filter = parseFilter(
        columnName: columnName,
        postrestFilter: '$operator.$value',
        targetRow: targetRow,
      );
      return (row) => !filter(row);
    }
    return (row) => true;
  }

  /// Splits the body of a Postgrest list on the commas that separate its
  /// elements, then unquotes and unescapes each element.
  ///
  /// Postgrest quotes any element that is not a bare number and escapes `\`
  /// and `"` inside it, so a naive split on commas would break on values that
  /// contain a comma or a quote.
  static List<String> _parseList(String body) {
    final values = <String>[];
    final buffer = StringBuffer();
    var insideQuotes = false;
    for (var index = 0; index < body.length; index++) {
      final character = body[index];
      if (character == '\\' && insideQuotes && index + 1 < body.length) {
        buffer.write(body[++index]);
      } else if (character == '"') {
        insideQuotes = !insideQuotes;
      } else if (character == ',' && !insideQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    values.add(buffer.toString());
    return values;
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
  static bool Function(Map<String, dynamic> row) _handleComparison({
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
}
