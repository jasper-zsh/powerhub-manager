# PowerHub Manager 状态管理迁移指南

## 概述

本文档描述了从旧的 ChangeNotifier 架构到新的 Riverpod + StateNotifier 架构的迁移过程。

## 迁移前后对比

### 旧架构 (ChangeNotifier)
- `AppStateProvider` - 单体状态管理器，处理所有功能
- `DeviceControlProvider` - 设备控制状态
- `OrchestrationProvider` - 编排功能状态
- 多处 `Timer` 和 `microtask` 用于状态同步
- UI 通过 `Consumer` 监听全局状态变化

### 新架构 (Riverpod + StateNotifier)
- 分离的状态控制器，每个负责特定功能域
- 可预测的数据流，使用 `AsyncValue` 处理异步状态
- Repository 层封装副作用，便于测试
- UI 通过 `ref.watch(controllerProvider.select(...))` 精细订阅

## 新的架构组件

### 控制器 (Controllers)
1. **ConnectionSessionController** - 连接会话管理
2. **DiscoveryController** - 设备发现管理
3. **SavedControllerController** - 保存的控制器管理
4. **TelemetryController** - 遥测数据管理
5. **MonitoringController** - 监控数据管理
6. **DeviceControlController** - 设备控制管理
7. **OrchestrationController** - 编排功能管理

### 仓库 (Repositories)
1. **DeviceRepository** - BLE 设备操作封装
2. **SavedControllerRepository** - 保存控制器数据封装
3. **TelemetryRepository** - 遥测数据操作封装
4. **OrchestrationRepository** - 编排数据操作封装

## 迁移映射

### 旧 Provider -> 新 Controller

| 旧 Provider | 新 Controller | 主要功能 |
|-------------|---------------|----------|
| AppStateProvider | ConnectionSessionController + DiscoveryController + SavedControllerController | 设备连接、发现、保存管理 |
| DeviceControlProvider | DeviceControlController | 通道控制、预设管理 |
| OrchestrationProvider | OrchestrationController | 场景编排、执行日志 |

### 状态映射

| 旧状态 | 新状态 | 位置 |
|---------|--------|------|
| `selectedDevice` | `device` | ConnectionSessionState |
| `discoveredDevices` | `devices` | DiscoveryState |
| `savedControllers` | `controllers` | SavedControllerState |
| `isConnected` | `status == ConnectionStatus.connected` | ConnectionSessionState |
| `telemetry` | `value` | AsyncValue<TelemetryData> |
| `isScanning` | `status == DiscoveryStatus.scanning` | DiscoveryState |

## UI 迁移指南

### 1. 替换 Consumer

**旧代码:**
```dart
Consumer<AppStateProvider>(
  builder: (context, appState, child) {
    return Text('Connected: ${appState.isConnected}');
  },
)
```

**新代码:**
```dart
ConsumerWidget(
  builder: (context, ref, child) {
    final connectionState = ref.watch(connectionSessionControllerProvider);
    return Text('Connected: ${connectionState.isConnected}');
  },
)
```

### 2. 精细订阅

**旧代码:**
```dart
Consumer<AppStateProvider>(
  builder: (context, appState, child) {
    // 任何状态变化都会重建整个 widget
    return Column(
      children: [
        Text('Device: ${appState.selectedDevice?.name}'),
        Text('Status: ${appState.isConnected ? "Connected" : "Disconnected"}'),
      ],
    );
  },
)
```

**新代码:**
```dart
ConsumerWidget(
  builder: (context, ref, child) {
    // 只订阅需要的状态片段
    final deviceName = ref.watch(
      connectionSessionControllerProvider.select((state) => state.device?.name),
    );
    final isConnected = ref.watch(
      connectionSessionControllerProvider.select((state) => state.isConnected),
    );
    
    return Column(
      children: [
        Text('Device: $deviceName'),
        Text('Status: ${isConnected ? "Connected" : "Disconnected"}'),
      ],
    );
  },
)
```

### 3. 异步状态处理

**旧代码:**
```dart
Consumer<AppStateProvider>(
  builder: (context, appState, child) {
    if (appState.isLoading) {
      return CircularProgressIndicator();
    }
    if (appState.errorMessage.isNotEmpty) {
      return Text('Error: ${appState.errorMessage}');
    }
    return YourContent();
  },
)
```

**新代码:**
```dart
ConsumerWidget(
  builder: (context, ref, child) {
    final asyncState = ref.watch(yourControllerProvider);
    
    return asyncState.when(
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
      data: (data) => YourContent(data: data),
    );
  },
)
```

