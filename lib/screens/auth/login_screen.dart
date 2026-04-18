import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:smart_hospital_queue/utils/app_colors.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/custom_text_field.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 2);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  int _failedAttempts = 0;
  DateTime? _lockoutEndsAt;
  Timer? _lockoutTicker;
  String? _errorMessage;
  String? _selectedRole;

  bool get _isLockedOut {
    final lockoutEndsAt = _lockoutEndsAt;
    if (lockoutEndsAt == null) return false;
    return DateTime.now().isBefore(lockoutEndsAt);
  }

  Duration get _lockoutRemaining {
    final lockoutEndsAt = _lockoutEndsAt;
    if (lockoutEndsAt == null) return Duration.zero;
    final diff = lockoutEndsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLockedOut) {
      setState(() {
        _errorMessage =
            'Too many failed attempts. Try again in ${_formatLockoutTime(_lockoutRemaining)}.';
      });
      return;
    }

    if (!_formKey.currentState!.validate() || _selectedRole == null) {
      setState(() => _errorMessage = 'Please select a role to continue.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Authentication failed');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final roleField = userData['role'];
      if (roleField is! String || roleField.trim().isEmpty) {
        await authProvider.signOut();
        throw Exception('Account role is missing. Contact support for help.');
      }

      final userRole = roleField.trim().toLowerCase();
      final accountStatus = (userData['accountStatus'] as String? ?? 'active')
          .trim()
          .toLowerCase();
      final selectedRole = _selectedRole!.toLowerCase();

      if (userRole != selectedRole) {
        await authProvider.signOut();
        throw Exception('You don\'t have access as $selectedRole');
      }

      if (userRole == 'doctor' && accountStatus == 'pending') {
        await authProvider.signOut();
        throw Exception(
          'Your doctor account is pending admin approval. Please wait for verification.',
        );
      }

      if (accountStatus == 'suspended' || accountStatus == 'rejected') {
        await authProvider.signOut();
        throw Exception(
          'Your account has been $accountStatus. Contact support for help.',
        );
      }

      _clearFailedAttempts();
    } on FirebaseAuthException catch (e) {
      var message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid email or password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      }

      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = _registerFailedAttempt(message);
      }

      if (mounted) {
        setState(() => _errorMessage = message);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _registerFailedAttempt(String baseMessage) {
    _failedAttempts += 1;
    final attemptsLeft = _maxFailedAttempts - _failedAttempts;

    if (attemptsLeft <= 0) {
      _lockoutEndsAt = DateTime.now().add(_lockoutDuration);
      _failedAttempts = 0;
      _startLockoutTicker();
      return 'Too many failed attempts. Try again in ${_formatLockoutTime(_lockoutRemaining)}.';
    }

    final attemptsText = attemptsLeft == 1 ? 'attempt' : 'attempts';
    return '$baseMessage. $attemptsLeft $attemptsText left before temporary lockout.';
  }

  void _clearFailedAttempts() {
    _failedAttempts = 0;
    _lockoutEndsAt = null;
    _lockoutTicker?.cancel();
    _lockoutTicker = null;
  }

  void _startLockoutTicker() {
    _lockoutTicker?.cancel();
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_isLockedOut) {
        setState(() {
          _lockoutEndsAt = null;
          _errorMessage = 'You can try logging in again now.';
        });
        _lockoutTicker?.cancel();
        _lockoutTicker = null;
        return;
      }

      setState(() {
        _errorMessage =
            'Too many failed attempts. Try again in ${_formatLockoutTime(_lockoutRemaining)}.';
      });
    });
  }

  String _formatLockoutTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final secondsText = seconds.toString().padLeft(2, '0');
    return '$minutes:$secondsText';
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Enter your email first, then tap Forgot Password.';
      });
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Enter a valid email address first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      var message = 'Unable to send reset email right now.';
      if (e.code == 'invalid-email') {
        message = 'This email address is not valid.';
      } else if (e.code == 'user-not-found') {
        message = 'No account was found for this email.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }
      if (!mounted) return;
      setState(() => _errorMessage = message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to send reset email right now.');
    }
  }

  Widget _buildRoleSelector() {
    final roles = [
      {'value': 'patient', 'label': 'Patient', 'icon': Icons.person_outline},
      {
        'value': 'doctor',
        'label': 'Doctor',
        'icon': Icons.medical_services_outlined,
      },
      {
        'value': 'receptionist',
        'label': 'Receptionist',
        'icon': Icons.desk_outlined,
      },
      {
        'value': 'admin',
        'label': 'Admin',
        'icon': Icons.admin_panel_settings_outlined,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: roles.map((role) {
            final isSelected = _selectedRole == role['value'];
            const selectedColor = AppColors.primaryLight;
            const selectedForeground = AppColors.primaryDark;
            const unselectedIcon = AppColors.primary;

            return InkWell(
              onTap: () {
                setState(() {
                  _errorMessage = null;
                  _selectedRole = role['value'] as String;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      role['icon'] as IconData,
                      size: 32,
                      color: isSelected ? selectedForeground : unselectedIcon,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? selectedForeground
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPatientRegistrationFlow =
        _selectedRole == null || _selectedRole == 'patient';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: AuthBackground(
          title: 'MediQueue',
          subtitle: 'Skip the Wait, Not the Care',
          child: Column(
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _buildRoleSelector(),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.infoSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Doctor, Receptionist, and Admin accounts are created by hospital administration.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        label: 'Email',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(
                            r'^[^@]+@[^@]+\.[^@]+',
                          ).hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      CustomTextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        label: 'Password',
                        hint: '********',
                        icon: Icons.lock_outline,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : _handlePasswordReset,
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || _isLockedOut)
                              ? null
                              : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : const Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (isPatientRegistrationFlow)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Need a patient account? ',
                      style: TextStyle(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text(
                        'Register as Patient',
                        style: TextStyle(
                          color: AppColors.accentGold,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.accentGold,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 16,
                      color: AppColors.onPrimary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Staff accounts are created by hospital admin',
                      style: TextStyle(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
