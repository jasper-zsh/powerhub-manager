import 'package:flutter/material.dart';

class UnifiedMonitoringScreen extends StatelessWidget {
  const UnifiedMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备监控')),
      body: const Center(child: Text('Unified Monitoring')),
    );
  }
}
