// services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  UserRole? get userRole => _userModel?.role;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // Handle auth state changes
  void _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadUserModel();
    } else {
      _userModel = null;
    }
    notifyListeners();
  }

  // Load user model from Firestore
  Future<void> _loadUserModel() async {
    if (_user == null) return;
    
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .get();
      
      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print('Error loading user model: $e');
    }
  }

  // Sign in method (matches what the LoginScreen calls)
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = '';
      
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      return null; // No error
    } on FirebaseAuthException catch (e) {
      final error = _getAuthErrorMessage(e.code);
      _errorMessage = error;
      return error;
    } catch (e) {
      const error = 'An unexpected error occurred';
      _errorMessage = error;
      return error;
    } finally {
      _setLoading(false);
    }
  }

  // Sign up method (matches what the RegisterScreen calls)
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = '';
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        // Create user document in Firestore
        UserModel newUser = UserModel(
          uid: result.user!.uid,
          email: email.trim(),
          name: name.trim(),
          role: role,
          createdAt: DateTime.now(),
          isActive: false,
        );

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(newUser.toFirestore());

        _userModel = newUser;
        return null; // No error
      }
      
      return 'Failed to create user account';
    } on FirebaseAuthException catch (e) {
      final error = _getAuthErrorMessage(e.code);
      _errorMessage = error;
      return error;
    } catch (e) {
      const error = 'An unexpected error occurred';
      _errorMessage = error;
      return error;
    } finally {
      _setLoading(false);
    }
  }

  // Legacy methods for backward compatibility
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    final error = await signIn(email: email, password: password);
    return error == null;
  }

  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    final error = await signUp(
      email: email,
      password: password,
      name: name,
      role: role,
    );
    return error == null;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Update user status to offline before signing out
      if (_user != null) {
        await _firestore.collection('users').doc(_user!.uid).update({
          'isActive': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      
      await _auth.signOut();
      _userModel = null;
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Update user status
  Future<void> updateUserStatus(bool isActive) async {
    if (_user == null) return;
    
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'isActive': isActive,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      if (_userModel != null) {
        _userModel = UserModel(
          uid: _userModel!.uid,
          email: _userModel!.email,
          name: _userModel!.name,
          role: _userModel!.role,
          createdAt: _userModel!.createdAt,
          isActive: isActive,
          lastSeen: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  // Reset password
  Future<String?> resetPassword(String email) async {
    try {
      _setLoading(true);
      _errorMessage = '';
      
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // No error
    } on FirebaseAuthException catch (e) {
      final error = _getAuthErrorMessage(e.code);
      _errorMessage = error;
      return error;
    } catch (e) {
      const error = 'An unexpected error occurred';
      _errorMessage = error;
      return error;
    } finally {
      _setLoading(false);
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      case 'invalid-credential':
        return 'The provided credentials are invalid.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An authentication error occurred.';
    }
  }
}