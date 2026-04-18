import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital_queue/services/queue_service.dart';
import 'package:smart_hospital_queue/services/queue_transition_policy.dart';

void main() {
  group('Queue public consistency', () {
    late FakeFirebaseFirestore firestore;
    late QueueService queueService;
    const doctorId = 'doctor-public-1';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      queueService = QueueService(firestore: firestore);
    });

    test(
      'updateQueuePositions writes sanitized queue_public entries and metadata',
      () async {
        final date = _todayDate();
        await _seedDoctor(firestore, doctorId);

        await _seedWaitingAppointment(
          firestore: firestore,
          appointmentId: 'appt-normal',
          doctorId: doctorId,
          date: date,
          ticketNumber: 1,
          priority: 'normal',
          patientType: 'new',
        );
        await _seedWaitingAppointment(
          firestore: firestore,
          appointmentId: 'appt-urgent',
          doctorId: doctorId,
          date: date,
          ticketNumber: 5,
          priority: 'urgent',
          patientType: 'followup',
        );
        await _seedWaitingAppointment(
          firestore: firestore,
          appointmentId: 'appt-emergency',
          doctorId: doctorId,
          date: date,
          ticketNumber: 2,
          priority: 'emergency',
          patientType: 'new',
        );

        await queueService.updateQueuePositions(
          doctorId: doctorId,
          date: date,
          completedTicketNumber: 0,
        );

        final queueKey = QueueService.publicQueueKey(
          doctorId: doctorId,
          date: date,
        );
        final meta = await firestore
            .collection('queue_public')
            .doc(queueKey)
            .get();
        expect(meta.exists, isTrue);
        expect(meta.data()?['doctorId'], doctorId);
        expect(meta.data()?['date'], date);
        expect(meta.data()?['updatedAt'], isA<Timestamp>());

        final emergency = await _publicEntry(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          appointmentId: 'appt-emergency',
        ).get();
        final urgent = await _publicEntry(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          appointmentId: 'appt-urgent',
        ).get();
        final normal = await _publicEntry(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          appointmentId: 'appt-normal',
        ).get();

        expect(emergency.data()?['status'], QueueAppointmentStatus.waiting);
        expect(emergency.data()?['patientsAhead'], 0);
        expect(emergency.data()?['queuePosition'], 1);
        expect(emergency.data()?['timeSlot'], '10:00 AM - 10:30 AM');
        expect(urgent.data()?['patientsAhead'], 1);
        expect(urgent.data()?['queuePosition'], 2);
        expect(urgent.data()?['timeSlot'], '10:00 AM - 10:30 AM');
        expect(normal.data()?['patientsAhead'], 2);
        expect(normal.data()?['queuePosition'], 3);
        expect(normal.data()?['timeSlot'], '10:00 AM - 10:30 AM');
      },
    );

    test(
      'markAppointmentStatus(in-progress) syncs queue_public status',
      () async {
        final date = _todayDate();
        const appointmentId = 'appt-in-progress';
        await _seedDoctor(firestore, doctorId);
        await _seedWaitingAppointment(
          firestore: firestore,
          appointmentId: appointmentId,
          doctorId: doctorId,
          date: date,
          ticketNumber: 7,
          priority: 'normal',
          patientType: 'new',
        );

        await queueService.syncPublicQueueEntryByAppointmentId(appointmentId);
        await queueService.markAppointmentStatus(
          appointmentId,
          doctorId,
          QueueAppointmentStatus.inProgress,
        );

        final entry = await _publicEntry(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          appointmentId: appointmentId,
        ).get();
        expect(entry.exists, isTrue);
        expect(entry.data()?['status'], QueueAppointmentStatus.inProgress);
        expect(entry.data()?['timeSlot'], '10:00 AM - 10:30 AM');
      },
    );

    test(
      'markAppointmentStatus(cancelled) removes queue_public entry',
      () async {
        final date = _todayDate();
        const appointmentId = 'appt-cancel-public';
        await _seedDoctor(firestore, doctorId);
        await _seedWaitingAppointment(
          firestore: firestore,
          appointmentId: appointmentId,
          doctorId: doctorId,
          date: date,
          ticketNumber: 9,
          priority: 'normal',
          patientType: 'new',
        );

        await queueService.syncPublicQueueEntryByAppointmentId(appointmentId);
        await queueService.markAppointmentStatus(
          appointmentId,
          doctorId,
          QueueAppointmentStatus.cancelled,
        );

        final entry = await _publicEntry(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          appointmentId: appointmentId,
        ).get();
        expect(entry.exists, isFalse);
      },
    );

    test('checkAndAutoNoShow removes queue_public entry', () async {
      final date = _todayDate();
      const appointmentId = 'appt-noshow-public';
      await _seedDoctor(firestore, doctorId, graceMinutes: 0);
      await _seedWaitingAppointment(
        firestore: firestore,
        appointmentId: appointmentId,
        doctorId: doctorId,
        date: date,
        ticketNumber: 11,
        priority: 'normal',
        patientType: 'new',
        timeSlot: '12:00 AM - 12:30 AM',
        checkedIn: false,
      );
      await queueService.syncPublicQueueEntryByAppointmentId(appointmentId);

      final noShowCount = await queueService.checkAndAutoNoShow(doctorId, date);

      final entry = await _publicEntry(
        firestore: firestore,
        doctorId: doctorId,
        date: date,
        appointmentId: appointmentId,
      ).get();
      expect(noShowCount, 1);
      expect(entry.exists, isFalse);
    });
  });
}

Future<void> _seedDoctor(
  FirebaseFirestore firestore,
  String doctorId, {
  int graceMinutes = 15,
}) async {
  await firestore.collection('doctors').doc(doctorId).set({
    'avgConsultationTime': 15.0,
    'noShowRate': 0.1,
    'totalCompletedAppointments': 0,
    'graceMinutes': graceMinutes,
    'currentState': 'available',
  });
}

Future<void> _seedWaitingAppointment({
  required FirebaseFirestore firestore,
  required String appointmentId,
  required String doctorId,
  required String date,
  required int ticketNumber,
  required String priority,
  required String patientType,
  String timeSlot = '10:00 AM - 10:30 AM',
  bool checkedIn = true,
  String? paymentStatus,
  String? paymentMethod,
  Timestamp? createdAt,
}) async {
  await firestore.collection('appointments').doc(appointmentId).set({
    'doctorId': doctorId,
    'date': date,
    'timeSlot': timeSlot,
    'status': QueueAppointmentStatus.waiting,
    'checkedIn': checkedIn,
    'ticketNumber': ticketNumber,
    'priority': priority,
    'patientType': patientType,
    'patientsAhead': 0,
    'estimatedWaitTime': 0,
    'paymentStatus': paymentStatus ?? 'pay_at_hospital',
    'paymentMethod': paymentMethod ?? 'pay_at_hospital',
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
  });
}

DocumentReference<Map<String, dynamic>> _publicEntry({
  required FirebaseFirestore firestore,
  required String doctorId,
  required String date,
  required String appointmentId,
}) {
  return firestore
      .collection('queue_public')
      .doc(QueueService.publicQueueKey(doctorId: doctorId, date: date))
      .collection('entries')
      .doc(appointmentId);
}

String _todayDate() {
  return DateTime.now().toIso8601String().substring(0, 10);
}
