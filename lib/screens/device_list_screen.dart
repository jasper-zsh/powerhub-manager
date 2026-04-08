import 'package:flutter/material.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备管理')),
      body: const Center(child: Text('Device List')),
    );
  }
}
