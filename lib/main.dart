import 'dart:async';

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

  final appLinks = AppLinks();
  // handle initial link (app not running)
  try {
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null && initialLink.toString().contains('reset-password')) {
      DeepLinkService.isResetLinkPending = true;
      runApp(MyApp(initialRoute: 'reset', resetLink: initialLink));
    } else {
      runApp(const MyApp());
    }
  } catch (e) {
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
  late final StreamSubscription<AuthState> _authSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _lastHandledResetLink;
  bool _isResetScreenOpen = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _lastHandledResetLink = widget.resetLink?.toString();
    _isResetScreenOpen = widget.initialRoute == 'reset' && widget.resetLink != null;
    // listen for deep links while app is running
    _appLinks.uriLinkStream.listen((Uri? uri) {
      _handleIncomingLink(uri);
    });
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery && !_isResetScreenOpen) {
        DeepLinkService.isResetLinkPending = true;
        _isResetScreenOpen = true;
        _navigatorKey.currentState
            ?.pushNamed('/reset')
            .whenComplete(() => _isResetScreenOpen = false);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _handleIncomingLink(Uri? uri) {
    if (uri == null || !uri.toString().contains('reset-password')) return;

    final uriString = uri.toString();
    if (_isResetScreenOpen || _lastHandledResetLink == uriString) {
      return;
    }

    DeepLinkService.isResetLinkPending = true;
    _lastHandledResetLink = uriString;
    _isResetScreenOpen = true;

    _navigatorKey.currentState
        ?.pushNamed('/reset', arguments: uri)
        .whenComplete(() {
          _isResetScreenOpen = false;
          if (!DeepLinkService.isResetLinkPending) {
            _lastHandledResetLink = null;
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
      onGenerateRoute: (settings) {
        if (settings.name == '/reset') {
          final link = settings.arguments as Uri? ?? widget.resetLink;
          final hasRecoverySession =
              Supabase.instance.client.auth.currentSession != null;
          if (link == null && !hasRecoverySession) {
            return MaterialPageRoute(builder: (_) => const AuthWrapper());
          }
          return MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(link: link),
          );
        }
        // Default route
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      },
    );
  }
}