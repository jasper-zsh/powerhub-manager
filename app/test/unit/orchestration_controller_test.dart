import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/orchestration_controller.dart';
import 'package:app/repositories/orchestration_repository.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/execution_log_entry.dart';
import 'package:app/models/saved_controller.dart';

import 'orchestration_controller_test.mocks.dart';

@GenerateMocks([OrchestrationRepository])
void main() {
  group('OrchestrationController', () {
    late ProviderContainer container;
    late MockOrchestrationRepository mockOrchestrationRepository;

    setUp(() {
      mockOrchestrationRepository = MockOrchestrationRepository();
      
      container = ProviderContainer(
        overrides: [
          orchestrationRepositoryProvider.overrideWithValue(mockOrchestrationRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have empty scenes and logs', () {
      final state = container.read(orchestrationControllerProvider);
      
      expect(state.scenes, isEmpty);
      expect(state.executionLogs, isEmpty);
      expect(state.isExecuting, false);
      expect(state.missingControllers, isEmpty);
    });

    test('loadScenes should update state with scenes', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final scenes = [
        ToggleScene(
          id: 'scene-1',
          name: 'Test Scene 1',
          description: 'Description 1',
          commands: [],
          createdAt: DateTime.now(),
        ),
        ToggleScene(
          id: 'scene-2',
          name: 'Test Scene 2',
          description: 'Description 2',
          commands: [],
          createdAt: DateTime.now(),
        ),
      ];
      
      when(mockOrchestrationRepository.getScenes())
          .thenAnswer((_) async => scenes);
      
      await controller.loadScenes();
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.scenes.length, 2);
      expect(state.scenes[0].name, 'Test Scene 1');
      expect(state.scenes[1].name, 'Test Scene 2');
      verify(mockOrchestrationRepository.getScenes()).called(1);
    });

    test('loadExecutionLogs should update state with logs', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final logs = [
        ExecutionLogEntry(
          id: 'log-1',
          sceneId: 'scene-1',
          sceneName: 'Test Scene 1',
          executedAt: DateTime.now(),
          status: ExecutionStatus.success,
        ),
        ExecutionLogEntry(
          id: 'log-2',
          sceneId: 'scene-2',
          sceneName: 'Test Scene 2',
          executedAt: DateTime.now(),
          status: ExecutionStatus.failed,
          error: 'Connection failed',
        ),
      ];
      
      when(mockOrchestrationRepository.getExecutionLogs())
          .thenAnswer((_) async => logs);
      
      await controller.loadExecutionLogs();
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.executionLogs.length, 2);
      expect(state.executionLogs[0].sceneName, 'Test Scene 1');
      expect(state.executionLogs[1].sceneName, 'Test Scene 2');
      verify(mockOrchestrationRepository.getExecutionLogs()).called(1);
    });

    test('createScene should add scene to state', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final scene = ToggleScene(
        id: 'scene-1',
        name: 'New Scene',
        description: 'New Description',
        commands: [],
        createdAt: DateTime.now(),
      );
      
      when(mockOrchestrationRepository.saveScene(scene))
          .thenAnswer((_) async {});
      
      await controller.createScene(scene);
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.scenes.length, 1);
      expect(state.scenes[0].name, 'New Scene');
      verify(mockOrchestrationRepository.saveScene(scene)).called(1);
    });

    test('updateScene should update scene in state', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final originalScene = ToggleScene(
        id: 'scene-1',
        name: 'Original Scene',
        description: 'Original Description',
        commands: [],
        createdAt: DateTime.now(),
      );
      final updatedScene = ToggleScene(
        id: 'scene-1',
        name: 'Updated Scene',
        description: 'Updated Description',
        commands: [],
        createdAt: DateTime.now(),
      );
      
      // First add the original scene
      when(mockOrchestrationRepository.saveScene(originalScene))
          .thenAnswer((_) async {});
      when(mockOrchestrationRepository.saveScene(updatedScene))
          .thenAnswer((_) async {});
      
      await controller.createScene(originalScene);
      await controller.updateScene(updatedScene);
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.scenes.length, 1);
      expect(state.scenes[0].name, 'Updated Scene');
      verify(mockOrchestrationRepository.saveScene(originalScene)).called(1);
      verify(mockOrchestrationRepository.saveScene(updatedScene)).called(1);
    });

    test('deleteScene should remove scene from state', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final scene = ToggleScene(
        id: 'scene-1',
        name: 'Test Scene',
        description: 'Test Description',
        commands: [],
        createdAt: DateTime.now(),
      );
      
      when(mockOrchestrationRepository.saveScene(scene))
          .thenAnswer((_) async {});
      when(mockOrchestrationRepository.deleteScene(scene.id))
          .thenAnswer((_) async {});
      
      await controller.createScene(scene);
      await controller.deleteScene(scene.id);
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.scenes, isEmpty);
      verify(mockOrchestrationRepository.saveScene(scene)).called(1);
      verify(mockOrchestrationRepository.deleteScene(scene.id)).called(1);
    });

    test('executeScene should update executing state and create log', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final scene = ToggleScene(
        id: 'scene-1',
        name: 'Test Scene',
        description: 'Test Description',
        commands: [],
        createdAt: DateTime.now(),
      );
      final connectedControllers = [
        SavedController(
          id: 'controller-1',
          name: 'Controller 1',
          address: '00:11:22:33:44:55',
          isConnected: true,
        ),
      ];
      
      when(mockOrchestrationRepository.saveScene(scene))
          .thenAnswer((_) async {});
      when(mockOrchestrationRepository.executeScene(scene, connectedControllers))
          .thenAnswer((_) async => ExecutionLogEntry(
            id: 'log-1',
            sceneId: scene.id,
            sceneName: scene.name,
            executedAt: DateTime.now(),
            status: ExecutionStatus.success,
          ));
      
      await controller.createScene(scene);
      await controller.executeScene(scene, connectedControllers);
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.isExecuting, false); // Should be false after execution
      expect(state.executionLogs.length, 1);
      expect(state.executionLogs[0].sceneName, 'Test Scene');
      expect(state.executionLogs[0].status, ExecutionStatus.success);
      verify(mockOrchestrationRepository.executeScene(scene, connectedControllers)).called(1);
    });

    test('executeScene with missing controllers should identify them', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final scene = ToggleScene(
        id: 'scene-1',
        name: 'Test Scene',
        description: 'Test Description',
        commands: [],
        createdAt: DateTime.now(),
      );
      final connectedControllers = [
        SavedController(
          id: 'controller-1',
          name: 'Controller 1',
          address: '00:11:22:33:44:55',
          isConnected: true,
        ),
      ];
      final missingControllers = [
        SavedController(
          id: 'controller-2',
          name: 'Controller 2',
          address: '00:11:22:33:44:66',
          isConnected: false,
        ),
      ];
      
      when(mockOrchestrationRepository.saveScene(scene))
          .thenAnswer((_) async {});
      when(mockOrchestrationRepository.executeScene(scene, connectedControllers))
          .thenThrow(Exception('Missing controllers: controller-2'));
      when(mockOrchestrationRepository.getMissingControllers(scene, connectedControllers))
          .thenReturn(missingControllers);
      
      await controller.createScene(scene);
      await controller.executeScene(scene, connectedControllers);
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.missingControllers.length, 1);
      expect(state.missingControllers[0].name, 'Controller 2');
      verify(mockOrchestrationRepository.getMissingControllers(scene, connectedControllers)).called(1);
    });

    test('clearExecutionLogs should remove all logs', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final logs = [
        ExecutionLogEntry(
          id: 'log-1',
          sceneId: 'scene-1',
          sceneName: 'Test Scene 1',
          executedAt: DateTime.now(),
          status: ExecutionStatus.success,
        ),
      ];
      
      when(mockOrchestrationRepository.getExecutionLogs())
          .thenAnswer((_) async => logs);
      when(mockOrchestrationRepository.clearExecutionLogs())
          .thenAnswer((_) async {});
      
      await controller.loadExecutionLogs();
      await controller.clearExecutionLogs();
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.executionLogs, isEmpty);
      verify(mockOrchestrationRepository.clearExecutionLogs()).called(1);
    });

    test('refresh should reload scenes and logs', () async {
      final controller = container.read(orchestrationControllerProvider.notifier);
      final scenes = [
        ToggleScene(
          id: 'scene-1',
          name: 'Test Scene',
          description: 'Test Description',
          commands: [],
          createdAt: DateTime.now(),
        ),
      ];
      final logs = [
        ExecutionLogEntry(
          id: 'log-1',
          sceneId: 'scene-1',
          sceneName: 'Test Scene',
          executedAt: DateTime.now(),
          status: ExecutionStatus.success,
        ),
      ];
      
      when(mockOrchestrationRepository.getScenes())
          .thenAnswer((_) async => scenes);
      when(mockOrchestrationRepository.getExecutionLogs())
          .thenAnswer((_) async => logs);
      
      await controller.refresh();
      
      final state = container.read(orchestrationControllerProvider);
      expect(state.scenes.length, 1);
      expect(state.executionLogs.length, 1);
      verify(mockOrchestrationRepository.getScenes()).called(1);
      verify(mockOrchestrationRepository.getExecutionLogs()).called(1);
    });
  });
}