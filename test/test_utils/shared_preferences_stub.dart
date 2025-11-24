import 'package:shared_preferences/shared_preferences.dart';

/// Resets the shared preferences mock store with provided initial values.
Future<void> resetSharedPreferences({
  Map<String, Object> values = const {},
}) async {
  SharedPreferences.setMockInitialValues(values);
  await SharedPreferences.getInstance();
}

/// Returns a writable shared preferences instance seeded with optional values.
Future<SharedPreferences> getTestSharedPreferences({
  Map<String, Object> values = const {},
}) async {
  await resetSharedPreferences(values: values);
  return SharedPreferences.getInstance();
}
