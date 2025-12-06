import 'dart:async';

import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/services/ble_service.dart';

/// 抽象接口，用于与 SwitchHub 设备进行命令交互
abstract class SwitchHubCommandService {
  /// 预览将要执行的场景配置，返回执行预估信息
  Future<ExecutionPreview> previewExecution(ToggleScene scene);

  /// 执行指定的 ToggleScene，返回执行结果流
  Stream<ExecutionUpdate> executeScene(ToggleScene scene);

  /// 停止当前正在执行的场景
  Future<void> stopExecution();

  /// 获取当前执行状态
  Future<ExecutionStatus?> getCurrentExecutionStatus();

  /// 错误流，用于推送执行过程中的错误
  Stream<String> get errorStream;
}

/// 执行预览信息
class ExecutionPreview {
  final int estimatedSteps;
  final Duration estimatedDuration;
  final Set<String> requiredControllers;
  final List<String> warnings;

  const ExecutionPreview({
    required this.estimatedSteps,
    required this.estimatedDuration,
    required this.requiredControllers,
    this.warnings = const [],
  });
}

/// 执行状态更新
class ExecutionUpdate {
  final int currentStep;
  final int totalSteps;
  final String? currentAction;
  final ExecutionStatus status;
  final String? error;

  const ExecutionUpdate({
    required this.currentStep,
    required this.totalSteps,
    this.currentAction,
    required this.status,
    this.error,
  });
}

/// 执行状态
enum ExecutionStatus {
  idle,
  preparing,
  executing,
  completed,
  failed,
  cancelled,
}

/// SwitchHub 命令服务的 BLE 实现
class BleSwitchHubCommandService implements SwitchHubCommandService {
  BleSwitchHubCommandService({
    required BLEService bleService,
  }) : _bleService = bleService;

  final BLEService _bleService;
  final _errorController = StreamController<String>.broadcast();
  bool _isExecuting = false;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Future<ExecutionPreview> previewExecution(ToggleScene scene) async {
    final requiredControllers = <String>{};
    var estimatedSteps = 0;
    final warnings = <String>[];

    // 分析场景中的每个动作
    for (final state in scene.states) {
      for (final bundle in state.commandBundles) {
        for (final action in bundle.actions) {
          estimatedSteps++;
          requiredControllers.add(action.controllerId);

          // 检查控制器是否已连接（简化检查，因为BLEService不暴露deviceId）
          if (!_bleService.isConnected) {
            warnings.add('Controller ${action.controllerId} is not connected');
          }
        }
      }
    }

    // 估算执行时间（每个动作平均耗时 500ms）
    final estimatedDuration = Duration(milliseconds: estimatedSteps * 500);

    return ExecutionPreview(
      estimatedSteps: estimatedSteps,
      estimatedDuration: estimatedDuration,
      requiredControllers: requiredControllers,
      warnings: warnings,
    );
  }

  @override
  Stream<ExecutionUpdate> executeScene(ToggleScene scene) async* {
    if (_isExecuting) {
      yield const ExecutionUpdate(
        currentStep: 0,
        totalSteps: 0,
        status: ExecutionStatus.failed,
        error: 'Another execution is already in progress',
      );
      return;
    }

    _isExecuting = true;

    try {
      // Calculate total actions for progress tracking
      final allActions = <CommandAction>[];
      for (final state in scene.states) {
        for (final bundle in state.commandBundles) {
          allActions.addAll(bundle.actions);
        }
      }

      yield ExecutionUpdate(
        currentStep: 0,
        totalSteps: allActions.length,
        status: ExecutionStatus.preparing,
        currentAction: 'Preparing execution',
      );

      // 检查连接状态
      if (!_bleService.isConnected) {
        yield const ExecutionUpdate(
          currentStep: 0,
          totalSteps: 0,
          status: ExecutionStatus.failed,
          error: 'No device connected',
        );
        return;
      }

      yield ExecutionUpdate(
        currentStep: 0,
        totalSteps: allActions.length,
        status: ExecutionStatus.executing,
        currentAction: 'Starting execution',
      );

      // 执行场景中的每个动作
      for (var i = 0; i < allActions.length; i++) {
        final action = allActions[i];

        yield ExecutionUpdate(
          currentStep: i,
          totalSteps: allActions.length,
          status: ExecutionStatus.executing,
          currentAction: 'Executing action on ${action.controllerId}',
        );

        try {
          // 简化：直接发送命令，假设设备已连接
          // 在实际使用中，应该由连接会话控制器管理连接状态

          // 执行具体的 BLE 命令
          await _executeAction(action);
        } catch (error) {
          _errorController.add('Failed to execute action: $error');
          yield ExecutionUpdate(
            currentStep: i,
            totalSteps: allActions.length,
            status: ExecutionStatus.failed,
            error: 'Action failed: $error',
          );
          return;
        }
      }

      yield ExecutionUpdate(
        currentStep: allActions.length,
        totalSteps: allActions.length,
        status: ExecutionStatus.completed,
        currentAction: 'Execution completed',
      );
    } catch (error) {
      _errorController.add('Execution failed: $error');
      // 计算所有动作的数量用于错误报告
      final allActionsForError = <CommandAction>[];
      for (final state in scene.states) {
        for (final bundle in state.commandBundles) {
          allActionsForError.addAll(bundle.actions);
        }
      }

      yield ExecutionUpdate(
        currentStep: 0,
        totalSteps: allActionsForError.length,
        status: ExecutionStatus.failed,
        error: 'Execution failed: $error',
      );
    } finally {
      _isExecuting = false;
    }
  }

  Future<void> _executeAction(CommandAction action) async {
    // 根据 action 类型执行相应的 BLE 命令
    // 这里需要根据实际的 BLE 协议来实现
    switch (action.type) {
      case CommandActionType.channelValue:
        if (action.channel != null && action.value != null) {
          // 实现设置通道值的 BLE 命令
          await _bleService.sendSetCommand(SetCommand(
            channel: action.channel!,
            value: action.value!,
          ));
        }
        break;
      case CommandActionType.presetTrigger:
        // 实现预设触发的 BLE 命令
        if (action.presetId != null) {
          // TODO: 实现预设触发逻辑
        }
        break;
      case CommandActionType.gradientMode:
        if (action.channel != null && action.value != null && action.duration != null) {
          await _bleService.sendFadeCommand(FadeCommand(
            channel: action.channel!,
            targetValue: action.value!,
            duration: action.duration!,
          ));
        }
        break;
      case CommandActionType.blinkMode:
        if (action.channel != null && action.period != null) {
          await _bleService.sendBlinkCommand(BlinkCommand(
            channel: action.channel!,
            period: action.period!,
          ));
        }
        break;
      case CommandActionType.strobeMode:
        if (action.channel != null && action.count != null &&
            action.totalTime != null && action.pauseTime != null) {
          await _bleService.sendStrobeCommand(StrobeCommand(
            channel: action.channel!,
            flashCount: action.count!,
            totalDuration: action.totalTime!,
            pauseDuration: action.pauseTime!,
          ));
        }
        break;
    }
  }

  @override
  Future<void> stopExecution() async {
    _isExecuting = false;
  }

  @override
  Future<ExecutionStatus?> getCurrentExecutionStatus() async {
    return _isExecuting ? ExecutionStatus.executing : ExecutionStatus.idle;
  }

  void dispose() {
    _errorController.close();
  }
}