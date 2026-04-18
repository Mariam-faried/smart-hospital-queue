import 'dart:io';

void main() {
  final files = [
    'lib/screens/admin/admin_dashboard.dart',
    'lib/screens/admin/add_doctor_screen.dart',
    'lib/screens/admin/add_receptionist_screen.dart',
    'lib/screens/admin/edit_doctor_screen.dart',
    'lib/screens/patient/book_appointment_screen.dart',
    'lib/screens/patient/doctor_profile_screen.dart',
    'lib/screens/patient/appointments_tab.dart',
    'lib/screens/patient/queue_tab.dart',
    'lib/screens/patient/profile_tab.dart'
  ];

  for (final path in files) {
    var file = File(path);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();
    
    if (path == 'lib/screens/admin/admin_dashboard.dart') {
      content = content.replaceAll('Colors.black.withValues(alpha: 0.05)', 'AppColors.textPrimary.withValues(alpha: 0.06)');
      content = content.replaceAll('Colors.black.withValues(alpha: 0.04)', 'AppColors.textPrimary.withValues(alpha: 0.05)');
    } else {
      content = content.replaceAll('Colors.black.withValues', 'AppColors.textPrimary.withValues');
    }
    
    file.writeAsStringSync(content);
  }
}
