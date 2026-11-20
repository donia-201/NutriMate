import 'package:nutri_mate/presentation/cubit/profile_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';


Future<SharedPreferencesWithCache> makeTestPrefs({
  Map<String, Object> initial = const {},
}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initial);

  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: ProfileCubit.keys,
    ),
  );
}