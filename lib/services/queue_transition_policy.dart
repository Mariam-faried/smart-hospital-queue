/// Canonical appointment statuses used in queue/reception workflows.
abstract final class QueueAppointmentStatus {
  static const String waiting = 'waiting';
  static const String confirmed = 'confirmed';
  static const String inProgress = 'in-progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String noShow = 'no-show';

  static const List<String> activeList = <String>[
    waiting,
    confirmed,
    inProgress,
  ];

  static const Set<String> activeSet = <String>{waiting, confirmed, inProgress};

  static const Set<String> all = {
    waiting,
    confirmed,
    inProgress,
    completed,
    cancelled,
    noShow,
  };
}

class QueueTransitionValidation {
  final bool isAllowed;
  final String? message;

  const QueueTransitionValidation._({required this.isAllowed, this.message});

  const QueueTransitionValidation.allowed() : this._(isAllowed: true);

  const QueueTransitionValidation.denied(String message)
    : this._(isAllowed: false, message: message);
}

/// Transition policy for queue-related status updates.
abstract final class QueueTransitionPolicy {
  static bool isActiveStatus(String? status) {
    if (status == null) return false;
    final normalized = normalizeStatus(status);
    return QueueAppointmentStatus.activeSet.contains(normalized);
  }

  static int parseTicketNumber(dynamic raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return fallback;

      final direct = int.tryParse(value);
      if (direct != null) return direct;

      final noPrefix = value.toUpperCase().startsWith('T-')
          ? value.substring(2)
          : value;
      final prefixed = int.tryParse(noPrefix);
      if (prefixed != null) return prefixed;

      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        final parsed = int.tryParse(digits);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  static String normalizeStatus(String status) {
    return status.trim().toLowerCase().replaceAll('_', '-');
  }

  static QueueTransitionValidation validate({
    required String fromStatus,
    required String toStatus,
    required bool checkedIn,
  }) {
    final from = normalizeStatus(fromStatus);
    final to = normalizeStatus(toStatus);

    if (!QueueAppointmentStatus.all.contains(to)) {
      return QueueTransitionValidation.denied('Unsupported status "$to".');
    }

    if (from == to) {
      return const QueueTransitionValidation.allowed();
    }

    switch (from) {
      case QueueAppointmentStatus.waiting:
        if (to == QueueAppointmentStatus.inProgress) {
          return checkedIn
              ? const QueueTransitionValidation.allowed()
              : const QueueTransitionValidation.denied(
                  'Patient must be checked in before being called.',
                );
        }
        if (to == QueueAppointmentStatus.noShow) {
          return checkedIn
              ? const QueueTransitionValidation.denied(
                  'Checked-in patients cannot be marked as no-show.',
                )
              : const QueueTransitionValidation.allowed();
        }
        if (to == QueueAppointmentStatus.cancelled) {
          return const QueueTransitionValidation.allowed();
        }
        break;
      case QueueAppointmentStatus.confirmed:
        if (to == QueueAppointmentStatus.inProgress ||
            to == QueueAppointmentStatus.cancelled) {
          return const QueueTransitionValidation.allowed();
        }
        break;
      case QueueAppointmentStatus.inProgress:
        if (to == QueueAppointmentStatus.completed ||
            to == QueueAppointmentStatus.cancelled) {
          return const QueueTransitionValidation.allowed();
        }
        break;
      case QueueAppointmentStatus.completed:
      case QueueAppointmentStatus.cancelled:
      case QueueAppointmentStatus.noShow:
        return QueueTransitionValidation.denied(
          'Cannot change status after "$from".',
        );
      default:
        return QueueTransitionValidation.denied(
          'Unsupported current status "$from".',
        );
    }

    return QueueTransitionValidation.denied(
      'Invalid status transition from "$from" to "$to".',
    );
  }

  static bool shouldRecalculateQueue(String status) {
    final normalized = normalizeStatus(status);
    return normalized == QueueAppointmentStatus.completed ||
        normalized == QueueAppointmentStatus.noShow ||
        normalized == QueueAppointmentStatus.cancelled;
  }

  static bool shouldUpdateNoShowRate(String status) {
    return normalizeStatus(status) == QueueAppointmentStatus.noShow;
  }
}
