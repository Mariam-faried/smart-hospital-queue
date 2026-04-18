import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/queue_provider.dart';
import '../../utils/app_colors.dart';

// Import doctor-specific widgets
import '../../widgets/doctor/doctor_header.dart';
import '../../widgets/doctor/doctor_date_selector.dart';
import '../../widgets/doctor/doctor_statistics_section.dart';
import '../../widgets/doctor/doctor_queue_overview.dart';
import '../../widgets/doctor/doctor_appointments_list.dart';
import '../../widgets/doctor/doctor_availability_toggle.dart';
import '../../widgets/doctor/call_next_patient_fab.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  DateTime _selectedDate = DateTime.now();
  String _statusFilter = 'all'; // all, waiting, confirmed, completed, cancelled

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final doctorId = authProvider.user?.uid;

    if (doctorId != null) {
      // Listen to doctor's appointments
      context.read<AppointmentProvider>().listenToDoctorAppointments(doctorId);

      // Listen to doctor's queue for selected date
      context.read<QueueProvider>().listenToDoctorQueue(
        doctorId,
        _selectedDate,
      );
    }
  }

  Future<void> _refreshData() async {
    _initializeData();
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final doctorId = authProvider.user?.uid;
    if (doctorId != null) {
      context.read<QueueProvider>().listenToDoctorQueue(doctorId, newDate);
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _statusFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: [
          // Availability toggle in AppBar
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return DoctorAvailabilityToggle(
                doctorId: authProvider.user?.uid ?? '',
              );
            },
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.onError,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                context.read<AuthProvider>().signOut();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor header with name and specialization
              const DoctorHeader(),

              // Date selector
              DoctorDateSelector(
                selectedDate: _selectedDate,
                onDateChanged: _onDateChanged,
              ),

              // Statistics cards
              DoctorStatisticsSection(selectedDate: _selectedDate),

              // Queue overview
              DoctorQueueOverview(selectedDate: _selectedDate),

              // Appointments list
              DoctorAppointmentsList(
                selectedDate: _selectedDate,
                statusFilter: _statusFilter,
                onFilterChanged: _onFilterChanged,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: CallNextPatientFab(selectedDate: _selectedDate),
    );
  }
}
