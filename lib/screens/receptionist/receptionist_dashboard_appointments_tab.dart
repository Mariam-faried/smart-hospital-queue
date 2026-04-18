part of 'receptionist_dashboard.dart';

// =======================================
// TAB 3 - APPOINTMENTS
// =======================================

class _AppointmentsTab extends StatefulWidget {
  const _AppointmentsTab();

  @override
  State<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<_AppointmentsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Appointments'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
              style: const TextStyle(color: AppColors.onPrimary),
              decoration: InputDecoration(
                hintText: 'Search by patient name or ticket...',
                hintStyle: TextStyle(
                  color: AppColors.onPrimary.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.onPrimary.withValues(alpha: 0.6),
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppColors.onPrimary.withValues(alpha: 0.8),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.onPrimary.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Filter Chips
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    value: 'all',
                    selected: _statusFilter,
                    onTap: (v) => setState(() => _statusFilter = v),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Waiting',
                    value: QueueAppointmentStatus.waiting,
                    selected: _statusFilter,
                    onTap: (v) => setState(() => _statusFilter = v),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'In Progress',
                    value: QueueAppointmentStatus.inProgress,
                    selected: _statusFilter,
                    onTap: (v) => setState(() => _statusFilter = v),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Completed',
                    value: QueueAppointmentStatus.completed,
                    selected: _statusFilter,
                    onTap: (v) => setState(() => _statusFilter = v),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Cancelled',
                    value: QueueAppointmentStatus.cancelled,
                    selected: _statusFilter,
                    onTap: (v) => setState(() => _statusFilter = v),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'No Show',
                    value: QueueAppointmentStatus.noShow,
                    selected: _statusFilter,
                    onTap: (v) => setState(() => _statusFilter = v),
                  ),
                ],
              ),
            ),
          ),

          // Appointments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('date', isEqualTo: todayStr)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildEmptyState(
                    icon: Icons.error_outline,
                    message: 'Could not load appointments',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                var appointments = List<QueryDocumentSnapshot>.from(
                  snapshot.data?.docs ?? const [],
                );

                // Sort by createdAt descending
                appointments.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = _resolveCreatedAtStamp(aData);
                  final bTime = _resolveCreatedAtStamp(bData);
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                // Filter by status
                if (_statusFilter != 'all') {
                  appointments = appointments.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['status'] as String? ?? '') == _statusFilter;
                  }).toList();
                }

                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  appointments = appointments.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['patientName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final ticket = AppFormatters.formatTicket(
                      data['ticketNumber'],
                    ).toLowerCase();
                    final doctorName = (data['doctorName'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        ticket.contains(_searchQuery) ||
                        doctorName.contains(_searchQuery);
                  }).toList();
                }

                if (appointments.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.event_busy_outlined,
                    message: _statusFilter == 'all'
                        ? 'No appointments found'
                        : 'No ${_formatStatusLabel(_statusFilter).toLowerCase()} appointments',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final doc = appointments[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _AppointmentCard(data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================
// SHARED WIDGETS
// =======================================
