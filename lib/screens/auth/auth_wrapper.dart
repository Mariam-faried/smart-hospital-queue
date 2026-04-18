import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_hospital_queue/utils/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';
import '../patient/patient_main_screen.dart';
import '../doctor/doctor_dashboard.dart';
import '../receptionist/receptionist_dashboard.dart';
import '../admin/admin_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.authError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.authError!),
                backgroundColor: AppColors.error,
              ),
            );
            authProvider.clearAuthError();
          });
        }

        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.user == null) {
          return const LoginScreen();
        }

        if (authProvider.userRole == 'patient' &&
            !(authProvider.user?.emailVerified ?? false)) {
          return const EmailVerificationScreen();
        }

        switch (authProvider.userRole) {
          case 'patient':
            return const PatientMainScreen();
          case 'doctor':
            return const DoctorDashboard();
          case 'receptionist':
            return const ReceptionistDashboard();
          case 'admin':
            return const AdminDashboard();
          default:
            return const Scaffold(
              body: Center(child: Text('Invalid Role or Role Not Found')),
            );
        }
      },
    );
  }
}
