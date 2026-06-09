import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'signup_page.dart';
import 'services/auth_api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthApiService _authService = AuthApiService.instance;

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _authService.login(email: email, password: password);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> forgotPassword() async {
    final emailController = TextEditingController(text: emailControllerText);

    try {
      final email = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Account Email',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(emailController.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (!mounted || email == null || email.isEmpty) {
        return;
      }

      final resetToken = await _authService.requestPasswordReset(email: email);

      if (!mounted) return;

      if ((resetToken ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset request submitted. Please check your email.'),
          ),
        );
        return;
      }

      await _showSetNewPasswordDialog(email: email, resetToken: resetToken!);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      emailController.dispose();
    }
  }

  String get emailControllerText => emailController.text.trim();

  Future<void> _showSetNewPasswordDialog({
    required String email,
    required String resetToken,
  }) async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    try {
      final shouldSubmit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Set New Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reset token generated for $email',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Reset Password'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldSubmit != true) {
        return;
      }

      final newPassword = newPasswordController.text;
      final confirmPassword = confirmPasswordController.text;

      if (newPassword.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New password must be at least 6 characters'),
          ),
        );
        return;
      }

      if (newPassword != confirmPassword) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }

      final emailSent = await _authService.resetPassword(
        email: email,
        resetToken: resetToken,
        newPassword: newPassword,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Password reset successful. A confirmation email was sent to your account email.'
                : 'Password reset successful. Confirmation email could not be sent.',
          ),
        ),
      );
      passwordController.clear();
    } finally {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB5D2E6),
      body: Column(
        children: [
          // Header Banner
          // Form Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/logo.png',
                      height: 250,
                      width: 300,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 50),
                    // Email with icon
                    _LabeledField(
                      controller: emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Password with icon
                    _LabeledField(
                      controller: passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF1E3A5F).withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),

                    // Forgot Password
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      child: GestureDetector(
                        onTap: forgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: const Color(0xFF789CE6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'LOG IN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Color(0xFF1E3A5F),
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignupPage(),
                            ),
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF789CE6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.icon,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? icon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: Color(0xFF1E3A5F),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: const Color(0xFF1E3A5F).withValues(alpha: 0.7),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF1E3A5F).withValues(alpha: 0.6))
            : null,
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFFD5FCDD).withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF789CE6), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
