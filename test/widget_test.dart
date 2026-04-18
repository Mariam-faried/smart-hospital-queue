import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital_queue/services/queue_transition_policy.dart';

void main() {
  test('queue status catalog includes all required states', () {
    expect(
      QueueAppointmentStatus.all,
      contains(QueueAppointmentStatus.waiting),
    );
    expect(
      QueueAppointmentStatus.all,
      contains(QueueAppointmentStatus.inProgress),
    );
    expect(
      QueueAppointmentStatus.all,
      contains(QueueAppointmentStatus.completed),
    );
    expect(
      QueueAppointmentStatus.all,
      contains(QueueAppointmentStatus.cancelled),
    );
    expect(QueueAppointmentStatus.all, contains(QueueAppointmentStatus.noShow));
  });
}
