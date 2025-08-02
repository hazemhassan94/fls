// features/auth/presentation/complete_profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_fls/main_axis_pages/teachers/main_teachers.dart';
import '../cubit/auth_cubit.dart';

// destination pages
import 'package:school_fls/main_axis_pages/admin/waseem/hr_page.dart';
// TODO: import other role pages when ready
// import 'package:school_fls/main_axis_pages/student/student_home_page.dart';
// import 'package:school_fls/main_axis_pages/deputy/deputy_home_page.dart';
// import 'package:school_fls/main_axis_pages/financial/financial_home_page.dart';
// import 'package:school_fls/main_axis_pages/public_chat/public_chat_page.dart';

enum UserRole {
  teacher,
  student,
  hr,
  deputy,
  financial,
  publicChat,
}

extension UserRoleExtension on String {
  UserRole? toUserRole() {
    final normalized = toLowerCase().trim();
    switch (normalized) {
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      case 'hr':
        return UserRole.hr;
      case 'deputy':
        return UserRole.deputy;
      case 'financial':
        return UserRole.financial;
      case 'public_chat':
      case 'publicchat':
      case 'chat':
        return UserRole.publicChat;
      default:
        return null;
    }
  }
}

class CompleteProfilePage extends StatefulWidget {
  final String role;

  const CompleteProfilePage({super.key, required this.role});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  String? selectedSubject;

  final _formKey = GlobalKey<FormState>();
  final List<String> _subjects = [
    'Arabic',
    'English',
    'French',
    'Social Studies',
    'Math',
    'Science',
    'ICT',
    'PE',
    'Activities',
    'Art',
    'Music',
  ];

  bool _submitted = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your name';
    if (value.trim().length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email';
    final pattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!pattern.hasMatch(value.trim())) return 'Please enter a valid email';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your phone number';
    if (value.trim().length < 11) return 'Please enter a valid phone number';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a new password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateSubject(String? value) {
    if (widget.role.toLowerCase() == 'teacher' && (value == null || value.isEmpty)) {
      return 'Please select a subject';
    }
    return null;
  }

  void _onSubmit() {
    if (_submitted) return;
    if (!_formKey.currentState!.validate()) return;

    final subjectToSend = selectedSubject ?? '';
    final role = widget.role.trim();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete Profile'),
        content: const Text(
          'This will update your profile information in the database and change your password. Do you want to continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (!context.mounted) return;
              setState(() => _submitted = true);
              context.read<AuthCubit>().completeProfile(
                    context,
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    newPassword: passwordController.text,
                    role: role,
                    subject: subjectToSend,
                  );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _navigateByRole(String roleStr) {
    final roleEnum = roleStr.toUserRole();
    Widget? target;

    switch (roleEnum) {
      case UserRole.teacher:
        target = const TeacherHomePage();
        break;
      case UserRole.hr:
        target = const HrHomePage();
        break;
      // extend when other pages exist:
      // case UserRole.student:
      //   target = const StudentHomePage();
      //   break;
      // case UserRole.deputy:
      //   target = const DeputyHomePage();
      //   break;
      // case UserRole.financial:
      //   target = const FinancialHomePage();
      //   break;
      // case UserRole.publicChat:
      //   target = const PublicChatPage();
      //   break;
      default:
        target = null;
    }

    if (target != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => target!),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unrecognized role: $roleStr')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1E2B86);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Complete Profile - ${widget.role.toUpperCase()}'),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            setState(() => _submitted = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
          if (state is AuthSuccess) {
            _navigateByRole(widget.role);
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.symmetric(vertical: 24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.person_add, size: 60, color: primaryColor),
                      const SizedBox(height: 20),
                      const Text(
                        'Complete Your Profile',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Provide your name, email, phone, subject (if applicable), and choose a new password to finish setup.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: nameController,
                        keyboardType: TextInputType.name,
                        validator: _validateName,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Ex: Hazem Hassan',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'you@example.com',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '11 digits',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.role.toLowerCase() == 'teacher')
                        DropdownButtonFormField<String>(
                          value: selectedSubject,
                          items: _subjects
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedSubject = v),
                          validator: _validateSubject,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            prefixIcon: const Icon(Icons.book),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      if (widget.role.toLowerCase() == 'teacher') const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Enter a strong password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 30),
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final isLoading = state is AuthLoading;
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isLoading ? null : _onSubmit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Complete Profile', style: TextStyle(fontSize: 16)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
