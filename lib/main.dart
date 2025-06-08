import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_table_app/pages/home_page.dart';
import 'package:time_table_app/pages/main_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.black),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {'/main': (context) => const MainPage()},
      home: const HomePage(),
    );
  }
}
