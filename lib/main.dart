import 'package:flutter/material.dart';

void main() {
  runApp(const PlatzfreiApp());
}

class PlatzfreiApp extends StatelessWidget {
  const PlatzfreiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Platzfrei',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Text('Platzfrei läuft!', style: TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
