import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../screens/patient/doctor_chat_screen.dart';
import '../../utils/app_colors.dart';

class DoctorQuickActions extends StatefulWidget {
  final String doctorId;
  final String? phoneNumber;
  final String doctorName;

  const DoctorQuickActions({
    super.key,
    required this.doctorId,
    this.phoneNumber,
    required this.doctorName,
  });

  @override
  State<DoctorQuickActions> createState() => _DoctorQuickActionsState();
}

class _DoctorQuickActionsState extends State<DoctorQuickActions> {
  String _resolvedPhone = '';
  bool _isLoadingPhone = false;

  String _readString(dynamic value) {
    if (value == null) return '';
    final text = value is String ? value.trim() : value.toString().trim();
    return text;
  }

  @override
  void initState() {
    super.initState();
    _resolvePhoneNumber();
  }

  @override
  void didUpdateWidget(covariant DoctorQuickActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctorId != widget.doctorId ||
        oldWidget.phoneNumber != widget.phoneNumber) {
      _resolvePhoneNumber();
    }
  }

  Future<void> _resolvePhoneNumber() async {
    final directPhone = _readString(widget.phoneNumber);
    if (directPhone.isNotEmpty) {
      if (mounted) {
        setState(() {
          _resolvedPhone = directPhone;
          _isLoadingPhone = false;
        });
      }
      return;
    }

    final doctorId = widget.doctorId.trim();
    if (doctorId.isEmpty) {
      if (mounted) {
        setState(() {
          _resolvedPhone = '';
          _isLoadingPhone = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingPhone = true);
    }

    try {
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .get();

      final data = doctorDoc.data();
      final primaryPhone = _readString(data?['phone']);
      final secondaryPhone = _readString(data?['phoneNumber']);
      final fallbackPhone = _readString(data?['contactPhone']);
      final fetchedPhone = primaryPhone.isNotEmpty
          ? primaryPhone
          : (secondaryPhone.isNotEmpty ? secondaryPhone : fallbackPhone);
      if (mounted) {
        setState(() {
          _resolvedPhone = fetchedPhone;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _resolvedPhone = '');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPhone = false);
      }
    }
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = true,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _makeCall(BuildContext context) async {
    if (_isLoadingPhone) {
      _showMessage(
        context,
        'Preparing doctor contact details. Please try again in a moment.',
      );
      return;
    }

    final phone = _readString(_resolvedPhone);
    if (phone.isEmpty) {
      _showMessage(context, 'Phone number is unavailable for this doctor.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    final canOpen = await canLaunchUrl(uri);
    if (!canOpen) {
      if (context.mounted) {
        _showMessage(context, 'Could not start a phone call on this device.');
      }
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && context.mounted) {
      _showMessage(context, 'Could not start a phone call on this device.');
    }
  }

  Future<void> _sendMessage(BuildContext context) async {
    if (widget.doctorId.trim().isEmpty) {
      _showMessage(context, 'Doctor chat is unavailable right now.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorChatScreen(
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    Future<void> Function() onTap, {
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? () => onTap() : null,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: enabled
                  ? color.withValues(alpha: 0.1)
                  : AppColors.divider.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled
                    ? color.withValues(alpha: 0.2)
                    : AppColors.divider,
              ),
            ),
            child: Icon(
              icon,
              color: enabled ? color : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context,
            Icons.phone_outlined,
            'Call',
            AppColors.success,
            () => _makeCall(context),
            enabled: !_isLoadingPhone,
          ),
          _buildActionButton(
            context,
            Icons.chat_bubble_outline,
            'Message',
            AppColors.info,
            () => _sendMessage(context),
          ),
        ],
      ),
    );
  }
}
