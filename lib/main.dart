import 'package:flutter/material.dart';
import 'main_screen.dart';

void main() {
  Paint.enableDithering = true;
  runApp(const FlightApp());
}

class FlightApp extends StatelessWidget {
  const FlightApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flight App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme:
            const ColorScheme.dark().copyWith(secondary: Colors.orange),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          titleTextStyle: const TextStyle(
            color: Colors.orange,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.orange,
          size: 30,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Colors.orange,
            fontSize: 15,
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}


