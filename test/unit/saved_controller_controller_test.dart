import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/repositories/saved_controller_repository.dart';
import 'package:app/models/saved_controller.dart';

import 'saved_controller_controller_test.mocks.dart';

@GenerateMocks([SavedControllerRepository])
void main() {
  group('SavedControllerController', () {
    late ProviderContainer container;
    late MockSavedControllerRepository mockSavedControllerRepository;

    setUp(() {
      mockSavedControllerRepository = MockSavedControllerRepository();
      
      container = ProviderContainer(
        overrides: [
          savedControllerRepositoryProvider.overrideWithValue(mockSavedControllerRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should be loading with empty controllers', () {
      final state = container.read(savedControllerControllerProvider);
      
      expect(state.status, SavedControllerStatus.loading);
      expect(state.controllers, isEmpty);
      expect(state.error, null);
    });

    test('loadControllers should update state with controllers', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final controllers = [
        SavedController(
          id: 'controller-1',
          name: 'Controller 1',
          address: '00:11:22:33:44:55',
          isConnected: false,
        ),
        SavedController(
          id: 'controller-2',
          name: 'Controller 2',
          address: '00:11:22:33:44:66',
          isConnected: true,
        ),
      ];
      
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => controllers);
      
      await controller.loadControllers();
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.status, SavedControllerStatus.loaded);
      expect(state.controllers.length, 2);
      expect(state.controllers[0].name, 'Controller 1');
      expect(state.controllers[1].name, 'Controller 2');
      verify(mockSavedControllerRepository.getAllControllers()).called(1);
    });

    test('loadControllers error should update state with error', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      
      when(mockSavedControllerRepository.getAllControllers())
          .thenThrow(Exception('Failed to load controllers'));
      
      await controller.loadControllers();
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.status, SavedControllerStatus.error);
      expect(state.error, 'Exception: Failed to load controllers');
      verify(mockSavedControllerRepository.getAllControllers()).called(1);
    });

    test('addController should add controller to state', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final newController = SavedController(
        id: 'controller-1',
        name: 'New Controller',
        address: '00:11:22:33:44:55',
        isConnected: false,
      );
      
      when(mockSavedControllerRepository.saveController(newController))
          .thenAnswer((_) async => newController);
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => [newController]);
      
      await controller.addController(newController);
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.status, SavedControllerStatus.loaded);
      expect(state.controllers.length, 1);
      expect(state.controllers[0].name, 'New Controller');
      verify(mockSavedControllerRepository.saveController(newController)).called(1);
    });

    test('updateController should update controller in state', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final originalController = SavedController(
        id: 'controller-1',
        name: 'Original Controller',
        address: '00:11:22:33:44:55',
        isConnected: false,
      );
      final updatedController = SavedController(
        id: 'controller-1',
        name: 'Updated Controller',
        address: '00:11:22:33:44:55',
        isConnected: true,
      );
      
      when(mockSavedControllerRepository.saveController(originalController))
          .thenAnswer((_) async => originalController);
      when(mockSavedControllerRepository.saveController(updatedController))
          .thenAnswer((_) async => updatedController);
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => [originalController]);
      
      await controller.addController(originalController);
      await controller.updateController(updatedController);
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.controllers.length, 1);
      expect(state.controllers[0].name, 'Updated Controller');
      expect(state.controllers[0].isConnected, true);
      verify(mockSavedControllerRepository.saveController(originalController)).called(1);
      verify(mockSavedControllerRepository.saveController(updatedController)).called(1);
    });

    test('deleteController should remove controller from state', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final savedController = SavedController(
        id: 'controller-1',
        name: 'Test Controller',
        address: '00:11:22:33:44:55',
        isConnected: false,
      );
      
      when(mockSavedControllerRepository.saveController(savedController))
          .thenAnswer((_) async => savedController);
      when(mockSavedControllerRepository.deleteController(savedController.id))
          .thenAnswer((_) async {});
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => [savedController]);
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => []);
      
      await controller.addController(savedController);
      await controller.deleteController(savedController.id);
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.controllers, isEmpty);
      verify(mockSavedControllerRepository.saveController(savedController)).called(1);
      verify(mockSavedControllerRepository.deleteController(savedController.id)).called(1);
    });

    test('updateConnectionStatus should update controller connection status', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final savedController = SavedController(
        id: 'controller-1',
        name: 'Test Controller',
        address: '00:11:22:33:44:55',
        isConnected: false,
      );
      
      when(mockSavedControllerRepository.saveController(savedController))
          .thenAnswer((_) async => savedController);
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => [savedController]);
      
      await controller.addController(savedController);
      await controller.updateConnectionStatus(savedController.id, true);
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.controllers[0].isConnected, true);
    });

    test('getControllerById should return correct controller', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final controller1 = SavedController(
        id: 'controller-1',
        name: 'Controller 1',
        address: '00:11:22:33:44:55',
        isConnected: false,
      );
      final controller2 = SavedController(
        id: 'controller-2',
        name: 'Controller 2',
        address: '00:11:22:33:44:66',
        isConnected: true,
      );
      
      when(mockSavedControllerRepository.saveController(controller1))
          .thenAnswer((_) async => controller1);
      when(mockSavedControllerRepository.saveController(controller2))
          .thenAnswer((_) async => controller2);
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => [controller1, controller2]);
      
      await controller.addController(controller1);
      await controller.addController(controller2);
      
      final foundController = controller.getControllerById('controller-1');
      expect(foundController, isNotNull);
      expect(foundController!.name, 'Controller 1');
      
      final notFoundController = controller.getControllerById('controller-3');
      expect(notFoundController, isNull);
    });

    test('getConnectedControllers should return only connected controllers', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final controller1 = SavedController(
        id: 'controller-1',
        name: 'Controller 1',
        address: '00:11:22:33:44:55',
        isConnected: false,
      );
      final controller2 = SavedController(
        id: 'controller-2',
        name: 'Controller 2',
        address: '00:11:22:33:44:66',
        isConnected: true,
      );
      final controller3 = SavedController(
        id: 'controller-3',
        name: 'Controller 3',
        address: '00:11:22:33:44:77',
        isConnected: true,
      );
      
      when(mockSavedControllerRepository.saveController(controller1))
          .thenAnswer((_) async => controller1);
      when(mockSavedControllerRepository.saveController(controller2))
          .thenAnswer((_) async => controller2);
      when(mockSavedControllerRepository.saveController(controller3))
          .thenAnswer((_) async => controller3);
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => [controller1, controller2, controller3]);
      
      await controller.addController(controller1);
      await controller.addController(controller2);
      await controller.addController(controller3);
      
      final connectedControllers = controller.getConnectedControllers();
      expect(connectedControllers.length, 2);
      expect(connectedControllers[0].name, 'Controller 2');
      expect(connectedControllers[1].name, 'Controller 3');
    });

    test('refresh should reload controllers', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final controllers = [
        SavedController(
          id: 'controller-1',
          name: 'Controller 1',
          address: '00:11:22:33:44:55',
          isConnected: false,
        ),
      ];
      
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => controllers);
      
      await controller.refresh();
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.status, SavedControllerStatus.loaded);
      expect(state.controllers.length, 1);
      verify(mockSavedControllerRepository.getAllControllers()).called(1);
    });

    test('clearAll should remove all controllers', () async {
      final controller = container.read(savedControllerControllerProvider.notifier);
      final savedController = SavedController(
        id: 'controller-1',
        name: 'Test Controller',
        address: '00:11:22:33:44:55',
        isConnected: false,
      );
      
      when(mockSavedControllerRepository.saveController(savedController))
          .thenAnswer((_) async => savedController);
      when(mockSavedControllerRepository.clearAllControllers())
          .thenAnswer((_) async {});
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => [savedController]);
      when(mockSavedControllerRepository.getAllControllers())
          .thenAnswer((_) async => []);
      
      await controller.addController(savedController);
      await controller.clearAll();
      
      final state = container.read(savedControllerControllerProvider);
      expect(state.controllers, isEmpty);
      verify(mockSavedControllerRepository.clearAllControllers()).called(1);
    });
  });
}