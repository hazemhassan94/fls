import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleDetectionService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Available role collections in the Firebase database
  static const List<String> availableRoles = [
    'teacher',
    'student', 
    'parent',
    'admin'
  ];

  /// Automatically detect user role from Firebase collections
  /// Returns the role if found, null if not found in any collection
  Future<String?> detectUserRole({String? email}) async {
    try {
      // Use current user if no email provided
      String? userEmail = email;
      String? userId;

      if (userEmail == null) {
        final currentUser = _auth.currentUser;
        if (currentUser == null) return null;
        userEmail = currentUser.email;
        userId = currentUser.uid;
      }

      if (userEmail == null) return null;

      // Check each role collection for the user
      for (String role in availableRoles) {
        try {
          QuerySnapshot querySnapshot;
          
          // If we have userId, search by document ID first (more efficient)
          if (userId != null) {
            DocumentSnapshot docSnapshot = await _firestore
                .collection(role)
                .doc(userId)
                .get();
            
            if (docSnapshot.exists) {
              final data = docSnapshot.data() as Map<String, dynamic>?;
              
              // For admin collection, check if there's a specific role field
              if (role == 'admin' && data != null) {
                final specificRole = data['role'] as String?;
                if (specificRole != null && specificRole.isNotEmpty) {
                  return specificRole.toLowerCase().trim();
                }
              }
              
              return role;
            }
          }
          
          // Fallback: search by email
          querySnapshot = await _firestore
              .collection(role)
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
            
            // For admin collection, check if there's a specific role field
            if (role == 'admin') {
              final specificRole = userData['role'] as String?;
              if (specificRole != null && specificRole.isNotEmpty) {
                return specificRole.toLowerCase().trim();
              }
            }
            
            return role;
          }
        } catch (e) {
          // Continue checking other collections if one fails
          continue;
        }
      }

      return null; // User not found in any collection
    } catch (e) {
      throw 'Failed to detect user role: $e';
    }
  }

  /// Check if user exists in any collection with the given email
  Future<bool> userExistsInDatabase(String email) async {
    try {
      final role = await detectUserRole(email: email);
      return role != null;
    } catch (e) {
      return false;
    }
  }

  /// Get user data from the detected role collection
  Future<Map<String, dynamic>?> getUserDataFromDetectedRole(String email) async {
    try {
      final role = await detectUserRole(email: email);
      if (role == null) return null;

      // Determine the actual collection to query
      String collectionName = role;
      if (['hr', 'deputy', 'financial', 'public_chat', 'publicchat', 'chat'].contains(role)) {
        collectionName = 'admin';
      }

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Try by user ID first
        final docSnapshot = await _firestore
            .collection(collectionName)
            .doc(currentUser.uid)
            .get();
        
        if (docSnapshot.exists) {
          return docSnapshot.data();
        }
      }

      // Fallback to email query
      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      throw 'Failed to get user data: $e';
    }
  }
}