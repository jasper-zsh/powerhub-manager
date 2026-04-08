import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/screens/orchestration_screen.dart';
import 'package:app/screens/device_list_screen.dart';
import 'package:app/screens/unified_monitoring_screen.dart';

void main() {
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
          height: 56,
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
      DeviceListScreen(),
      UnifiedMonitoringScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.toggle_on_outlined),
            selectedIcon: Icon(Icons.toggle_on),
            label: '开关编排',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: '设备管理',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '设备监控',
          ),
        ],
        onDestinationSelected: (index) {
          ref.read(bottomNavigationBarIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}

final bottomNavigationBarIndexProvider = StateProvider<int>((ref) => 0);
