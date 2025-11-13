import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'data/local_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = LocalDatabase();
  await database.init();
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.database});

  final LocalDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6CF7)),
        useMaterial3: true,
      ),
      home: AppShell(database: database),
    );
  }
}
