import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/patient/appointments_list_builder.dart';
import 'appointment_actions_mixin.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab>
    with SingleTickerProviderStateMixin, AppointmentActionsMixin {
  final Set<String> _shownPaymentConfirmations = {};
  late TabController _tabController;
  final Map<String, Map<String, dynamic>> _doctorsCache = {};

  String? _currentUid;
  Stream<List<QueryDocumentSnapshot>>? _upcomingStream;
  Stream<List<QueryDocumentSnapshot>>? _completedStream;
  Stream<List<QueryDocumentSnapshot>>? _cancelledStream;

  void _logDebug(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'AppointmentsTab');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).user;
    if (user != null && user.uid != _currentUid) {
      _currentUid = user.uid;
      _upcomingStream = _createAppointmentsStream(user.uid, [
        'waiting',
        'in-progress',
      ]);
      _completedStream = _createAppointmentsStream(user.uid, ['completed']);
      _cancelledStream = _createAppointmentsStream(user.uid, [
        'cancelled',
        'no-show',
      ]);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchDoctors(
    List<String> doctorIds,
  ) async {
    if (doctorIds.isEmpty) return {};
    try {
      final results = await Future.wait(
        doctorIds.map(
          (id) =>
              FirebaseFirestore.instance.collection('doctors').doc(id).get(),
        ),
      );
      return {
        for (var doc in results)
          if (doc.exists && doc.data() != null)
            doc.id: doc.data() as Map<String, dynamic>,
      };
    } catch (e) {
      _logDebug('Error fetching doctors batch: $e');
      return {};
    }
  }

  Stream<List<QueryDocumentSnapshot>> _createAppointmentsStream(
    String uid,
    List<String> statuses,
  ) {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .where('status', whereIn: statuses)
        .snapshots()
        .asyncMap((snapshot) async {
          final docs = snapshot.docs;
          final Set<String> doctorIdsToFetch = {};

          for (var doc in docs) {
            final data = doc.data();
            final docId = data['doctorId'] as String?;
            if (docId != null && !_doctorsCache.containsKey(docId)) {
              doctorIdsToFetch.add(docId);
            }
          }

          if (doctorIdsToFetch.isNotEmpty) {
            final newDoctors = await _fetchDoctors(doctorIdsToFetch.toList());
            _doctorsCache.addAll(newDoctors);
          }

          final sortedDocs = docs.toList();
          sortedDocs.sort((a, b) {
            final dataA = a.data();
            final dataB = b.data();

            final createdAtA = dataA['createdAt'];
            final createdAtB = dataB['createdAt'];

            if (createdAtA == null && createdAtB == null) return 0;
            if (createdAtA == null) return 1;
            if (createdAtB == null) return -1;

            if (createdAtA is Timestamp && createdAtB is Timestamp) {
              return createdAtB.compareTo(createdAtA); // descending
            }
            if (createdAtA is String && createdAtB is String) {
              return createdAtB.compareTo(createdAtA);
            }
            return createdAtB.toString().compareTo(createdAtA.toString());
          });

          return sortedDocs;
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Appointments',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.onPrimary,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.onPrimary,
          indicatorWeight: 3,
          labelColor: AppColors.onPrimary,
          unselectedLabelColor: AppColors.onPrimary.withValues(alpha: 0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AppointmentsListBuilder(
            stream: _upcomingStream,
            statuses: const ['waiting', 'in-progress'],
            emptyMsg: 'No upcoming appointments',
            emptyIcon: Icons.calendar_today,
            doctorsCache: _doctorsCache,
            shownPaymentConfirmations: _shownPaymentConfirmations,
            onCancel: cancelAppointment,
            onReschedule: rescheduleAppointment,
            onCompletePayment: completePayment,
          ),
          AppointmentsListBuilder(
            stream: _completedStream,
            statuses: const ['completed'],
            emptyMsg: 'No completed appointments',
            emptyIcon: Icons.check_circle_outline,
            doctorsCache: _doctorsCache,
            shownPaymentConfirmations: _shownPaymentConfirmations,
            onCancel: cancelAppointment,
            onReschedule: rescheduleAppointment,
            onCompletePayment: completePayment,
          ),
          AppointmentsListBuilder(
            stream: _cancelledStream,
            statuses: const ['cancelled', 'no-show'],
            emptyMsg: 'No cancelled appointments',
            emptyIcon: Icons.cancel_outlined,
            doctorsCache: _doctorsCache,
            shownPaymentConfirmations: _shownPaymentConfirmations,
            onCancel: cancelAppointment,
            onReschedule: rescheduleAppointment,
            onCompletePayment: completePayment,
          ),
        ],
      ),
    );
  }
}
