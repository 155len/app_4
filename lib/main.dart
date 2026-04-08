import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/local/hive_service.dart';
import 'config/theme.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive 本地存储
  await HiveService.init();

  runApp(
    const ProviderScope(
      child: GlucoseTrackerApp(),
    ),
  );
}

class GlucoseTrackerApp extends StatelessWidget {
  const GlucoseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '血糖记录',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
