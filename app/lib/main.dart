import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/screens/home_screen.dart';

void main() {
  // Enable debug print for development
  if (kDebugMode) {
    debugPrint('Starting PowerHub Manager app...');
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the app state provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).init();
    });
    
    return MaterialApp(
      title: 'PowerHub Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
