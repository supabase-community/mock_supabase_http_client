import 'package:supabase/supabase.dart';

import 'mock_supabase_http_client.dart';

final mockSupabase = SupabaseClient(
  'https://mock.supabase.co',
  'fakeAnonKey',
  httpClient: MockSupabaseHttpClient(),
);
