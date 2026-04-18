part of 'receptionist_dashboard.dart';

// =======================================
// SHARED WIDGETS
// =======================================

String _readString(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) return fallback;
  return normalized;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

Timestamp? _resolveCheckInStamp(Map<String, dynamic> data) {
  final checkedInAt = data['checkedInAt'];
  if (checkedInAt is Timestamp) return checkedInAt;
  if (checkedInAt is DateTime) return Timestamp.fromDate(checkedInAt);

  final checkInTime = data['checkInTime'];
  if (checkInTime is Timestamp) return checkInTime;
  if (checkInTime is DateTime) return Timestamp.fromDate(checkInTime);

  return null;
}

Timestamp? _resolveCreatedAtStamp(Map<String, dynamic> data) {
  final createdAt = data['createdAt'];
  if (createdAt is Timestamp) return createdAt;
  if (createdAt is DateTime) return Timestamp.fromDate(createdAt);
  return null;
}

String _formatDoctorName(String rawName) {
  final trimmed = rawName.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown') {
    return 'Dr. Unknown';
  }

  final lower = trimmed.toLowerCase();
  if (lower.startsWith('dr.') || lower.startsWith('dr ')) {
    return trimmed;
  }

  return 'Dr. $trimmed';
}

String _buildDoctorSubtitle(String doctorName, String timeSlot) {
  final doctorLabel = _formatDoctorName(doctorName);
  if (timeSlot.trim().isEmpty) return doctorLabel;
  return '$doctorLabel - ${timeSlot.trim()}';
}

String _formatStatusLabel(String status) {
  switch (status) {
    case 'all':
      return 'All';
    case QueueAppointmentStatus.inProgress:
      return 'In Progress';
    case QueueAppointmentStatus.noShow:
      return 'No Show';
    default:
      final normalized = status
          .trim()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      if (normalized.isEmpty) return 'Unknown';
      return normalized
          .split(RegExp(r'\s+'))
          .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
  }
}

String _toBadgeLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'UNKNOWN';
  return normalized.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: AppColors.textPrimary.withValues(alpha: 0.06),
        blurRadius: 12,
        spreadRadius: 0,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.03),
        blurRadius: 6,
        spreadRadius: 0,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

Widget _buildEmptyState({required IconData icon, required String message}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

void _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
          ),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    context.read<AuthProvider>().signOut();
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() {
    switch (status) {
      case QueueAppointmentStatus.waiting:
        return AppColors.statusWaiting;
      case QueueAppointmentStatus.inProgress:
        return AppColors.statusInProgress;
      case QueueAppointmentStatus.completed:
        return AppColors.statusCompleted;
      case QueueAppointmentStatus.cancelled:
        return AppColors.statusCancelled;
      case QueueAppointmentStatus.noShow:
        return AppColors.statusNoShow;
      default:
        return AppColors.textSecondary;
    }
  }

  String _label() {
    switch (status) {
      case QueueAppointmentStatus.inProgress:
        return 'IN PROGRESS';
      case QueueAppointmentStatus.noShow:
        return 'NO SHOW';
      default:
        return _toBadgeLabel(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.statusSurface(chipColor),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.statusBorder(chipColor)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
          color: chipColor,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.onPrimary
              : AppColors.onPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.primary
                : AppColors.onPrimary.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AppointmentCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final patientName = data['patientName'] as String? ?? 'Unknown';
    final doctorName = _formatDoctorName(
      data['doctorName'] as String? ?? 'Unknown',
    );
    final status = data['status'] as String? ?? QueueAppointmentStatus.waiting;
    final timeSlot = data['timeSlot'] as String? ?? '';
    final ticket = AppFormatters.formatTicket(data['ticketNumber']);
    final priority = data['priority'] as String? ?? 'normal';
    final paymentStatus = data['paymentStatus'] as String? ?? 'pay_at_hospital';
    final checkedIn = data['checkedIn'] as bool? ?? false;
    final totalFee = _readInt(data['totalFee']);
    final currency = _readString(
      data['currency'],
      fallback: 'EGP',
    ).toUpperCase();
    final initials = AppFormatters.getInitials(patientName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: patient name + status
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      doctorName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: details
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                ticket,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.access_time,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  timeSlot,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (priority != 'normal') ...[
                const SizedBox(width: 8),
                Icon(
                  priority == 'emergency'
                      ? Icons.emergency
                      : Icons.priority_high,
                  size: 14,
                  color: priority == 'emergency'
                      ? AppColors.error
                      : AppColors.warning,
                ),
                const SizedBox(width: 2),
                Text(
                  _toBadgeLabel(priority),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: priority == 'emergency'
                        ? AppColors.error
                        : AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: payment + check-in status
          Row(
            children: [
              // Payment badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.statusSurface(_paymentColor(paymentStatus)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.statusBorder(_paymentColor(paymentStatus)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _paymentIcon(paymentStatus),
                      size: 12,
                      color: _paymentColor(paymentStatus),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      totalFee > 0
                          ? '${_paymentLabel(paymentStatus)} - $totalFee $currency'
                          : _paymentLabel(paymentStatus),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                        color: _paymentColor(paymentStatus),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                checkedIn ? Icons.how_to_reg : Icons.person_outline,
                size: 14,
                color: checkedIn ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                checkedIn ? 'Checked In' : 'Not Checked In',
                style: TextStyle(
                  fontSize: 11,
                  color: checkedIn
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pay_at_hospital':
        return 'PAY AT HOSPITAL';
      case 'paid':
        return 'PAID';
      case 'free':
        return 'FREE';
      default:
        return _toBadgeLabel(status);
    }
  }

  Color _paymentColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'pay_at_hospital':
        return AppColors.info;
      case 'free':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _paymentIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pay_at_hospital':
        return Icons.local_hospital_outlined;
      case 'paid':
      case 'free':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }
}
