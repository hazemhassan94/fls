// features/auth/cubit/auth_cubit.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/auth_repository.dart';
import '../models/user_model.dart';
import '../presentation/complete_profile_page.dart';

/// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String role;
  AuthSuccess(this.role);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

/// Cubit
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository repo;

  AuthCubit(this.repo) : super(AuthInitial());

  /// تسجيل الدخول وتحديد الدور الفعلي من Firestore
  Future<void> loginAndRedirect(
    BuildContext context, {
    required String email,
    required String password,
    required String role,
  }) async {
    emit(AuthLoading());

    try {
      await repo.signIn(email, password);
      final uid = FirebaseAuth.instance.currentUser!.uid;

      String finalRole = role.toLowerCase().trim();

      // إذا المستخدم داخل كمجموعة admin → اقرأ الدور الفعلي من الحقل role
      if (finalRole == 'admin') {
        final adminDoc = await repo.getUserDoc('admin', uid);
        if (!adminDoc.exists) {
          await repo.signOut();
          throw 'User not found in admin collection.';
        }

        final adminData = adminDoc.data() as Map<String, dynamic>? ?? {};
        final storedRole = (adminData['role'] as String?)?.toLowerCase().trim();

        if (storedRole != null && storedRole.isNotEmpty) {
          finalRole = storedRole; // مثل hr, deputy, financial, public_chat
        }
      }

      // جلب بيانات البروفايل من مجموعة الدور الفعلي
      final doc = await repo.getUserDoc(finalRole, uid);
      if (!doc.exists) {
        await repo.signOut();
        throw 'User not found in $finalRole collection.';
      }

      final userData = doc.data() as Map<String, dynamic>? ?? {};
      final isCompleted = _isProfileComplete(userData, finalRole);

      if (!context.mounted) return;

      if (!isCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CompleteProfilePage(role: finalRole)),
        );
        emit(AuthInitial());
      } else {
        emit(AuthSuccess(finalRole));
      }
    } catch (e) {
      final err = e.toString();
      emit(AuthError(err));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: $err"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// إكمال البروفايل (تحديث كلمة المرور + حفظ البيانات)
  Future<void> completeProfile(
    BuildContext context, {
    required String name,
    required String email,
    required String phone,
    required String newPassword,
    required String role,
    required String subject,
  }) async {
    emit(AuthLoading());

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // تحديث كلمة المرور
      await repo.updatePassword(newPassword);

      final user = AppUser(
        uid: uid,
        email: email,
        phone: phone,
        role: role,
        name: name,
        subject: subject,
      );

      await repo.saveUser(user);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile completed successfully! Welcome to your dashboard.'),
          backgroundColor: Colors.green,
        ),
      );

      emit(AuthSuccess(role));
    } catch (e) {
      final err = e.toString();
      emit(AuthError(err));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to complete profile: $err"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// إرسال رابط إعادة تعيين كلمة المرور
  Future<void> resetPassword(
    BuildContext context, {
    required String email,
  }) async {
    emit(AuthLoading());

    try {
      await repo.sendPasswordResetEmail(email);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent to your email. Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );

      emit(AuthSuccess('reset'));
    } catch (e) {
      final err = e.toString();
      emit(AuthError(err));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send reset link: $err"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// التحقق من اكتمال البروفايل
  bool _isProfileComplete(Map<String, dynamic> data, String role) {
    final hasEmail = (data['email'] as String?)?.trim().isNotEmpty == true;
    final hasPhone = (data['phone'] as String?)?.trim().isNotEmpty == true;
    final hasName = (data['name'] as String?)?.trim().isNotEmpty == true;

    if (role.toLowerCase().trim() == 'teacher') {
      final hasSubject = (data['subject'] as String?)?.trim().isNotEmpty == true;
      return hasEmail && hasPhone && hasName && hasSubject;
    }

    // باقي الأدوار: لا نحتاج subject
    return hasEmail && hasPhone && hasName;
  }
}
