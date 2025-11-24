import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/providers/orchestration_provider.dart';

final orchestrationProviderProvider = ChangeNotifierProvider<OrchestrationProvider>((ref) {
  final provider = OrchestrationProvider();
  ref.onDispose(provider.dispose);
  return provider;
});