## 测试迁移

### 1. 单元测试

**旧代码:**
```dart
test('should connect to device', () async {
  final appStateProvider = AppStateProvider();
  await appStateProvider.connectToDevice('device-id');
  expect(appStateProvider.isConnected, true);
});
```

**新代码:**
```dart
test('should connect to device', () async {
  final container = ProviderContainer(
    overrides: [
      deviceRepositoryProvider.overrideWithValue(mockDeviceRepository),
    ],
  );
  
  when(mockDeviceRepository.connectToDevice(any))
      .thenAnswer((_) async => true);
  
  await container.read(connectionSessionControllerProvider.notifier)
      .connectToDevice(testDevice);
  
  final state = container.read(connectionSessionControllerProvider);
  expect(state.status, ConnectionStatus.connected);
});
```

### 2. Widget 测试

**旧代码:**
```dart
testWidgets('should show connection status', (tester) async {
  final appStateProvider = AppStateProvider();
  
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => appStateProvider,
      child: MaterialApp(
        home: YourScreen(),
      ),
    ),
  );
  
  expect(find.text('Connected'), findsOneWidget);
});
```

**新代码:**
```dart
testWidgets('should show connection status', (tester) async {
  final container = ProviderContainer();
  
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: YourScreen(),
      ),
    ),
  );
  
  expect(find.text('Connected'), findsOneWidget);
});
```

## 性能优化

### 1. 减少重建

新架构通过 `select` 方法实现精细订阅，只重建必要的 widget 部分：

```dart
// 只订阅连接状态，不影响其他状态变化
final isConnected = ref.watch(
  connectionSessionControllerProvider.select((state) => state.isConnected),
);

// 只订阅设备列表，不影响连接状态
final devices = ref.watch(
  discoveryControllerProvider.select((state) => state.devices),
);
```

### 2. 异步操作优化

使用 `AsyncValue` 统一处理异步状态，避免多个 loading 状态：

```dart
final telemetryState = ref.watch(telemetryControllerProvider);

return telemetryState.when(
  loading: () => const CircularProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
  data: (telemetry) => TelemetryView(data: telemetry),
);
```

## 常见问题

### 1. 如何处理跨控制器通信？

使用 Repository 层共享数据，或者通过 `ref.read` 访问其他控制器：

```dart
// 在一个控制器中访问另一个控制器
final connectionState = ref.read(connectionSessionControllerProvider);
if (connectionState.isConnected) {
  // 执行操作
}
```

### 2. 如何处理全局事件？

使用 Riverpod 的 `Provider` 定义全局事件总线：

```dart
final eventBusProvider = Provider<EventBus>((ref) => EventBus());

// 在控制器中发送事件
ref.read(eventBusProvider).fire(MyEvent());

// 在 UI 中监听事件
ref.listen(eventBusProvider, (previous, next) {
  // 处理事件
});
```

### 3. 如何处理复杂的状态逻辑？

将复杂逻辑移至 Repository 层或使用专门的 StateNotifier：

```dart
class ComplexLogicController extends StateNotifier<ComplexState> {
  ComplexLogicController(this._repository) : super(const ComplexState.initial());
  
  final ComplexRepository _repository;
  
  Future<void> performComplexOperation() async {
    state = const ComplexState.loading();
    
    try {
      final result = await _repository.complexOperation();
      state = ComplexState.data(result);
    } catch (error) {
      state = ComplexState.error(error);
    }
  }
}
```

## 迁移检查清单

- [ ] 替换所有 `Consumer` 为 `ConsumerWidget` 或 `HookConsumerWidget`
- [ ] 使用 `ref.watch` 替换 `Provider.of`
- [ ] 使用 `select` 方法优化订阅
- [ ] 替换 `ChangeNotifier` 为 `StateNotifier`
- [ ] 使用 `AsyncValue` 处理异步状态
- [ ] 更新单元测试使用 `ProviderContainer`
- [ ] 更新 widget 测试使用 `UncontrolledProviderScope`
- [ ] 验证性能优化效果
- [ ] 更新文档和注释

## 总结

新的 Riverpod 架构提供了更好的性能、可测试性和可维护性。通过分离关注点、使用不可变状态和精细订阅，我们可以构建更健壮和响应式的应用程序。

迁移过程可能需要一些时间，但长期收益是显著的。建议逐步迁移，确保每个步骤都经过充分测试。