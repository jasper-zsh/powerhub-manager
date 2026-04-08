import 'package:flutter/material.dart';

class SwitchHubDetailScreen extends StatelessWidget {
  final String controllerId;
  const SwitchHubDetailScreen({super.key, required this.controllerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SwitchHub')),
      body: const Center(child: Text('SwitchHub Detail')),
    );
  }
}
