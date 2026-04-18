import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../screens/patient/book_appointment_screen.dart';
import '../../screens/patient/doctor_search_screen.dart';
import 'categories_section.dart';

class HomeSearchBar extends StatefulWidget {
  final String searchQuery;
  final List<String> specializations;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;

  const HomeSearchBar({
    super.key,
    required this.searchQuery,
    required this.specializations,
    required this.onSearchChanged,
    required this.onClear,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void didUpdateWidget(HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        widget.onSearchChanged(value.trim());
      }
    });
  }

  void _showFilterBottomSheet() {
    final categories = widget.specializations.isNotEmpty
        ? widget.specializations
        : CategoriesSection.fallbackSpecializations;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;
    const estimatedHeaderAndPadding = 160.0;
    final estimatedHeight =
        estimatedHeaderAndPadding + (categories.length * 72);
    final sheetHeight = estimatedHeight.clamp(280.0, maxHeight).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground.withValues(alpha: 0),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Browse by Specialization',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final specialization = categories[index];
                        final categoryColor =
                            CategoriesSection.colorForSpecialization(
                              specialization,
                            );
                        final categoryIcon =
                            CategoriesSection.iconForSpecialization(
                              specialization,
                            );
                        return ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: categoryColor.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              categoryIcon,
                              color: categoryColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            specialization,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookAppointmentScreen(
                                  initialSpecialization: specialization,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorSearchScreen(initialQuery: value.trim()),
              ),
            );
            _searchController.clear();
            widget.onClear();
          }
        },
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search doctors by name or specialization...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    widget.onClear();
                  },
                ),
              Container(
                height: 30,
                width: 1,
                color: AppColors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
                onPressed: _showFilterBottomSheet,
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
