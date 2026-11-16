import 'package:flutter/material.dart';
import 'scanner_page.dart';

void main() {
  runApp(const IsbnApp());
}

class IsbnApp extends StatelessWidget {
  const IsbnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISBN-skanneri',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ScannerPage(),
    );
  }
}
