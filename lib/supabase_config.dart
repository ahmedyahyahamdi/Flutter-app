import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static final SupabaseConfig _instance = SupabaseConfig._internal();
  factory SupabaseConfig() => _instance;
  SupabaseConfig._internal();

  static const String supabaseUrl = 'https://hkjfpznurzygbnolnctw.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhramZwem51cnp5Z2Jub2xuY3R3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2ODc3NTUsImV4cCI6MjA3MzI2Mzc1NX0.1bVKNkbsXTjhiPp-TlPgB7IvP-7R76Z8o6QWaMOy5rU';

  Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}