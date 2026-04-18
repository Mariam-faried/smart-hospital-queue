import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital_queue/services/queue_transition_policy.dart';

void main() {
  group('QueueTransitionPolicy.validate', () {
    test('allows waiting -> in-progress when checked in', () {
      final result = QueueTransitionPolicy.validate(
        fromStatus: QueueAppointmentStatus.waiting,
        toStatus: QueueAppointmentStatus.inProgress,
        checkedIn: true,
      );

      expect(result.isAllowed, isTrue);
      expect(result.message, isNull);
    });

    test('denies waiting -> in-progress when not checked in', () {
      final result = QueueTransitionPolicy.validate(
        fromStatus: QueueAppointmentStatus.waiting,
        toStatus: QueueAppointmentStatus.inProgress,
        checkedIn: false,
      );

      expect(result.isAllowed, isFalse);
      expect(result.message, contains('checked in'));
    });

    test('allows waiting -> no-show when not checked in', () {
      final result = QueueTransitionPolicy.validate(
        fromStatus: QueueAppointmentStatus.waiting,
        toStatus: QueueAppointmentStatus.noShow,
        checkedIn: false,
      );

      expect(result.isAllowed, isTrue);
    });

    test('denies waiting -> no-show when checked in', () {
      final result = QueueTransitionPolicy.validate(
        fromStatus: QueueAppointmentStatus.waiting,
        toStatus: QueueAppointmentStatus.noShow,
        checkedIn: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.message, contains('Checked-in'));
    });

    test('allows in-progress -> completed', () {
      final result = QueueTransitionPolicy.validate(
        fromStatus: QueueAppointmentStatus.inProgress,
        toStatus: QueueAppointmentStatus.completed,
        checkedIn: true,
      );

      expect(result.isAllowed, isTrue);
    });

    test('denies completed -> waiting', () {
      final result = QueueTransitionPolicy.validate(
        fromStatus: QueueAppointmentStatus.completed,
        toStatus: QueueAppointmentStatus.waiting,
        checkedIn: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.message, contains('Cannot change status'));
    });

    test('allows waiting -> cancelled', () {
      final result = QueueTransitionPolicy.validate(
        fromStatus: QueueAppointmentStatus.waiting,
        toStatus: QueueAppointmentStatus.cancelled,
        checkedIn: false,
      );

      expect(result.isAllowed, isTrue);
    });
  });

  group('QueueTransitionPolicy helpers', () {
    test('queue recalculation statuses are correct', () {
      expect(
        QueueTransitionPolicy.shouldRecalculateQueue(
          QueueAppointmentStatus.completed,
        ),
        isTrue,
      );
      expect(
        QueueTransitionPolicy.shouldRecalculateQueue(
          QueueAppointmentStatus.noShow,
        ),
        isTrue,
      );
      expect(
        QueueTransitionPolicy.shouldRecalculateQueue(
          QueueAppointmentStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        QueueTransitionPolicy.shouldRecalculateQueue(
          QueueAppointmentStatus.inProgress,
        ),
        isFalse,
      );
    });

    test('no-show rate update only for no-show status', () {
      expect(
        QueueTransitionPolicy.shouldUpdateNoShowRate(
          QueueAppointmentStatus.noShow,
        ),
        isTrue,
      );
      expect(
        QueueTransitionPolicy.shouldUpdateNoShowRate(
          QueueAppointmentStatus.completed,
        ),
        isFalse,
      );
    });
  });
}
