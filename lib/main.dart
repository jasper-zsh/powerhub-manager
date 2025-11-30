import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/screens/orchestration_screen.dart';
import 'package:app/screens/saved_controller_management_screen.dart';
import 'package:app/screens/device_control_screen.dart';
import 'package:app/screens/monitoring_screen.dart';
import 'package:app/screens/power_management_screen.dart';
import 'package:app/screens/switchhub_monitoring_screen.dart';

void main() {
  // Enable debug print for development
  if (kDebugMode) {
    debugPrint('Starting PowerHub Manager app...');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavigationBarIndexProvider);

    final pages = const [
      OrchestrationScreen(),
      SavedControllerManagementScreen(),
      DeviceControlScreen(),
      MonitoringScreen(),
      PowerManagementScreen(),
      SwitchHubMonitoringScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
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
          NavigationDestination(
            icon: Icon(Icons.power_settings_new_outlined),
            selectedIcon: Icon(Icons.power_settings_new),
            label: 'Power',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching_outlined),
            selectedIcon: Icon(Icons.bluetooth_searching),
            label: 'SwitchHub',
          ),
        ],
        onDestinationSelected: (index) {
          ref.read(bottomNavigationBarIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}

// Provider for bottom navigation index
final bottomNavigationBarIndexProvider = StateProvider<int>((ref) => 0);
