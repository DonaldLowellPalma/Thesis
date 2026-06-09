import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'services/auth_api_service.dart';
import 'services/firebase_service.dart';
import 'services/fcm_service.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await FCMService.initialize();
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await AuthApiService.instance.restoreSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome',
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
    return Positioned.fill(child: Container(color: const Color(0xFFB5D2E6)));
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.pressed)) {
                        return Color(0xFF0D47A1); // Dark blue when pressed
                      } else if (states.contains(WidgetState.hovered)) {
                        return Color(0xFF1B6CDF); // Blue when hovered
                      }
                      return const Color.fromARGB(
                        255,
                        255,
                        255,
                        255,
                      ); // White by default
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.pressed) ||
                          states.contains(WidgetState.hovered)) {
                        return const Color.fromARGB(
                          255,
                          255,
                          255,
                          255,
                        ); // White text when hovered or pressed
                      }
                      return Colors.black; // Black text by default
                    }),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: true,
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const LoginPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                  child: const Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.pressed)) {
                        return Color(0xFF0D47A1); // Dark blue when pressed
                      } else if (states.contains(WidgetState.hovered)) {
                        return Color(0xFF1B6CDF); // Blue when hovered
                      }
                      return Colors.white; // White by default
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.pressed) ||
                          states.contains(WidgetState.hovered)) {
                        return Colors
                            .white; // White text when hovered or pressed
                      }
                      return Colors.black; // Black text by default
                    }),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: true,
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const SignupPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                  child: const Text('Sign Up', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
