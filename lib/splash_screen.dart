import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_config.dart';
import 'mqtt_monitor_page.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Small delay so the splash has time to be visible
    await Future.delayed(const Duration(milliseconds: 400));

    // Ensure Supabase is initialized (it is in main.dart before runApp)
    final user = SupabaseConfig().client.auth.currentUser;

    if (user != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MqttMonitorPage()));
      return;
    }

    // No server session: check saved username for a nicer UX, but do not auto-navigate
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    if (savedEmail != null) {
      // We don't need to pass it, as LoginPage will read it itself; keep this to maintain behaviour
      // Add a slight delay to avoid flicker
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.agriculture_rounded, size: 72, color: Colors.green),
            SizedBox(height: 20),
            Text('AGRINOVA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
