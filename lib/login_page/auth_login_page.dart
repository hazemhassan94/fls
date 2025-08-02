// features/auth/presentation/auth_login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Cubit
import 'package:school_fls/login_page/features/auth/cubit/auth_cubit.dart';
import 'package:school_fls/login_page/features/auth/presentation/forgot_password_page.dart';

// صفحات الأدوار
import 'package:school_fls/main_axis_pages/teachers/main_teachers.dart';
import 'package:school_fls/main_axis_pages/admin/waseem/hr_page.dart';
// TODO: استورد الصفحات النهائية لباقي الأدوار
// import 'package:school_fls/main_axis_pages/deputy/deputy_home_page.dart';
// import 'package:school_fls/main_axis_pages/financial/financial_home_page.dart';
// import 'package:school_fls/main_axis_pages/public_chat/public_chat_home_page.dart';

/// دالة تحدد الصفحة المناسبة حسب الدور الفعلي القادم من Firestore
Widget? getHomeForRole(String role) {
  switch (role.toLowerCase().trim()) {
    case 'teacher':
      return const TeacherHomePage();
    case 'hr':
      return const HrHomePage();
    case 'deputy':
      // return const DeputyHomePage();
      return const Placeholder(); // مؤقتاً Placeholder
    case 'financial':
      // return const FinancialHomePage();
      return const Placeholder();
    case 'public_chat':
    case 'publicchat':
    case 'chat':
      // return const PublicChatHomePage();
      return const Placeholder();
    default:
      return null;
  }
}

class AuthLoginPage extends StatefulWidget {
  final String role; // المجموعة اللي هنجرب فيها (مثلاً admin أو teacher)

  const AuthLoginPage({super.key, required this.role});

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadSavedEmailAndPassword();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loadSavedEmailAndPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('${widget.role}_email');
      final savedPassword = prefs.getString('${widget.role}_password');

      if (savedEmail != null && savedPassword != null) {
        emailController.text = savedEmail;
        passwordController.text = savedPassword;
        setState(() => rememberMe = true);
      }
    } catch (_) {
      // silent
    }
  }

  Future<void> saveOrClearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('${widget.role}_email', emailController.text.trim());
        await prefs.setString('${widget.role}_password', passwordController.text);
      } else {
        await prefs.remove('${widget.role}_email');
        await prefs.remove('${widget.role}_password');
      }
    } catch (_) {
      // silent
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    await saveOrClearCredentials();

    if (!context.mounted) return;

    await context.read<AuthCubit>().loginAndRedirect(
          context,
          email: emailController.text.trim(),
          password: passwordController.text,
          role: widget.role,
        );
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(role: widget.role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1E2B86);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Login - ${widget.role.toUpperCase()}"),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            setState(() => _errorMessage = state.message);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is AuthSuccess) {
            final target = getHomeForRole(state.role);
            if (target != null) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => target),
                (route) => false,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unknown role: ${state.role}')),
              );
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.lock_person_rounded, size: 60, color: primaryColor),
                        const SizedBox(height: 16),
                        const Text(
                          "Welcome back!",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Login as ${widget.role.toUpperCase()}",
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _errorMessage = null),
                                  child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          validator: _validatePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: rememberMe,
                                  activeColor: primaryColor,
                                  onChanged: (val) {
                                    setState(() => rememberMe = val ?? false);
                                  },
                                ),
                                const Text("Remember me", style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            TextButton(
                              onPressed: _navigateToForgotPassword,
                              child: const Text(
                                "Forgot password?",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isLoading ? null : _handleLogin,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  "LOG IN",
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
