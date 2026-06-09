import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'dashboard_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'services/auth_api_service.dart';
import 'services/firebase_service.dart';
import 'services/fcm_service.dart';
import 'services/demo_mode_config.dart';

// ==================== EASY DEMO MODE TOGGLE ====================
// Change this ONE word to switch between Demo and Real mode
const bool DEMO_MODE = false;     // ←←← CHANGE THIS LINE ONLY
// ============================================================

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==================== DEMO MODE SETUP ====================
  if (DEMO_MODE) {
    DemoModeConfig.enable();
  } else {
    DemoModeConfig.disable();
  }
  // =======================================================

  await FirebaseService.initialize();
  await FCMService.initialize();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await AuthApiService.instance.restoreSession();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaterGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF789CE6)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A5F),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      builder: (context, child) {
        return Stack(
          children: [const AppBackground(), if (child != null) child],
        );
      },
      home: const SplashScreen(),
    );
  }
}

class AppBackground extends StatefulWidget {
  const AppBackground({super.key});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(color: const Color(0xFFB5D2E6)),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthApiService _authService = AuthApiService.instance;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      final Widget nextPage = _authService.isAuthenticated
          ? const DashboardPage()
          : const WelcomeScreen();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            opaque: true,
            pageBuilder: (context, animation, secondaryAnimation) => nextPage,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 290,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'WATER',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'GUARD',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 0, 15, 149),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 280,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'WATER',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'GUARD',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 1, 20, 194),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.pressed)) return const Color(0xFF0D47A1);
                      if (states.contains(WidgetState.hovered)) return const Color(0xFF1B6CDF);
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)) {
                        return Colors.white;
                      }
                      return Colors.black;
                    }),
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  onPressed: () => Navigator.push(context, _fadeRoute(const LoginPage())),
                  child: const Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.pressed)) return const Color(0xFF0D47A1);
                      if (states.contains(WidgetState.hovered)) return const Color(0xFF1B6CDF);
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)) {
                        return Colors.white;
                      }
                      return Colors.black;
                    }),
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  onPressed: () => Navigator.push(context, _fadeRoute(const SignupPage())),
                  child: const Text('Sign Up', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}