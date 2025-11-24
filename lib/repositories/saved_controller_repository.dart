import 'dart:async';

import 'package:app/models/saved_controller.dart';
import 'package:app/services/storage_service.dart';

/// SavedController 数据的仓库封装，集中处理 SharedPreferences 初始化与序列化，
/// 并通过流推送最新列表，确保 Riverpod 与传统 Provider 可以共享数据源。
class SavedControllerRepository {
  factory SavedControllerRepository({StorageService? storageService}) {
    if (storageService != null) {
      return SavedControllerRepository._(storageService);
    }
    _defaultInstance ??= SavedControllerRepository._(StorageService());
    return _defaultInstance!;
  }

  SavedControllerRepository._(StorageService storageService)
      : _storageService = storageService;

  static SavedControllerRepository? _defaultInstance;

  final StorageService _storageService;
  bool _initialized = false;
  List<SavedController> _cache = const <SavedController>[];
  final _controllersController =
      StreamController<List<SavedController>>.broadcast();

  Stream<List<SavedController>> get controllersStream =>
      _controllersController.stream;
  List<SavedController> get currentControllers => _cache;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await _storageService.init();
    _initialized = true;
    await _refreshFromStorage();
  }

  Future<void> _refreshFromStorage() async {
    final controllers = await _storageService.loadSavedControllers();
    _setCache(controllers);
  }

  void _setCache(List<SavedController> controllers) {
    _cache = List<SavedController>.unmodifiable(controllers);
    if (!_controllersController.isClosed) {
      _controllersController.add(_cache);
    }
  }

  Future<List<SavedController>> loadSavedControllers() async {
    await ensureInitialized();
    await _refreshFromStorage();
    return _cache;
  }

  Future<SavedController> addSavedController(SavedController controller) async {
    await ensureInitialized();
    final saved = await _storageService.addSavedController(controller);
    await _refreshFromStorage();
    return saved;
  }

  Future<SavedController> renameSavedController(
    String controllerId,
    String alias,
  ) async {
    await ensureInitialized();
    final renamed = await _storageService.renameSavedController(
      controllerId,
      alias,
    );
    await _refreshFromStorage();
    return renamed;
  }

  Future<List<SavedController>> removeSavedController(String controllerId) async {
    await ensureInitialized();
    final updated = await _storageService.removeSavedController(controllerId);
    _setCache(updated);
    return _cache;
  }

  Future<void> persistSavedControllers(
    List<SavedController> controllers,
  ) async {
    await ensureInitialized();
    await _storageService.persistSavedControllers(controllers);
    _setCache(controllers);
  }

  Future<SavedController?> findSavedController(String controllerId) async {
    await ensureInitialized();
    return _storageService.findSavedController(controllerId);
  }

  Future<void> clearSavedControllers() async {
    await ensureInitialized();
    await _storageService.clearSavedControllers();
    _setCache(const <SavedController>[]);
  }

  void dispose() {
    if (!_controllersController.isClosed) {
      _controllersController.close();
    }
  }
}
