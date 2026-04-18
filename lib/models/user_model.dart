import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a User/Patient in Firestore
class UserModel {
  /// Unique identifier of the document
  final String id;

  /// Identifier for the patient
  final String patientId;

  /// Full name of the user
  final String name;

  /// Email address of the user
  final String email;

  /// Phone number of the user
  final String phone;

  /// Role of the user (e.g., patient, doctor, receptionist, admin)
  final String role;

  /// List of favorite doctor IDs
  final List<String> favoriteDoctors;

  /// Whether notifications are enabled for the user
  final bool notificationsEnabled;

  /// URL of the user's profile image
  final String? profileImageUrl;

  /// Timestamp when the user became a member
  final DateTime memberSince;

  /// Account status: active, pending, suspended, rejected
  final String accountStatus;

  const UserModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.favoriteDoctors = const [],
    required this.notificationsEnabled,
    this.profileImageUrl,
    required this.memberSince,
    required this.accountStatus,
  });

  /// Convert model to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'favoriteDoctors': favoriteDoctors,
    'notificationsEnabled': notificationsEnabled,
    'profileImageUrl': profileImageUrl,
    'memberSince': memberSince.toIso8601String(),
    'accountStatus': accountStatus,
  };

  /// Create model from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String? ?? '',
    patientId: json['patientId'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: json['role'] as String? ?? 'patient',
    favoriteDoctors:
        (json['favoriteDoctors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
    profileImageUrl: json['profileImageUrl'] as String?,
    memberSince: json['memberSince'] != null
        ? DateTime.parse(json['memberSince'] as String)
        : DateTime.now(),
    accountStatus: json['accountStatus'] as String? ?? 'active',
  );

  /// Convert model to Firestore format
  Map<String, dynamic> toFirestore() => {
    'patientId': patientId,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'favoriteDoctors': favoriteDoctors,
    'notificationsEnabled': notificationsEnabled,
    'profileImageUrl': profileImageUrl,
    'memberSince': Timestamp.fromDate(memberSince),
    'accountStatus': accountStatus,
  };
 
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return UserModel(
        id: doc.id,
        patientId: doc.id,
        name: '',
        email: '',
        phone: '',
        role: 'patient',
        favoriteDoctors: const [],
        notificationsEnabled: false,
        memberSince: DateTime.now(),
        accountStatus: 'active',
      );
    }

    return UserModel(
      id: doc.id,
      patientId: data['patientId'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: data['role'] as String? ?? 'patient',
      favoriteDoctors:
          (data['favoriteDoctors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? false,
      profileImageUrl: data['profileImageUrl'] as String?,
      memberSince: data['memberSince'] != null
          ? (data['memberSince'] as Timestamp).toDate()
          : DateTime.now(),
      accountStatus: data['accountStatus'] as String? ?? 'active',
    );
  }

  /// Create a copy with modified fields
  UserModel copyWith({
    String? id,
    String? patientId,
    String? name,
    String? email,
    String? phone,
    String? role,
    List<String>? favoriteDoctors,
    bool? notificationsEnabled,
    String? profileImageUrl,
    DateTime? memberSince,
    String? accountStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      favoriteDoctors: favoriteDoctors ?? this.favoriteDoctors,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      memberSince: memberSince ?? this.memberSince,
      accountStatus: accountStatus ?? this.accountStatus,
    );
  }
}
