import 'package:flutter/material.dart';

import 'app_services.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw something right away and set up behind it, so a slow or failing
  // startup step shows up on screen instead of as a blank window.
  runApp(AudiobookToSleepApp(startup: AppServices.init()));
}

class AudiobookToSleepApp extends StatelessWidget {
  const AudiobookToSleepApp({super.key, required this.startup, this.home = const HomeScreen()});

  final Future<void> startup;
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Audiobook to Sleep',
        debugShowCheckedModeBanner: false,
        theme: nightTheme,
        home: FutureBuilder<void>(
          future: startup,
          builder: (context, snapshot) {
            if (snapshot.hasError) return StartupFailedScreen(error: snapshot.error!);
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return home;
          },
        ),
      );
}

class StartupFailedScreen extends StatelessWidget {
  const StartupFailedScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('The app could not start', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SelectableText('$error'),
              const SizedBox(height: 12),
              const Text('Please send this message to the developer.', style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      );
}
