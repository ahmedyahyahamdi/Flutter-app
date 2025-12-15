
import 'package:flutter/material.dart';

import 'supabase_config.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig().initialize();
  runApp(const RpiMonitorApp());
}

/// ============================================================================
/// APPLICATION ROOT
/// ============================================================================
class RpiMonitorApp extends StatelessWidget {
  const RpiMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPi MQTT Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Using the corrected VisualDensity constant
        visualDensity: VisualDensity.adaptivePlatformDensity, 
      ),
      
      // 1. SET THE 'home' PROPERTY TO ENSURE LOGINPAGE IS FIRST
      home: const SplashScreen(), 
      
      // 2. Navigation will use widget routes (no named routes)
      // Removed the 'routes' map in favor of direct MaterialPageRoute navigation.

    );
  }
}

