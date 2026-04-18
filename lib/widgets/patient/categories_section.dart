import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../screens/patient/book_appointment_screen.dart';

class CategoriesSection extends StatelessWidget {
  final Animation<double> categoriesFade;
  final Animation<Offset> categoriesSlide;
  final String searchQuery;
  final List<String> specializations;

  const CategoriesSection({
    super.key,
    required this.categoriesFade,
    required this.categoriesSlide,
    required this.searchQuery,
    required this.specializations,
  });

  static const List<String> fallbackSpecializations = [
    'General Medicine',
    'Cardiology',
    'Pediatrics',
    'Orthopedics',
    'Dermatology',
    'Neurology',
    'Ophthalmology',
    'Psychiatry',
  ];

  static const List<IconData> _fallbackIcons = [
    Icons.health_and_safety_rounded,
    Icons.medication_rounded,
    Icons.healing_rounded,
    Icons.science_rounded,
    Icons.emergency_rounded,
  ];

  static const List<Color> _fallbackColors = [
    Color(0xFF1E7C72),
    Color(0xFF8D5DA7),
    Color(0xFF3B82A0),
    Color(0xFFB26A2F),
    Color(0xFF64748B),
  ];

  static int _fallbackIndex(String value, int length) {
    final safeLength = length <= 0 ? 1 : length;
    return value.hashCode.abs() % safeLength;
  }

  static IconData iconForSpecialization(String specialization) {
    final lower = specialization.toLowerCase();
    if (lower.contains('general')) return Icons.local_hospital_rounded;
    if (lower.contains('cardio')) return Icons.favorite_rounded;
    if (lower.contains('pedia')) return Icons.child_care_rounded;
    if (lower.contains('endo') || lower.contains('diabet')) {
      return Icons.monitor_heart_rounded;
    }
    if (lower.contains('ortho') || lower.contains('bone')) {
      return Icons.accessibility_new_rounded;
    }
    if (lower.contains('derma') || lower.contains('skin')) return Icons.face;
    if (lower.contains('neuro') || lower.contains('brain')) {
      return Icons.psychology_rounded;
    }
    if (lower.contains('ophthal') || lower.contains('eye')) {
      return Icons.visibility_rounded;
    }
    if (lower.contains('psych')) return Icons.self_improvement_rounded;
    if (lower.contains('ent') || lower.contains('ear')) return Icons.hearing;
    if (lower.contains('dental') || lower.contains('dent')) {
      return Icons.medical_services_rounded;
    }
    if (lower.contains('gyn') || lower.contains('obstetric')) {
      return Icons.pregnant_woman;
    }
    return _fallbackIcons[_fallbackIndex(lower, _fallbackIcons.length)];
  }

  static Color colorForSpecialization(String specialization) {
    final lower = specialization.toLowerCase();
    if (lower.contains('general')) return const Color(0xFF0D8A6A);
    if (lower.contains('cardio')) return const Color(0xFFC63B58);
    if (lower.contains('pedia')) return const Color(0xFF2E7AB8);
    if (lower.contains('endo') || lower.contains('diabet')) {
      return const Color(0xFFA26700);
    }
    if (lower.contains('ortho') || lower.contains('bone')) {
      return const Color(0xFF7A5FCE);
    }
    if (lower.contains('derma') || lower.contains('skin')) {
      return const Color(0xFFCF8A2F);
    }
    if (lower.contains('neuro') || lower.contains('brain')) {
      return const Color(0xFF4E63B6);
    }
    if (lower.contains('ophthal') || lower.contains('eye')) {
      return const Color(0xFF0F8F83);
    }
    if (lower.contains('psych')) return const Color(0xFF6A7B2F);
    if (lower.contains('ent') || lower.contains('ear')) {
      return const Color(0xFF9C6B3A);
    }
    if (lower.contains('gyn') || lower.contains('obstetric')) {
      return const Color(0xFFB35D82);
    }
    return _fallbackColors[_fallbackIndex(lower, _fallbackColors.length)];
  }

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final categories = specializations.isNotEmpty
        ? specializations
        : fallbackSpecializations;

    return FadeTransition(
      opacity: categoriesFade,
      child: SlideTransition(
        position: categoriesSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.category, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookAppointmentScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88, maxHeight: 140),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final specialization = categories[index];
                  final icon = iconForSpecialization(specialization);
                  final color = colorForSpecialization(specialization);
                  final labelLength = specialization.trim().length;
                  final tileWidth = labelLength >= 20
                      ? 126.0
                      : labelLength >= 14
                      ? 112.0
                      : 100.0;

                  return SizedBox(
                    width: tileWidth,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookAppointmentScreen(
                              initialSpecialization: specialization,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(32),
                      splashColor: color.withValues(alpha: 0.16),
                      highlightColor: color.withValues(alpha: 0.08),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.withValues(alpha: 0.28),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: tileWidth,
                            height: 36,
                            child: Text(
                              specialization,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
