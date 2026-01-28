import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LasPrendasApp());
}

class LasPrendasApp extends StatelessWidget {
  const LasPrendasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Las Prendas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
        useMaterial3: true,
        fontFamily: 'Roboto', // O el sistema por defecto
      ),
      home: const HomeScreen(),
    );
  }
}
