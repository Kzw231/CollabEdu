import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_wrapper.dart';
import 'screens/reset_password_screen.dart';
import 'package:app_links/app_links.dart';
import 'services/deep_link_service.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://gxvbqliweraanmgxzijk.supabase.co',
      anonKey: 'sb_secret_QN6o1Rern0RLtP7bfF-UFw_ODJIJExP',
  );

  // deep link handling
  final appLinks = AppLinks();
  final initialLink = await appLinks.getInitialLink();
  if (initialLink != null && initialLink.toString().contains('reset-password')) {
    DeepLinkService.isResetLinkPending = true;
    runApp(MyApp(initialRoute: 'reset', resetLink: initialLink));
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  final String? initialRoute;
  final Uri? resetLink;
  const MyApp({super.key, this.initialRoute, this.resetLink});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    // listen for deep links while app is running
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.toString().contains('reset-password')) {
        // if the reset password screen is not already open, open it
        DeepLinkService.isResetLinkPending = true;
        _navigatorKey.currentState?.pushNamed('/reset', arguments: uri);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CollabEdu',
      theme: classroomTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      initialRoute: widget.initialRoute == 'reset' ? '/reset' : '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/reset': (context) => ResetPasswordScreen(link: widget.resetLink!),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/reset' && settings.arguments is Uri) {
          return MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(link: settings.arguments as Uri),
          );
        }
        return null;
      },
    );
  }
}