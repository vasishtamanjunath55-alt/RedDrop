import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_screen.dart';
import 'home_shell.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const RedDropApp());
}

class RedDropApp extends StatelessWidget {
  const RedDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedDrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kRed),
        scaffoldBackgroundColor: const Color(0xFFFBF7F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: kRed,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: AnimatedBuilder(
        animation: app,
        builder: (context, _) =>
            app.me == null ? const AuthScreen() : const HomeShell(),
      ),
    );
  }
}
