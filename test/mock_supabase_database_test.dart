import 'package:mock_supabase_http_client/src/mock_supabase_database.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseDatabase db;

  setUp(() {
    db = MockSupabaseDatabase({});
  });

  group('basic CRUD operations', () {
    test('insert single row', () {
      final result = db.from('users').insert({'id': 1, 'name': 'John'});
      expect(result, [
        {'id': 1, 'name': 'John'}
      ]);
    });

    test('insert multiple rows', () {
      final result = db.from('users').insert([
        {'id': 1, 'name': 'John'},
        {'id': 2, 'name': 'Jane'}
      ]);
      expect(result.length, 2);
    });

    test('select returns empty list for non-existent table', () {
      final result = db.from('non_existent').select();
      expect(result, isEmpty);
    });

    test('update single row', () {
      db.from('users').insert([
        {'id': 1, 'name': 'John', 'age': 25},
        {'id': 2, 'name': 'Jane', 'age': 30},
      ]);

      final result = db.from('users').eq('name', 'John').update({'age': 26});
      expect(result.length, 1);
      expect(result.first['age'], 26);
    });

    test('update multiple rows', () {
      db.from('users').insert([
        {'id': 1, 'name': 'John', 'age': 25},
        {'id': 2, 'name': 'Jane', 'age': 30},
      ]);

      final result =
          db.from('users').gte('age', 25).update({'status': 'active'});
      expect(result.length, 2);
      expect(result.every((user) => user['status'] == 'active'), true);
    });

    test('update returns empty list for non-existent table', () {
      final result = db.from('non_existent').update({'name': 'John'});
      expect(result, isEmpty);
    });

    test('delete single row', () {
      db.from('users').insert([
        {'id': 1, 'name': 'John', 'age': 25},
        {'id': 2, 'name': 'Jane', 'age': 30},
      ]);

      final deleted = db.from('users').eq('name', 'John').delete();
      expect(deleted.length, 1);
      expect(deleted.first['name'], 'John');

      final remaining = db.from('users').select();
      expect(remaining.length, 1);
    });

    test('delete multiple rows', () {
      db.from('users').insert([
        {'id': 1, 'name': 'John', 'age': 25},
        {'id': 2, 'name': 'Jane', 'age': 30},
        {'id': 3, 'name': 'Bob', 'age': 20},
      ]);

      final deleted = db.from('users').gte('age', 25).delete();
      expect(deleted.length, 2);

      final remaining = db.from('users').select();
      expect(remaining.length, 1);
      expect(remaining.first['name'], 'Bob');
    });

    test('delete returns empty list for non-existent table', () {
      final result = db.from('non_existent').delete();
      expect(result, isEmpty);
    });
  });

  group('filtering operations', () {
    setUp(() {
      db.from('users').insert([
        {'id': 1, 'name': 'John', 'age': 25},
        {'id': 2, 'name': 'Jane', 'age': 30},
        {'id': 3, 'name': 'Bob', 'age': 20},
      ]);
    });

    test('eq filter', () {
      final result = db.from('users').eq('name', 'John').select();
      expect(result.length, 1);
      expect(result.first['name'], 'John');
    });

    test('neq filter', () {
      final result = db.from('users').neq('name', 'John').select();
      expect(result.length, 2);
      expect(result.every((user) => user['name'] != 'John'), true);
    });

    test('gt filter', () {
      final result = db.from('users').gt('age', 25).select();
      expect(result.length, 1);
      expect(result.first['name'], 'Jane');
    });

    test('lt filter', () {
      final result = db.from('users').lt('age', 25).select();
      expect(result.length, 1);
      expect(result.first['name'], 'Bob');
    });

    test('gte filter', () {
      final result = db.from('users').gte('age', 25).select();
      expect(result.length, 2);
      expect(result.map((user) => user['name']).toList()..sort(),
          ['Jane', 'John']);
    });

    test('lte filter', () {
      final result = db.from('users').lte('age', 25).select();
      expect(result.length, 2);
      expect(
          result.map((user) => user['name']).toList()..sort(), ['Bob', 'John']);
    });
  });

  group('ordering operations', () {
    setUp(() {
      db.from('users').insert([
        {'id': 1, 'name': 'John', 'age': 25, 'city': 'New York'},
        {'id': 2, 'name': 'Jane', 'age': 30, 'city': 'Boston'},
        {'id': 3, 'name': 'Bob', 'age': 25, 'city': 'Chicago'},
      ]);
    });

    test('single column ordering ascending', () {
      final result = db.from('users').order('name', ascending: true).select();
      expect(
          result.map((user) => user['name']).toList(), ['Bob', 'Jane', 'John']);
    });

    test('single column ordering descending', () {
      final result = db.from('users').order('name', ascending: false).select();
      expect(
          result.map((user) => user['name']).toList(), ['John', 'Jane', 'Bob']);
    });

    test('multiple column ordering', () {
      final result = db
          .from('users')
          .order('age', ascending: true)
          .order('name', ascending: true)
          .select();

      expect(result.map((user) => '${user['age']}-${user['name']}').toList(),
          ['25-Bob', '25-John', '30-Jane']);
    });
  });

  group('pagination operations', () {
    setUp(() {
      db.from('users').insert([
        {'id': 1, 'name': 'John'},
        {'id': 2, 'name': 'Jane'},
        {'id': 3, 'name': 'Bob'},
        {'id': 4, 'name': 'Alice'},
        {'id': 5, 'name': 'Charlie'},
      ]);
    });

    test('limit results', () {
      final result = db.from('users').limit(2).select();
      expect(result.length, 2);
    });

    test('offset results', () {
      final result = db.from('users').offset(2).select();
      expect(result.length, 3);
    });

    test('limit and offset combination', () {
      final result = db.from('users').limit(2).offset(2).select();
      expect(result.length, 2);
    });
  });
}
