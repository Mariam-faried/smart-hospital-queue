import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a Doctor in Firestore
class DoctorModel {
  // Core fields
  final String id;
  final String name;
  final String specialization;
  final String qualification;
  final int experience;

  // Rating and reviews
  final double rating;
  final int totalReviews;

  // Schedule and status
  final Map<String, dynamic> workingHours;
  final List<String> workingDays;
  final bool isAvailable;
  final String currentState;

  // Details
  final double consultationFee;
  final String? profileImageUrl;
  final List<String> languages;
  final String about;

  // Approval fields
  final String accountStatus; // 'pending', 'approved', 'rejected'
  final DateTime? approvedAt;
  final String? approvedBy; // Admin user ID

  const DoctorModel({
    required this.id,
    required this.name,
    required this.specialization,
    required this.qualification,
    required this.experience,
    required this.rating,
    required this.totalReviews,
    required this.workingHours,
    required this.workingDays,
    required this.isAvailable,
    required this.currentState,
    required this.consultationFee,
    this.profileImageUrl,
    required this.languages,
    required this.about,
    required this.accountStatus,
    this.approvedAt,
    this.approvedBy,
  });

  /// True if the doctor is available and current state is 'available'
  bool get isAvailableNow => isAvailable && currentState == 'available';

  /// Formatted consultation fee
  String get formattedFee => '${consultationFee.toInt()} EGP';

  /// Convert model to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'specialization': specialization,
    'qualification': qualification,
    'experience': experience,
    'rating': rating,
    'totalReviews': totalReviews,
    'workingHours': workingHours,
    'workingDays': workingDays,
    'isAvailable': isAvailable,
    'currentState': currentState,
    'consultationFee': consultationFee,
    'profileImageUrl': profileImageUrl,
    'languages': languages,
    'about': about,
    'accountStatus': accountStatus,
    'approvedAt': approvedAt?.toIso8601String(),
    'approvedBy': approvedBy,
  };

  /// Create model from JSON
  factory DoctorModel.fromJson(Map<String, dynamic> json) => DoctorModel(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    specialization: json['specialization'] as String? ?? '',
    qualification: json['qualification'] as String? ?? '',
    experience: json['experience'] as int? ?? 0,
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    totalReviews: json['totalReviews'] as int? ?? 0,
    workingHours:
        json['workingHours'] as Map<String, dynamic>? ?? <String, dynamic>{},
    workingDays:
        (json['workingDays'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    isAvailable: json['isAvailable'] as bool? ?? false,
    currentState: json['currentState'] as String? ?? 'offline',
    consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 0.0,
    profileImageUrl: json['profileImageUrl'] as String?,
    languages:
        (json['languages'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    about: json['about'] as String? ?? '',
    accountStatus: json['accountStatus'] as String? ?? 'pending',
    approvedAt: json['approvedAt'] != null
        ? DateTime.parse(json['approvedAt'] as String)
        : null,
    approvedBy: json['approvedBy'] as String?,
  );

  /// Convert model to Firestore format
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'specialization': specialization,
    'qualification': qualification,
    'experience': experience,
    'rating': rating,
    'totalReviews': totalReviews,
    'workingHours': workingHours,
    'workingDays': workingDays,
    'isAvailable': isAvailable,
    'currentState': currentState,
    'consultationFee': consultationFee,
    'profileImageUrl': profileImageUrl,
    'languages': languages,
    'about': about,
    'accountStatus': accountStatus,
    'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    'approvedBy': approvedBy,
  };

  /// Create model from Firestore document
  factory DoctorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return DoctorModel(
        id: doc.id,
        name: '',
        specialization: '',
        qualification: '',
        experience: 0,
        rating: 0.0,
        totalReviews: 0,
        workingHours: const <String, dynamic>{},
        workingDays: const [],
        isAvailable: false,
        currentState: 'offline',
        consultationFee: 0.0,
        languages: const [],
        about: '',
        accountStatus: 'pending',
      );
    }

    return DoctorModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      specialization: data['specialization'] as String? ?? '',
      qualification: data['qualification'] as String? ?? '',
      experience: data['experience'] as int? ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: data['totalReviews'] as int? ?? 0,
      workingHours:
          data['workingHours'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      workingDays:
          (data['workingDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isAvailable: data['isAvailable'] as bool? ?? false,
      currentState: data['currentState'] as String? ?? 'offline',
      consultationFee: (data['consultationFee'] as num?)?.toDouble() ?? 0.0,
      profileImageUrl: data['profileImageUrl'] as String?,
      languages:
          (data['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      about: data['about'] as String? ?? '',
      accountStatus: data['accountStatus'] as String? ?? 'pending',
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'] as String?,
    );
  }

  /// Create a copy with modified fields
  DoctorModel copyWith({
    String? id,
    String? name,
    String? specialization,
    String? qualification,
    int? experience,
    double? rating,
    int? totalReviews,
    Map<String, dynamic>? workingHours,
    List<String>? workingDays,
    bool? isAvailable,
    String? currentState,
    double? consultationFee,
    String? profileImageUrl,
    List<String>? languages,
    String? about,
    String? accountStatus,
    DateTime? approvedAt,
    String? approvedBy,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      qualification: qualification ?? this.qualification,
      experience: experience ?? this.experience,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      workingHours: workingHours ?? this.workingHours,
      workingDays: workingDays ?? this.workingDays,
      isAvailable: isAvailable ?? this.isAvailable,
      currentState: currentState ?? this.currentState,
      consultationFee: consultationFee ?? this.consultationFee,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      languages: languages ?? this.languages,
      about: about ?? this.about,
      accountStatus: accountStatus ?? this.accountStatus,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }
}
