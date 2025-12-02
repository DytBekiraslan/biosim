import 'package:flutter/material.dart';
import 'screens/ets_screen.dart';

void main() {
  runApp(BioSimApp());
}

class BioSimApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Biyo Simülasyon',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: EtsScreen(),
    );
  }
}