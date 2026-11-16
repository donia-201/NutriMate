import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Creates an in-memory SharedPreferencesWithCache for tests.
Future<SharedPreferencesWithCache> makeTestPrefs({
  Map<String, Object> initial = const {},
  Set<String> allowList = const {'themeMode', 'dietary', 'calorieGoal'},
}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initial);
  return SharedPreferencesWithCache.create(
    cacheOptions: SharedPreferencesWithCacheOptions(allowList: allowList),
  );
}
