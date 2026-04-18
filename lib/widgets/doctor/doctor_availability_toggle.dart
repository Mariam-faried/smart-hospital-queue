import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/doctor_provider.dart';
import '../../utils/app_colors.dart';

class DoctorAvailabilityToggle extends StatefulWidget {
  final String doctorId;

  const DoctorAvailabilityToggle({super.key, required this.doctorId});

  @override
  State<DoctorAvailabilityToggle> createState() =>
      _DoctorAvailabilityToggleState();
}

class _DoctorAvailabilityToggleState extends State<DoctorAvailabilityToggle> {
  bool _isLoading = false;

  String _statusLabel(String value) {
    final normalized = value.trim().replaceAll('_', ' ').replaceAll('-', ' ');
    if (normalized.isEmpty) return 'UNKNOWN';
    return normalized.toUpperCase();
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusTile(
              context,
              'Available',
              'available',
              true,
              Icons.radio_button_checked,
              AppColors.success,
            ),
            _buildStatusTile(
              context,
              'Busy',
              'busy',
              false,
              Icons.do_not_disturb_on,
              AppColors.warning,
            ),
            _buildStatusTile(
              context,
              'Offline',
              'offline',
              false,
              Icons.radio_button_unchecked,
              AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(
    BuildContext context,
    String title,
    String state,
    bool isAvailable,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: () async {
        Navigator.pop(context);
        setState(() => _isLoading = true);
        try {
          await context.read<DoctorProvider>().updateDoctorAvailability(
            widget.doctorId,
            isAvailable,
            state,
          );
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not update status. Please try again.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (context.mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppColors.onPrimary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Consumer<DoctorProvider>(
      builder: (context, provider, _) {
        // Find doctor info
        final docIndex = provider.doctors.indexWhere(
          (d) => d.id == widget.doctorId,
        );
        if (docIndex == -1) return const SizedBox.shrink();

        final doctor = provider.doctors[docIndex];

        Color statusColor;
        switch (doctor.currentState) {
          case 'available':
            statusColor = AppColors.success;
            break;
          case 'busy':
            statusColor = AppColors.warning;
            break;
          default:
            statusColor = AppColors.textSecondary;
        }

        return GestureDetector(
          onTap: _showStatusDialog,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.onPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(doctor.currentState),
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
