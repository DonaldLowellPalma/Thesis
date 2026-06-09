import 'package:flutter/material.dart';
import 'login_page.dart';
import 'services/auth_api_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final AuthApiService _authService = AuthApiService.instance;

  // Show/hide password toggles
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();

    // Password match validation
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _authService.signup(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB5D2E6),
      body: Column(
        children: [
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
                    const SizedBox(height: 30),
                    _LabeledField(
                      controller: nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      controller: emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
                    _LabeledField(
                      controller: confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_reset_outlined,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF1E3A5F).withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
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
                                'SIGN UP',
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
                          'Already have an account? ',
                          style: TextStyle(
                            color: Color(0xFF1E3A5F),
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          ),
                          child: const Text(
                            'Login',
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
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
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
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F).withValues(alpha: 0.6)),
        suffixIcon: suffixIcon,
        labelText: label,
        labelStyle: TextStyle(
          color: const Color(0xFF1E3A5F).withValues(alpha: 0.7),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
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
