import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';

class AddDoctorScreen extends StatefulWidget {
  const AddDoctorScreen({super.key});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _aboutController = TextEditingController();
  final _feeController = TextEditingController();
  final _avgTimeController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedSpecialization;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final List<String> _specializations = [
    'General Medicine',
    'Cardiology',
    'Pediatrics',
    'Orthopedics',
    'Dermatology',
    'Ophthalmology',
    'Psychiatry & Mental Health',
    'Neurology',
    'Gynecology & Obstetrics',
    'ENT',
    'Dentistry',
    'Urology',
    'Endocrinology',
    'Oncology',
  ];

  final List<String> _allDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final List<String> _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu'];

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _aboutController.dispose();
    _feeController.dispose();
    _avgTimeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveDoctor() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecialization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specialization.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one working day.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    UserCredential? userCredential;

    try {
      // 1. Create Firebase Auth account
      userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final uid = userCredential.user!.uid;

      // 2. Write to users/{uid}
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'patientId': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'doctor',
        'accountStatus': 'active',
        'notificationsEnabled': true,
        'memberSince': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'favoriteDoctors': [],
      });

      // 3. Write to doctors/{uid}
      final startTimeStr = _formatTimeOfDay(_startTime);
      final endTimeStr = _formatTimeOfDay(_endTime);

      await FirebaseFirestore.instance.collection('doctors').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'specialization': _selectedSpecialization,
        'qualification': _qualificationController.text.trim(),
        'experience': int.parse(_experienceController.text.trim()),
        'about': _aboutController.text.trim(),
        'consultationFee': int.parse(_feeController.text.trim()),
        'currency': 'EGP',
        'avgConsultationTime': int.parse(_avgTimeController.text.trim()),
        'imageUrl': '',
        'rating': 0.0,
        'totalReviews': 0,
        'isAvailable': true,
        'currentState': 'available',
        'accountStatus': 'active',
        'workingDays': _selectedDays.join(', '),
        'workingHours': '$startTimeStr - $endTimeStr',
        'languages': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor added successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Could not create account. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } catch (_) {
      // Rollback: delete Auth account if Firestore write failed
      try {
        await userCredential?.user?.delete();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not add doctor. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Doctor'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Personal Information ──
                    _buildSectionHeader(
                      'Personal Information',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            'Full Name',
                            Icons.person_outline,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Please enter full name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            'Email',
                            Icons.email_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter email';
                            }
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(v.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            'Phone Number',
                            Icons.phone_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter phone number';
                            }
                            if (!RegExp(
                              r'^\+?[0-9]*$',
                            ).hasMatch(v.trim().replaceAll(' ', ''))) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Doctor Information ──
                    _buildSectionHeader(
                      'Doctor Information',
                      Icons.medical_services_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSpecialization,
                          decoration: _inputDecoration(
                            'Specialization',
                            Icons.local_hospital_outlined,
                          ),
                          items: _specializations
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedSpecialization = v),
                          validator: (v) =>
                              v == null ? 'Please select specialization' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _qualificationController,
                          decoration: _inputDecoration(
                            'Qualification (e.g. MD, FACS)',
                            Icons.school_outlined,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Please enter qualification'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            'Years of Experience',
                            Icons.work_outline,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter years of experience';
                            }
                            final val = int.tryParse(v.trim());
                            if (val == null || val < 0) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _aboutController,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            'About / Bio (optional)',
                            Icons.info_outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _feeController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            'Consultation Fee (EGP)',
                            Icons.payments_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter fee';
                            }
                            final val = int.tryParse(v.trim());
                            if (val == null) return 'Enter a valid amount';
                            if (val <= 0) return 'Fee must be greater than 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _avgTimeController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            'Avg Consultation Time (minutes)',
                            Icons.timer_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter time';
                            }
                            final val = int.tryParse(v.trim());
                            if (val == null) return 'Enter a valid number';
                            if (val <= 0) return 'Time must be greater than 0';
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Schedule ──
                    _buildSectionHeader(
                      'Schedule',
                      Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        const Text(
                          'Working Days',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allDays.map((day) {
                            final isSelected = _selectedDays.contains(day);
                            return FilterChip(
                              label: Text(day),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDays.add(day);
                                  } else {
                                    _selectedDays.remove(day);
                                  }
                                });
                              },
                              selectedColor: AppColors.primary,
                              checkmarkColor: AppColors.onPrimary,
                              backgroundColor: AppColors.surfaceGrey,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.access_time,
                            color: AppColors.primary,
                          ),
                          title: const Text('Start Time'),
                          trailing: Text(
                            _formatTimeOfDay(_startTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onTap: () => _pickTime(isStart: true),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.access_time,
                            color: AppColors.primary,
                          ),
                          title: const Text('End Time'),
                          trailing: Text(
                            _formatTimeOfDay(_endTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Account ──
                    _buildSectionHeader('Account', Icons.lock_outline),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration:
                              _inputDecoration(
                                'Temporary Password',
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter password';
                            }
                            if (v.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Save Button ──
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveDoctor,
                        icon: _isLoading
                            ? const SizedBox.shrink()
                            : const Icon(Icons.person_add),
                        label: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Add Doctor',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: AppColors.textPrimary.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.surfaceGrey,
    );
  }
}
