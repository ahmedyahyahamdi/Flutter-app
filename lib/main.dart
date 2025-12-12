// File: main.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';
import 'dashboard_page.dart';
import 'login_page.dart'; // Ensure this is imported
import 'splash_screen.dart';
import 'mqtt_monitor_page.dart';

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

