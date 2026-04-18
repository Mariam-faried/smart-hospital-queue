import 'package:flutter/material.dart';
import 'admin_dashboard.dart';

/// This screen now redirects to AdminDashboard.
/// All user management is handled inside the dashboard tabs.
class AdminUserManagementScreen extends StatelessWidget {
  const AdminUserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboard();
  }
}
