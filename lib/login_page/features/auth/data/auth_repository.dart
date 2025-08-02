// features/auth/data/auth_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'No user found with this email address.';
        case 'wrong-password':
          throw 'Wrong password provided.';
        case 'invalid-email':
          throw 'Invalid email address.';
        case 'user-disabled':
          throw 'This account has been disabled.';
        case 'too-many-requests':
          throw 'Too many failed attempts. Please try again later.';
        default:
          throw 'Authentication failed: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in.';
      }
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw 'The password provided is too weak.';
        case 'requires-recent-login':
          throw 'This operation requires recent authentication. Please log in again.';
        default:
          throw 'Password update failed: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'No user found with this email address.';
        case 'invalid-email':
          throw 'Invalid email address.';
        case 'user-disabled':
          throw 'This account has been disabled.';
        case 'too-many-requests':
          throw 'Too many requests. Please try again later.';
        default:
          throw 'Failed to send reset email: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String role, String uid) async {
    try {
      return await _firestore.collection(role).doc(uid).get();
    } on FirebaseException catch (e) {
      throw 'Failed to fetch user data: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  Future<void> saveUser(AppUser user) async {
    try {
      final userData = {
        'email': user.email,
        'phone': user.phone,
        'name': user.name,
        'subject': user.subject,
        'role': user.role,
        'uid': user.uid,
        'isProfileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      // Upsert: create if not exists, merge otherwise
      await _firestore
          .collection(user.role)
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw 'Failed to save user data: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out: $e';
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  bool isUserSignedIn() {
    return _auth.currentUser != null;
  }
}
