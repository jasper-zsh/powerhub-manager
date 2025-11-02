import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/models/pwm_controller.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/providers/device_control_provider.dart';
import 'package:app/screens/orchestration_screen.dart';
import 'package:app/screens/saved_controller_management_screen.dart';
import 'package:app/screens/device_control_screen.dart';
import 'package:app/screens/monitoring_screen.dart';

void main() {
  // Enable debug print for development
  if (kDebugMode) {
    debugPrint('Starting PowerHub Manager app...');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => OrchestrationProvider()),
        ChangeNotifierProxyProvider<AppStateProvider, DeviceControlProvider>(
          create: (context) {
            final appState = context.read<AppStateProvider>();
            return DeviceControlProvider(
              appStateProvider: appState,
              onChannelUpdate: (controllerId, channelId, value) async {
                if (appState.selectedDevice?.id != controllerId) {
                  debugPrint(
                    'Main: channel update requires switching from '
                    '${appState.selectedDevice?.id} to $controllerId',
                  );
                  await appState.connectToDevice(controllerId);
                }
                await appState.updateChannelValue(channelId, value);
              },
            onPresetTrigger: (controllerId, presetId) async {
              final appState = context.read<AppStateProvider>();
              if (appState.selectedDevice?.id != controllerId) {
                debugPrint(
                  'Main: preset trigger requires switching from '
                  '${appState.selectedDevice?.id} to $controllerId',
                );
                await appState.connectToDevice(controllerId);
              }
              // Preset functionality has been removed
              // await appState.executePreset(presetId);
            },
            onFadeCommand:
                (controllerId, channelId, targetValue, duration) async {
                  final appState = context.read<AppStateProvider>();
                  if (appState.selectedDevice?.id != controllerId) {
                    await appState.connectToDevice(controllerId);
                  }
                  await appState.sendFadeCommand(
                    channelId: channelId,
                    targetValue: targetValue,
                    duration: duration,
                  );
                },
            onBlinkCommand: (controllerId, channelId, period) async {
              final appState = context.read<AppStateProvider>();
              if (appState.selectedDevice?.id != controllerId) {
                await appState.connectToDevice(controllerId);
              }
              await appState.sendBlinkCommand(
                channelId: channelId,
                period: period,
              );
            },
            onStrobeCommand:
                (
                  controllerId,
                  channelId,
                  flashCount,
                  totalDuration,
                  pauseDuration,
                ) async {
                  final appState = context.read<AppStateProvider>();
                  if (appState.selectedDevice?.id != controllerId) {
                    await appState.connectToDevice(controllerId);
                  }
                  await appState.sendStrobeCommand(
                    channelId: channelId,
                    flashCount: flashCount,
                    totalDuration: totalDuration,
                    pauseDuration: pauseDuration,
                  );
                },
            onEnsureDeviceReady: (controllerId) async {
              final appState = context.read<AppStateProvider>();
              debugPrint('Main: ensure device ready for $controllerId');
              final existing = appState.getConnectedController(controllerId);
              if (existing != null &&
                  appState.selectedDevice?.id != existing.id) {
                debugPrint(
                  'Main: adopting already-connected device ${existing.id} for $controllerId',
                );
                appState.markControllerConnected(existing.id);
                await appState.readChannelStates();
                // Preset functionality has been removed
                // await appState.loadDevicePresets();
                return existing;
              }
              if (appState.selectedDevice?.id != controllerId) {
                debugPrint(
                  'Main: ensure requires connection switch from '
                  '${appState.selectedDevice?.id} to $controllerId',
                );
                await appState.connectToDevice(controllerId);
                return appState.selectedDevice;
              }
              try {
                await appState.readChannelStates();
                debugPrint(
                  'Main: channel states refreshed, first value '
                  '${appState.selectedDevice?.channels.first.value ?? 'n/a'}',
                );
              } catch (e) {
                debugPrint('Main: Failed to read channel states: $e');
                // 读取失败说明设备实际上没有连接
                return null;
              }

              // Preset functionality has been removed
              // await appState.loadDevicePresets();

              // 只有在真正连接的情况下才标记为已连接
              if (appState.selectedDevice != null && appState.isConnected) {
                appState.markControllerConnected(appState.selectedDevice!.id);
                debugPrint('Main: Device confirmed connected: ${appState.selectedDevice!.id}');
              } else {
                debugPrint('Main: Device not actually connected, skipping markControllerConnected');
              }
              return appState.selectedDevice;
            },
            );
          },
          update: (context, appState, controlProvider) {
            final controllers = <String, PWMController>{
              for (final controller in appState.connectedControllers)
                controller.id: controller,
              if (appState.selectedDevice != null)
                appState.selectedDevice!.id: appState.selectedDevice!,
            }.values.toList();
            controlProvider!.syncFromAppState(
              appState.savedControllers,
              appState.selectedDevice,
              controllers,
            );
            return controlProvider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.init();

      // 延迟启动自动重连，避免应用启动时立即重连
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          appState.startAutoReconnectLoop();
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    appState.stopAutoReconnectLoop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        appState.startAutoReconnectLoop();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        appState.stopAutoReconnectLoop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerHub Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        navigationBarTheme: const NavigationBarThemeData(
          height: 56, // 降低到56px，更紧凑的设计
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 3,
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  static const _titles = <String>[
    'Switch Orchestration',
    'Saved Devices',
    'Device Control',
    'System Monitoring',
  ];

  final List<Widget> _pages = const [
    OrchestrationScreen(),
    SavedControllerManagementScreen(),
    DeviceControlScreen(),
    MonitoringScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.toggle_on_outlined),
            selectedIcon: Icon(Icons.toggle_on),
            label: 'Orchestrate',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Control',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
