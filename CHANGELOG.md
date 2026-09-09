## 0.1.0

- docs: mark this package as discontinued in favor of `supabase_test` once supabase_flutter v3 is released
- fix: shape `.single()` responses after insert, update, upsert and delete [#29](https://github.com/supabase-community/mock_supabase_http_client/pull/29)
- fix: honor `ignoreDuplicates` in upsert [#28](https://github.com/supabase-community/mock_supabase_http_client/pull/28)
- docs: audit the current limitations list [#27](https://github.com/supabase-community/mock_supabase_http_client/pull/27)
- fix(inFilter): enable inFilter usage with strings [#24](https://github.com/supabase-community/mock_supabase_http_client/pull/24)
- fix: selecting with filter on empty table [#22](https://github.com/supabase-community/mock_supabase_http_client/pull/22)

## 0.0.3+2

- fix: Error on select after delete or update [#17](https://github.com/supabase-community/mock_supabase_http_client/pull/17)

## 0.0.3+1

- fix: Add support to datetime on gt. gte. lt. lte. filter [#8](https://github.com/supabase-community/mock_supabase_http_client/pull/8)

## 0.0.3

- feat: Add support for count and select with count. [#6](https://github.com/supabase-community/mock_supabase_http_client/pull/6)

## 0.0.2

- fix: Character encoding issues in mock response to handle non-ASCII characters correctly [#3](https://github.com/supabase-community/mock_supabase_http_client/pull/3)
- chore: Add a longer description and provide example [#4](https://github.com/supabase-community/mock_supabase_http_client/pull/4)

## 0.0.1

- Initial release.
- Basic CRUD operations (Create, Read, Update, Delete) and upsert support.
- Basic filtering support.
- Basic transformer (order, limit, range, single, maybeSingle) support.
- Basic referenced table support.
