import 'package:flutter/material.dart';

import 'app_services.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.init();
  runApp(const AudiobookToSleepApp());
}

class AudiobookToSleepApp extends StatelessWidget {
  const AudiobookToSleepApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Audiobook to Sleep',
        debugShowCheckedModeBanner: false,
        theme: nightTheme,
        home: const HomeScreen(),
      );
}
