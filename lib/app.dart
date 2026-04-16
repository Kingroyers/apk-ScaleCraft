import 'package:flutter/material.dart';
import 'pages/escala_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Acoustic Guitar System',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8C547),
          secondary: Color(0xFFC4893A),
          surface: Color(0xFF161616),
        ),
      ),
      home: const EscalaPage(),
    );
  }
}
