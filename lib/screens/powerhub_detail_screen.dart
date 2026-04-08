import 'package:flutter/material.dart';

class PowerHubDetailScreen extends StatelessWidget {
  final String controllerId;
  const PowerHubDetailScreen({super.key, required this.controllerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PowerHub')),
      body: const Center(child: Text('PowerHub Detail')),
    );
  }
}
