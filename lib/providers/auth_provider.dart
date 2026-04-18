// lib/providers/auth_provider.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuthProvider with ChangeNotifier {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  

  User? _user;
  String? _userRole;
  bool _isLoading = true;

  String? _authError;
  String? get authError => _authError;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  String _userName = '';
  String get userName => _userName;

  String _userPhone = '';
  String get userPhone => _userPhone;

  String _userImageUrl = '';
  String get userImageUrl => _userImageUrl;

  String? _memberSince;
  String? get memberSince => _memberSince;

  Set<String> _favoriteDoctorIds = {};
  Set<String> get favoriteDoctorIds => _favoriteDoctorIds;

  bool isFavorite(String doctorId) => _favoriteDoctorIds.contains(doctorId);

  User? get user => _user;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;

  void _logDebug(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'AuthProvider');
    }
  }

  void clearAuthError() {
    _authError = null;
    notifyListeners();
  }

  AuthProvider() {
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _fetchUserRole(user.uid);
      } else {
        _userRole = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserRole(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        // Document genuinely missing — sign out is appropriate
        _logDebug('User document not found for uid: $uid');
        _authError = 'Account data not found. Please contact support.';
        _isLoading = false;
        notifyListeners();
        await _auth.signOut();
        return;
      }

      final data = doc.data();
      _userRole = data?['role'] as String?;
      _userName = data?['name'] as String? ?? '';
      _userPhone = data?['phone'] as String? ?? '';
      _userImageUrl = data?['imageUrl'] as String? ?? '';
      _memberSince = _formatMemberSince(data?['createdAt']);
      _loadNotificationPreferenceFromData(data);
      _loadFavoritesFromData(data);
      _isLoading = false;
      notifyListeners();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        // Network error — do NOT sign out, just stop loading
        _logDebug('Network error fetching user role: ${e.message}');
        _isLoading = false;
        notifyListeners();
      } else {
        // Other Firebase error — sign out as before
        _logDebug('Firebase error fetching user role: ${e.message}');
        await signOut();
      }
    } catch (e) {
      // Unknown error — do NOT sign out, fail gracefully
      _logDebug('Unexpected error fetching user role: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadNotificationPreferenceFromData(Map<String, dynamic>? data) {
    _notificationsEnabled = data?['notificationsEnabled'] ?? true;
  }

  void _loadFavoritesFromData(Map<String, dynamic>? data) {
    final favs = List<String>.from(data?['favoriteDoctors'] ?? []);
    _favoriteDoctorIds = favs.toSet();
  }

  String? _formatMemberSince(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return DateFormat('MMMM yyyy').format(timestamp.toDate());
    }
    if (timestamp is String) {
      try {
        return DateFormat('MMMM yyyy').format(DateTime.parse(timestamp));
      } catch (_) {
        return timestamp;
      }
    }
    return null;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _firestore.collection('users').doc(uid).update({
        'notificationsEnabled': value,
      });
    } catch (e) {
      _logDebug('Failed to save notification preference: $e');
    }
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? imageUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No authenticated user found.');
    }

    final normalizedName = name.trim();
    final normalizedPhone = phone.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Name is required.');
    }

    final payload = <String, dynamic>{
      'name': normalizedName,
      'phone': normalizedPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (imageUrl != null) {
      payload['imageUrl'] = imageUrl.trim();
    }

    await _firestore.collection('users').doc(uid).update(payload);

    _userName = normalizedName;
    _userPhone = normalizedPhone;
    if (imageUrl != null) {
      _userImageUrl = imageUrl.trim();
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(String doctorId) async {
    if (_favoriteDoctorIds.contains(doctorId)) {
      _favoriteDoctorIds.remove(doctorId);
    } else {
      _favoriteDoctorIds.add(doctorId);
    }
    notifyListeners();

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _firestore.collection('users').doc(uid).update({
        'favoriteDoctors': _favoriteDoctorIds.toList(),
      });
    } catch (e) {
      _logDebug('Failed to save favorite: $e');
      // Revert optimistic update on failure
      if (_favoriteDoctorIds.contains(doctorId)) {
        _favoriteDoctorIds.remove(doctorId);
      } else {
        _favoriteDoctorIds.add(doctorId);
      }
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      // Keep auth error codes for the login screen (lockout, precise messaging).
      rethrow;
    } catch (e) {
      throw 'An unexpected error occurred: ${e.toString()}';
    }
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    await currentUser.reload();
    _user = _auth.currentUser;
    notifyListeners();
    return _user?.emailVerified ?? false;
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'patient',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      throw _mapAuthException(e);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw 'An unexpected error occurred: ${e.toString()}';
    }
  }

  String _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'invalid-email':
        return 'Invalid email address.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  Future<void> signOut() async {
    // Reset state immediately before Firebase signout
    _userRole = null;
    _isLoading = false;
    _favoriteDoctorIds.clear();
    _notificationsEnabled = true;
    _userName = '';
    _userPhone = '';
    _userImageUrl = '';
    _memberSince = null;
    notifyListeners();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
