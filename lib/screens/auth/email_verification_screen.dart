import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:smart_hospital_queue/utils/app_colors.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/auth_background.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  DateTime? _resendAvailableAt;
  Timer? _resendTicker;
  String? _message;

  bool get _canResend {
    final resendAvailableAt = _resendAvailableAt;
    if (resendAvailableAt == null) return true;
    return DateTime.now().isAfter(resendAvailableAt);
  }

  Duration get _resendRemaining {
    final resendAvailableAt = _resendAvailableAt;
    if (resendAvailableAt == null) return Duration.zero;
    final diff = resendAvailableAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _resendTicker?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final isVerified = await authProvider.reloadAndCheckEmailVerified();
      if (!mounted) return;

      if (!isVerified) {
        setState(() {
          _message =
              'Email is not verified yet. Open your inbox and tap the verification link.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not refresh verification status. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _message = 'Session expired. Please sign in again.';
        });
        return;
      }

      await user.sendEmailVerification();
      if (!mounted) return;

      _startResendCooldown();
      setState(() {
        _message = 'Verification email sent. Check your inbox and spam folder.';
      });
    } on FirebaseAuthException catch (e) {
      var message = 'Could not send verification email right now.';
      if (e.code == 'too-many-requests') {
        message = 'Too many requests. Please wait before trying again.';
      }
      if (!mounted) return;
      setState(() => _message = message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not send verification email right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _startResendCooldown() {
    _resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));
    _resendTicker?.cancel();
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_canResend) {
        setState(() {
          _resendAvailableAt = null;
        });
        _resendTicker?.cancel();
        _resendTicker = null;
        return;
      }
      setState(() {});
    });
  }

  String _formatCountdown(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'your email address';

    return Scaffold(
      body: AuthBackground(
        title: 'Verify Your Email',
        subtitle: 'Secure your account before continuing',
        child: Column(
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Check Your Inbox',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verify your email address: $email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the link from your inbox, then return and confirm below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.infoSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isChecking ? null : _checkVerification,
                      child: _isChecking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('I Have Verified My Email'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: (_isResending || !_canResend)
                          ? null
                          : _resendVerificationEmail,
                      child: _isResending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : Text(
                              _canResend
                                  ? 'Resend Verification Email'
                                  : 'Resend in ${_formatCountdown(_resendRemaining)}',
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<AuthProvider>().signOut(),
                    child: const Text('Use a different account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
