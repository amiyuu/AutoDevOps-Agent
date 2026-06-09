import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebaseの初期化を試みますが、設定が無い場合やローカル検証時はエラーを握り潰して
  // モックモードで安全に起動できるようにします。
  try {
    await Firebase.initializeApp();
    print("Firebase core initialized successfully.");
  } catch (e) {
    print("Firebase initialization skipped/failed: $e. Running in standalone mode.");
  }

  runApp(
    const ProviderScope(
      child: AutoDevOpsApp(),
    ),
  );
}

class AutoDevOpsApp extends StatelessWidget {
  const AutoDevOpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoDevOps Cockpit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0E12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF),
          secondary: Color(0xFFFF9900),
          error: Color(0xFFFF3366),
          surface: Color(0xFF161822),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFF9900);
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFF9900).withOpacity(0.3);
            }
            return Colors.grey.withOpacity(0.3);
          }),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
