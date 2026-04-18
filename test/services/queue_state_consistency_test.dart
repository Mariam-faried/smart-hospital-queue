import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital_queue/services/queue_service.dart';
import 'package:smart_hospital_queue/services/queue_transition_policy.dart';

void main() {
  group('Queue state consistency', () {
    late FakeFirebaseFirestore firestore;
    late QueueService queueService;
    const doctorId = 'doctor-1';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      queueService = QueueService(firestore: firestore);
    });

    test(
      'checkInPatient marks check-in fields and keeps waiting status active',
      () async {
        final date = _todayDate();
        const appointmentId = 'appt-checkin';

        await _seedDoctor(firestore, doctorId);
        await firestore.collection('appointments').doc(appointmentId).set({
          'doctorId': doctorId,
          'date': date,
          'timeSlot': '09:00 AM - 09:30 AM',
          'status': QueueAppointmentStatus.waiting,
          'checkedIn': false,
          'ticketNumber': 1,
        });

        await queueService.checkInPatient(appointmentId);

        final appointment = await firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();

        expect(appointment.data()?['status'], QueueAppointmentStatus.waiting);
        expect(appointment.data()?['checkedIn'], isTrue);
        expect(appointment.data()?['checkedInAt'], isA<Timestamp>());
        expect(appointment.data()?['checkInTime'], isA<Timestamp>());
      },
    );

    test(
      'markAppointmentStatus(cancelled) deletes slot lock and decrements activeCount',
      () async {
        final date = _todayDate();
        const appointmentId = 'appt-cancelled';
        const timeSlot = '10:00 AM - 10:30 AM';
        final lockId = _slotLockId(doctorId, date, timeSlot);

        await _seedDoctor(firestore, doctorId);
        await _seedCounter(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          activeCount: 2,
        );
        await firestore.collection('slot_locks').doc(lockId).set({
          'appointmentId': appointmentId,
        });
        await firestore.collection('appointments').doc(appointmentId).set({
          'doctorId': doctorId,
          'date': date,
          'timeSlot': timeSlot,
          'slotLockId': lockId,
          'status': QueueAppointmentStatus.waiting,
          'checkedIn': false,
          'ticketNumber': 1,
        });

        await queueService.markAppointmentStatus(
          appointmentId,
          doctorId,
          QueueAppointmentStatus.cancelled,
        );

        final appointment = await firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();
        final lock = await firestore.collection('slot_locks').doc(lockId).get();
        final counter = await _counterDoc(firestore, doctorId, date).get();

        expect(appointment.data()?['status'], QueueAppointmentStatus.cancelled);
        expect(lock.exists, isFalse);
        expect(counter.data()?['activeCount'], 1);
      },
    );

    test(
      'markAppointmentStatus(completed) deletes slot lock and decrements activeCount',
      () async {
        final date = _todayDate();
        const appointmentId = 'appt-completed';
        const timeSlot = '11:00 AM - 11:30 AM';
        final lockId = _slotLockId(doctorId, date, timeSlot);

        await _seedDoctor(firestore, doctorId);
        await _seedCounter(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          activeCount: 1,
        );
        await firestore.collection('slot_locks').doc(lockId).set({
          'appointmentId': appointmentId,
        });
        await firestore.collection('appointments').doc(appointmentId).set({
          'doctorId': doctorId,
          'date': date,
          'timeSlot': timeSlot,
          'slotLockId': lockId,
          'status': QueueAppointmentStatus.inProgress,
          'checkedIn': true,
          'ticketNumber': 2,
          'consultationStartTime': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        });

        await queueService.markAppointmentStatus(
          appointmentId,
          doctorId,
          QueueAppointmentStatus.completed,
        );

        final appointment = await firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();
        final lock = await firestore.collection('slot_locks').doc(lockId).get();
        final counter = await _counterDoc(firestore, doctorId, date).get();

        expect(appointment.data()?['status'], QueueAppointmentStatus.completed);
        expect(lock.exists, isFalse);
        expect(counter.data()?['activeCount'], 0);
      },
    );

    test(
      'checkAndAutoNoShow marks no-show, deletes lock, and decrements activeCount by count',
      () async {
        final date = _todayDate();
        const appointmentId = 'appt-noshow';
        const timeSlot = '12:00 AM - 12:30 AM';
        final lockId = _slotLockId(doctorId, date, timeSlot);

        await _seedDoctor(firestore, doctorId, graceMinutes: 0);
        await _seedCounter(
          firestore: firestore,
          doctorId: doctorId,
          date: date,
          activeCount: 1,
        );
        await firestore.collection('slot_locks').doc(lockId).set({
          'appointmentId': appointmentId,
        });
        await firestore.collection('appointments').doc(appointmentId).set({
          'doctorId': doctorId,
          'date': date,
          'timeSlot': timeSlot,
          'slotLockId': lockId,
          'status': QueueAppointmentStatus.waiting,
          'checkedIn': false,
          'ticketNumber': 3,
        });

        final noShowCount = await queueService.checkAndAutoNoShow(
          doctorId,
          date,
        );

        final appointment = await firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();
        final lock = await firestore.collection('slot_locks').doc(lockId).get();
        final counter = await _counterDoc(firestore, doctorId, date).get();

        expect(noShowCount, 1);
        expect(appointment.data()?['status'], QueueAppointmentStatus.noShow);
        expect(lock.exists, isFalse);
        expect(counter.data()?['activeCount'], 0);
      },
    );
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

Future<void> _seedCounter({
  required FirebaseFirestore firestore,
  required String doctorId,
  required String date,
  required int activeCount,
}) async {
  await _counterDoc(
    firestore,
    doctorId,
    date,
  ).set({'doctorId': doctorId, 'date': date, 'activeCount': activeCount});
}

DocumentReference<Map<String, dynamic>> _counterDoc(
  FirebaseFirestore firestore,
  String doctorId,
  String date,
) {
  return firestore.doc('counters/tickets_${doctorId}_$date');
}

String _slotLockId(String doctorId, String date, String timeSlot) {
  final safeSlot = timeSlot.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  return '${doctorId}_${date}_$safeSlot';
}

String _todayDate() {
  return DateTime.now().toIso8601String().substring(0, 10);
}
