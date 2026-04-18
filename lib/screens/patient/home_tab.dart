import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import 'book_appointment_screen.dart';

import '../../widgets/patient/greeting_header.dart';
import '../../widgets/patient/upcoming_appointment_banner.dart';
import '../../widgets/patient/categories_section.dart';
import '../../widgets/patient/top_doctors_section.dart';
import '../../widgets/patient/doctor_search_results.dart';
import '../../widgets/patient/home_search_bar.dart';
import 'notifications_screen.dart';
import 'doctor_search_screen.dart';

class HomeTab extends StatefulWidget {
  final void Function(int)? onSwitchTab;

  const HomeTab({super.key, this.onSwitchTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  String _searchQuery = '';
  late final AnimationController _categoriesAnimController;
  late final AnimationController _doctorsAnimController;
  late final AnimationController _bannerAnimController;
  late final Animation<double> _categoriesFade;
  late final Animation<Offset> _categoriesSlide;
  late final Animation<double> _doctorsFade;
  late final Animation<Offset> _doctorsSlide;
  late final Animation<double> _bannerFade;
  late final Animation<Offset> _bannerSlide;
  late Stream<QuerySnapshot> _doctorsStream;
  late Stream<QuerySnapshot> _rankedDoctorsStream;

  Stream<QuerySnapshot> _createDoctorsStream() {
    return FirebaseFirestore.instance.collection('doctors').snapshots();
  }

  Stream<QuerySnapshot> _createRankedDoctorsStream() {
    return FirebaseFirestore.instance
        .collection('doctors')
        .orderBy('rating', descending: true)
        .limit(6)
        .snapshots();
  }

  AnimationController _createAnim() => AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Animation<double> _createFade(AnimationController c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut);
  Animation<Offset> _createSlide(AnimationController c) => Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _doctorsStream = _createDoctorsStream();
    _rankedDoctorsStream = _createRankedDoctorsStream();

    _bannerAnimController = _createAnim();
    _bannerFade = _createFade(_bannerAnimController);
    _bannerSlide = _createSlide(_bannerAnimController);

    _categoriesAnimController = _createAnim();
    _categoriesFade = _createFade(_categoriesAnimController);
    _categoriesSlide = _createSlide(_categoriesAnimController);

    _doctorsAnimController = _createAnim();
    _doctorsFade = _createFade(_doctorsAnimController);
    _doctorsSlide = _createSlide(_doctorsAnimController);

    _runEntranceAnimations();
  }

  void _runEntranceAnimations() {
    _bannerAnimController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _categoriesAnimController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _doctorsAnimController.forward();
    });
  }

  void _retryDoctorsLoad() {
    setState(() {
      _doctorsStream = _createDoctorsStream();
      _rankedDoctorsStream = _createRankedDoctorsStream();
    });
  }

  @override
  void dispose() {
    _bannerAnimController.dispose();
    _categoriesAnimController.dispose();
    _doctorsAnimController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _doctorsStream = _createDoctorsStream();
      _rankedDoctorsStream = _createRankedDoctorsStream();
    });
    _bannerAnimController.reset();
    _categoriesAnimController.reset();
    _doctorsAnimController.reset();
    _runEntranceAnimations();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) return const Center(child: CircularProgressIndicator());
    final bottomSpacing = 108 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            GreetingHeader(
              uid: user.uid,
              onNotificationsPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(
                      uid: user.uid,
                      onSwitchTab: widget.onSwitchTab,
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _doctorsStream,
                      builder: (context, snapshot) {
                        final isLoading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final docs = snapshot.data?.docs ?? [];
                        final specializations = _extractSpecializations(docs);
                        final hasDoctorsError = snapshot.hasError;
                        final doctorsError = _formatDoctorsError(
                          snapshot.error,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HomeSearchBar(
                              searchQuery: _searchQuery,
                              specializations: specializations,
                              onSearchChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                              onClear: () {
                                setState(() => _searchQuery = '');
                              },
                            ),
                            const SizedBox(height: 20),
                            UpcomingAppointmentBanner(
                              uid: user.uid,
                              bannerFade: _bannerFade,
                              bannerSlide: _bannerSlide,
                            ),
                            CategoriesSection(
                              categoriesFade: _categoriesFade,
                              categoriesSlide: _categoriesSlide,
                              searchQuery: _searchQuery,
                              specializations: specializations,
                            ),
                            const SizedBox(height: 20),
                            if (hasDoctorsError)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.error.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.error_outline,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Unable to load doctors right now.',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            doctorsError,
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: _retryDoctorsLoad,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Retry'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_searchQuery.isNotEmpty)
                              DoctorSearchResults(
                                docs: docs,
                                isLoading: isLoading,
                                searchQuery: _searchQuery,
                                onOpenFullResults: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DoctorSearchScreen(
                                        initialQuery: _searchQuery,
                                      ),
                                    ),
                                  );
                                },
                              )
                            else
                              StreamBuilder<QuerySnapshot>(
                                stream: _rankedDoctorsStream,
                                builder: (context, rankedSnapshot) {
                                  final rankedDocs =
                                      rankedSnapshot.data?.docs ?? const [];
                                  final useServerRanking = rankedDocs.isNotEmpty;
                                  final visibleDocs =
                                      useServerRanking ? rankedDocs : docs;
                                  return TopDoctorsSection(
                                    docs: visibleDocs,
                                    isLoading: isLoading && visibleDocs.isEmpty,
                                    doctorsFade: _doctorsFade,
                                    doctorsSlide: _doctorsSlide,
                                    isServerRanked: useServerRanking,
                                  );
                                },
                              ),
                            SizedBox(height: bottomSpacing),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.cardBackground,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: const Text(
            'Book New Appointment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  String _formatDoctorsError(Object? error) {
    if (error is FirebaseException) {
      final code = error.code.trim().isEmpty ? 'firebase-error' : error.code;
      final message = (error.message ?? '').trim();
      return message.isEmpty ? code : '$code: $message';
    }
    return 'Please pull to refresh and try again.';
  }

  List<String> _extractSpecializations(List<QueryDocumentSnapshot> docs) {
    final uniqueByLower = <String, String>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final rawSpecialization = data['specialization'];
      final specialization = rawSpecialization is String
          ? rawSpecialization.trim()
          : rawSpecialization?.toString().trim() ?? '';
      if (specialization.isEmpty) continue;
      uniqueByLower.putIfAbsent(
        specialization.toLowerCase(),
        () => specialization,
      );
    }
    final values = uniqueByLower.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }
}
