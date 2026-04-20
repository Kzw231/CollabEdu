import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_wrapper.dart';



void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://gxvbqliweraanmgxzijk.supabase.co',
      anonKey: 'sb_secret_QN6o1Rern0RLtP7bfF-UFw_ODJIJExP',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CollabEdu',
      theme: classroomTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}