import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_screen.dart';
import 'firebase_options.dart';
import 'home_shell.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (firebaseConfigured) {
    await Firebase.initializeApp(options: firebaseOptions);
    app.init();
  }
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
        builder: (context, _) => _root(),
      ),
    );
  }
}

Widget _root() {
  if (!firebaseConfigured) return const _SetupScreen();
  if (app.booting) return const _Splash();
  if (app.currentUserId == null) return const AuthScreen();
  if (app.me == null) {
    if (app.usersLoaded && !app.profilePending) {
      return const _ProfileMissing();
    }
    return const _Splash();
  }
  return const HomeShell();
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: kRed)),
    );
  }
}

class _ProfileMissing extends StatelessWidget {
  const _ProfileMissing();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off, size: 56, color: kRed),
              const SizedBox(height: 12),
              const Text(
                'Your profile could not be found. It may have been removed by an admin, or the Firestore rules are not published yet.',
                textAlign: TextAlign.center,
              ),
              if (app.syncError != null) ...[
                const SizedBox(height: 8),
                Text(app.syncError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kRed, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kRed),
                onPressed: () => app.logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RedDrop setup needed')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This build has no Firebase project connected yet.\n\n'
          'Open lib/firebase_options.dart, paste your Firebase apiKey, appId, '
          'messagingSenderId and projectId (README step 3), then rebuild the app.',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
      ),
    );
  }
}
