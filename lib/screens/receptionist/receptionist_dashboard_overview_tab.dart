part of 'receptionist_dashboard.dart';

// =======================================
// TAB 1 - OVERVIEW
// =======================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<AuthProvider>().userName;
    final displayName = userName.isNotEmpty ? userName : 'Receptionist';
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediQueue Reception'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()}, $displayName',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's Stats
            _buildStatsGrid(todayStr),
            const SizedBox(height: 24),

            // Recent Check-Ins
            const Text(
              'Recent Check-Ins',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildRecentCheckIns(todayStr),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(String todayStr) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isEqualTo: todayStr)
          .snapshots(),
      builder: (context, snap) {
        int waiting = 0, inProgress = 0, completed = 0, total = 0;

        if (snap.hasData) {
          final docs = snap.data!.docs;
          total = docs.length;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? '';
            if (status == QueueAppointmentStatus.waiting) waiting++;
            if (status == QueueAppointmentStatus.inProgress) inProgress++;
            if (status == QueueAppointmentStatus.completed) completed++;
          }
        }

        final isLoading = snap.connectionState == ConnectionState.waiting;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              icon: Icons.hourglass_top,
              label: 'Waiting',
              value: isLoading ? '...' : '$waiting',
              color: AppColors.statusWaiting,
            ),
            _StatCard(
              icon: Icons.play_circle_outline,
              label: 'In Progress',
              value: isLoading ? '...' : '$inProgress',
              color: AppColors.statusInProgress,
            ),
            _StatCard(
              icon: Icons.check_circle_outline,
              label: 'Completed',
              value: isLoading ? '...' : '$completed',
              color: AppColors.statusCompleted,
            ),
            _StatCard(
              icon: Icons.calendar_today,
              label: 'Total Today',
              value: isLoading ? '...' : '$total',
              color: AppColors.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentCheckIns(String todayStr) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isEqualTo: todayStr)
          .where('checkedIn', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            message: 'Could not load recent check-ins',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final docs = List<QueryDocumentSnapshot>.from(
          snapshot.data?.docs ?? const [],
        );
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aStamp = _resolveCheckInStamp(aData);
          final bStamp = _resolveCheckInStamp(bData);

          if (aStamp == null && bStamp == null) return 0;
          if (aStamp == null) return 1;
          if (bStamp == null) return -1;
          return bStamp.compareTo(aStamp);
        });

        final recentDocs = docs.take(5).toList();
        if (recentDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.how_to_reg_outlined,
            message: 'No check-ins yet today',
          );
        }

        return Column(
          children: recentDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final patientName = data['patientName'] as String? ?? 'Unknown';
            final doctorName = data['doctorName'] as String? ?? 'Unknown';
            final ticket = AppFormatters.formatTicket(data['ticketNumber']);
            final timeSlot = data['timeSlot'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.how_to_reg,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _buildDoctorSubtitle(doctorName, timeSlot),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// =======================================
// TAB 2 - QUEUE MANAGEMENT
// =======================================
