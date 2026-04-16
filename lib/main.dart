import 'package:flutter/material.dart';
import 'app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zyttqgeaqsceqidgigca.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5dHRxZ2VhcXNjZXFpZGdpZ2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NDcyOTksImV4cCI6MjA5MTMyMzI5OX0.HriEErgZoHZjgmyVKYjoa0QgQ7anH28TNAF5YLQP72c',
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}