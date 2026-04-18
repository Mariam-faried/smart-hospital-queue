import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isUpdatingEmail = false;
  bool _isUpdatingPassword = false;
  bool _isSendingResetEmail = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newEmailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _usesPasswordProvider(User user) {
    return user.providerData.any((provider) => provider.providerId == 'password');
  }

  void _showSnack(
    String message, {
    Color backgroundColor = AppColors.primary,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Future<User?> _currentUserOrError() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack(
        'No authenticated account found. Please sign in again.',
        backgroundColor: AppColors.error,
      );
      return null;
    }
    return user;
  }

  Future<void> _updateEmail() async {
    if (_isUpdatingEmail || _isUpdatingPassword) return;
    final user = await _currentUserOrError();
    if (user == null) return;

    if (!_usesPasswordProvider(user)) {
      _showSnack(
        'Email updates require password login. Please use your provider account settings.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final currentEmail = (user.email ?? '').trim().toLowerCase();
    if (currentEmail.isEmpty) {
      _showSnack(
        'Current email is unavailable. Please sign in again.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    final newEmail = _newEmailController.text.trim().toLowerCase();
    final currentPassword = _currentPasswordController.text;
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (newEmail.isEmpty || !emailPattern.hasMatch(newEmail)) {
      _showSnack(
        'Please enter a valid new email address.',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    if (newEmail == currentEmail) {
      _showSnack(
        'New email must be different from your current email.',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    if (currentPassword.trim().isEmpty) {
      _showSnack(
        'Enter your current password to continue.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _isUpdatingEmail = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      _newEmailController.clear();
      _showSnack(
        'Verification link sent to $newEmail. Confirm it to complete email update.',
        backgroundColor: AppColors.success,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnack(
        _mapAuthException(error),
        backgroundColor: AppColors.error,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Could not update email right now. Please try again.',
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isUpdatingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_isUpdatingPassword || _isUpdatingEmail) return;
    final user = await _currentUserOrError();
    if (user == null) return;

    if (!_usesPasswordProvider(user)) {
      _showSnack(
        'Password changes require password login. Please use your provider account settings.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      _showSnack(
        'Current email is unavailable. Please sign in again.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.trim().isEmpty) {
      _showSnack(
        'Enter your current password to continue.',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    if (newPassword.length < 8) {
      _showSnack(
        'New password must be at least 8 characters.',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnack(
        'New password and confirmation do not match.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack(
        'Password updated successfully.',
        backgroundColor: AppColors.success,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnack(
        _mapAuthException(error),
        backgroundColor: AppColors.error,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Could not update password right now. Please try again.',
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_isSendingResetEmail) return;
    final user = await _currentUserOrError();
    if (user == null) return;
    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      _showSnack(
        'No email is linked to this account.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    setState(() => _isSendingResetEmail = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showSnack(
        'Password reset email sent to $email.',
        backgroundColor: AppColors.success,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnack(
        _mapAuthException(error),
        backgroundColor: AppColors.error,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Could not send reset email right now.',
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isSendingResetEmail = false);
    }
  }

  String _mapAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'requires-recent-login':
        return 'Please sign in again and retry this action.';
      case 'email-already-in-use':
        return 'This email is already in use by another account.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        final fallback = (error.message ?? '').trim();
        return fallback.isEmpty
            ? 'Authentication action failed. Please try again.'
            : fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isUpdatingEmail || _isUpdatingPassword || _isSendingResetEmail;
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      appBar: AppBar(
        title: const Text('Account Security'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Current account email: $currentEmail\n'
                'For sensitive changes, enter your current password to re-authenticate.',
                style: const TextStyle(
                  color: AppColors.info,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Current Password',
              child: TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                enabled: !isBusy,
                decoration: InputDecoration(
                  hintText: 'Enter current password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Change Email',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      hintText: 'New email address',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingEmail || isBusy ? null : _updateEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                      ),
                      child: _isUpdatingEmail
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Send Email Verification'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Change Password',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      hintText: 'New password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      hintText: 'Confirm new password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingPassword || isBusy
                          ? null
                          : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: AppColors.onPrimary,
                      ),
                      child: _isUpdatingPassword
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Recovery',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : _sendPasswordResetEmail,
                  icon: _isSendingResetEmail
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mark_email_unread_outlined),
                  label: const Text('Send Password Reset Email'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

