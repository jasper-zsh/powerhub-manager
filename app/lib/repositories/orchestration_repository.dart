import 'package:app/models/orchestration/execution_log_entry.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/services/storage_service.dart';

class OrchestrationRepository {
  OrchestrationRepository({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  final StorageService _storageService;
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await _storageService.init();
    _initialized = true;
  }

  Future<List<ToggleScene>> loadScenes() async {
    await ensureInitialized();
    return _storageService.loadToggleScenes();
  }

  Future<ToggleScene> upsertScene(ToggleScene scene) async {
    await ensureInitialized();
    return _storageService.upsertToggleScene(scene);
  }

  Future<void> deleteScene(String sceneId) async {
    await ensureInitialized();
    return _storageService.deleteToggleScene(sceneId);
  }

  Future<List<ExecutionLogEntry>> loadExecutionLogs() async {
    await ensureInitialized();
    return _storageService.loadExecutionLogs();
  }

  Future<void> appendExecutionLog(ExecutionLogEntry entry) async {
    await ensureInitialized();
    return _storageService.appendExecutionLog(entry);
  }

  Future<void> clearExecutionLogs() async {
    await ensureInitialized();
    return _storageService.clearExecutionLogs();
  }
}
