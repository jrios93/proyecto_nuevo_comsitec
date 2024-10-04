import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:new_pro_com/config/theme/app_theme.dart';
import 'package:new_pro_com/presentation/providers/theme_provider.dart';
import 'package:new_pro_com/presentation/screen/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme appTheme = ref.watch(themeNotifierProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventory App',
      theme: appTheme.getTheme(),
      home: const MyCustomForm(), // Tu pantalla principal
    );
  }
}
