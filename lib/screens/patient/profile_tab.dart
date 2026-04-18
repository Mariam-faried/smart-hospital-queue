import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import 'doctor_profile_screen.dart';
import 'account_security_screen.dart';
import 'legal_document_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, User?>((p) => p.user);
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 40),
            _buildInfoSection(context),
            const SizedBox(height: 24),
            _buildSettingsSection(context),
            const SizedBox(height: 40),
            _buildLogoutButton(context),
            const SizedBox(height: 24),
            const Text(
              'MediQueue v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final name = context.select<AuthProvider, String>((p) => p.userName);
    final email = context.select<AuthProvider, String?>((p) => p.user?.email);
    final imageUrl = context.select<AuthProvider, String>((p) => p.userImageUrl);
    final displayName = name.isEmpty ? 'Patient' : name;

    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: imageUrl.trim().isEmpty
                  ? Center(
                      child: Text(
                        AppFormatters.getInitials(displayName),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl.trim(),
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          AppFormatters.getInitials(displayName),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Edit Profile',
                onPressed: () => _showEditProfileDialog(
                  context,
                  initialName: displayName,
                  initialPhone: context.read<AuthProvider>().userPhone,
                  initialImageUrl: imageUrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            email ?? 'No email',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final phone = context.select<AuthProvider, String>((p) => p.userPhone);
    final memberSince = context.select<AuthProvider, String?>(
      (p) => p.memberSince,
    );
    final favCount = context.select<AuthProvider, int>(
      (p) => p.favoriteDoctorIds.length,
    );

    return _buildCard(
      child: Column(
        children: [
          _buildInfoTile(
            Icons.phone_outlined,
            'Phone Number',
            phone.isEmpty ? 'No phone number provided' : phone,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _buildInfoTile(
            Icons.calendar_today_outlined,
            'Member Since',
            memberSince ?? 'Unknown',
          ),
          const Divider(height: 1, color: AppColors.divider),
          ListTile(
            leading: _buildIconBox(Icons.favorite_outlined),
            title: Text(
              '$favCount Saved Doctor${favCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
            onTap: () => _openSavedDoctors(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final notificationsEnabled = context.select<AuthProvider, bool>(
      (p) => p.notificationsEnabled,
    );

    return _buildCard(
      child: Column(
        children: [
          SwitchListTile(
            value: notificationsEnabled,
            onChanged: (val) =>
                context.read<AuthProvider>().setNotificationsEnabled(val),
            title: const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            secondary: const Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
            ),
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            activeThumbColor: AppColors.primary,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _buildSettingsTile(
            Icons.lock_outline_rounded,
            'Account Security',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSecurityScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),
          _buildSettingsTile(
            Icons.info_outline,
            'About MediQueue',
            () => _showInfoSheet(
              context,
              title: 'About MediQueue',
              lines: const [
                'MediQueue helps patients discover doctors, book visits, and track queue updates in real time.',
                'Our goal is to reduce waiting friction and make hospital visits more predictable for patients and staff.',
                'For support, contact your hospital reception team or app administration.',
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _buildSettingsTile(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    type: LegalDocumentType.privacy,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),
          _buildSettingsTile(
            Icons.gavel_rounded,
            'Terms & Conditions',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    type: LegalDocumentType.terms,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showLogoutDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          foregroundColor: AppColors.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // -- Shared building blocks -------------------------------------------------

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: _buildIconBox(icon),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context, {
    required String initialName,
    required String initialPhone,
    required String initialImageUrl,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: initialName == 'Patient' ? '' : initialName,
    );
    final phoneController = TextEditingController(text: initialPhone);
    final imageController = TextEditingController(text: initialImageUrl);

    final draft = await showDialog<_ProfileDraft>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Edit Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter your full name',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Name is required.';
                    if (text.length < 2) return 'Name is too short.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Optional',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    if (!RegExp(r'^[0-9+\-\s()]{7,20}$').hasMatch(text)) {
                      return 'Please enter a valid phone number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: imageController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Profile Image URL (optional)',
                    hintText: 'https://...',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final uri = Uri.tryParse(text);
                    final isValid =
                        uri != null &&
                        (uri.scheme == 'http' || uri.scheme == 'https');
                    if (!isValid) {
                      return 'Please enter a valid HTTP/HTTPS URL.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.of(ctx).pop(
                  _ProfileDraft(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    imageUrl: imageController.text.trim(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    imageController.dispose();
    if (draft == null || !context.mounted) return;

    try {
      await context.read<AuthProvider>().updateProfile(
        name: draft.name,
        phone: draft.phone,
        imageUrl: draft.imageUrl,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update profile. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchFavoriteDoctors(List<String> doctorIds) async {
    final uniqueIds = doctorIds.toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return const [];

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> collected = [];
    for (var i = 0; i < uniqueIds.length; i += 10) {
      final chunk = uniqueIds.skip(i).take(10).toList(growable: false);
      if (chunk.isEmpty) continue;
      final snapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      collected.addAll(snapshot.docs);
    }

    final order = {for (var i = 0; i < uniqueIds.length; i++) uniqueIds[i]: i};
    collected.sort((a, b) {
      final aOrder = order[a.id] ?? 1 << 30;
      final bOrder = order[b.id] ?? 1 << 30;
      return aOrder.compareTo(bOrder);
    });
    return collected;
  }

  Future<void> _openSavedDoctors(BuildContext context) async {
    final favoriteIds = context.read<AuthProvider>().favoriteDoctorIds.toList();
    if (favoriteIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved doctors yet.'),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved Doctors',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
                  ),
                  child:
                      FutureBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      >(
                        future: _fetchFavoriteDoctors(favoriteIds),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Unable to load saved doctors right now.',
                                style: TextStyle(color: AppColors.error),
                              ),
                            );
                          }
                          final docs = snapshot.data ?? const [];
                          if (docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No saved doctors are available right now.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final rawName = data['name'];
                              final name = rawName is String
                                  ? rawName.trim()
                                  : rawName?.toString().trim() ?? '';
                              final rawSpecialization = data['specialization'];
                              final specialization = rawSpecialization is String
                                  ? rawSpecialization.trim()
                                  : rawSpecialization?.toString().trim() ?? '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    AppFormatters.getInitials(
                                      name.isEmpty ? 'Doctor' : name,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name.isEmpty ? 'Unknown Doctor' : name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  specialization.isEmpty
                                      ? 'General'
                                      : specialization,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textSecondary,
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DoctorProfileScreen(
                                        doctorId: doc.id,
                                        doctorData: data,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInfoSheet(
    BuildContext context, {
    required String title,
    required List<String> lines,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to log out of MediQueue?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthProvider>().signOut();
    }
  }
}

class _ProfileDraft {
  final String name;
  final String phone;
  final String imageUrl;

  const _ProfileDraft({
    required this.name,
    required this.phone,
    required this.imageUrl,
  });
}
