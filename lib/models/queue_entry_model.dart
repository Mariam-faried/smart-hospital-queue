import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/formatters.dart';

int _queueTicketAsInt(dynamic raw, {int fallback = 0}) {
  return AppFormatters.parseTicketNumber(raw, fallback: fallback);
}

/// Model representing a Queue Entry in Firestore
class QueueEntryModel {
  // Core fields
  final String id;
  final String appointmentId;
  final String doctorId;
  final int ticketNumber;
  final String patientName;

  // Queue status
  final int position;
  final String status; // "waiting"/"called"/"in-progress"/"completed"/"no-show"
  final int estimatedWaitTime;
  final String date;

  // Timestamps
  final DateTime checkInTime;
  final DateTime? calledAt;

  const QueueEntryModel({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.ticketNumber,
    required this.patientName,
    required this.position,
    required this.status,
    required this.estimatedWaitTime,
    required this.date,
    required this.checkInTime,
    this.calledAt,
  });

  /// True if the entry is active
  bool get isActive => status == 'waiting' || status == 'called';

  /// Returns the formatted wait time
  String get formattedWaitTime =>
      AppFormatters.formatWaitTime(estimatedWaitTime);

  /// Convert model to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'appointmentId': appointmentId,
    'doctorId': doctorId,
    'ticketNumber': ticketNumber,
    'patientName': patientName,
    'position': position,
    'status': status,
    'estimatedWaitTime': estimatedWaitTime,
    'date': date,
    'checkInTime': checkInTime.toIso8601String(),
    'calledAt': calledAt?.toIso8601String(),
  };

  /// Create model from JSON
  factory QueueEntryModel.fromJson(Map<String, dynamic> json) =>
      QueueEntryModel(
        id: json['id'] as String? ?? '',
        appointmentId: json['appointmentId'] as String? ?? '',
        doctorId: json['doctorId'] as String? ?? '',
        ticketNumber: _queueTicketAsInt(json['ticketNumber']),
        patientName: json['patientName'] as String? ?? '',
        position: json['position'] as int? ?? 0,
        status: json['status'] as String? ?? 'waiting',
        estimatedWaitTime: json['estimatedWaitTime'] as int? ?? 0,
        date: json['date'] as String? ?? '',
        checkInTime: json['checkInTime'] != null
            ? DateTime.parse(json['checkInTime'] as String)
            : DateTime.now(),
        calledAt: json['calledAt'] != null
            ? DateTime.parse(json['calledAt'] as String)
            : null,
      );

  /// Convert model to Firestore format
  Map<String, dynamic> toFirestore() => {
    'appointmentId': appointmentId,
    'doctorId': doctorId,
    'ticketNumber': ticketNumber,
    'patientName': patientName,
    'position': position,
    'status': status,
    'estimatedWaitTime': estimatedWaitTime,
    'date': date,
    'checkInTime': Timestamp.fromDate(checkInTime),
    'calledAt': calledAt != null ? Timestamp.fromDate(calledAt!) : null,
  };

  /// Create model from Firestore document
  factory QueueEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return QueueEntryModel(
        id: doc.id,
        appointmentId: '',
        doctorId: '',
        ticketNumber: 0,
        patientName: '',
        position: 0,
        status: 'waiting',
        estimatedWaitTime: 0,
        date: '',
        checkInTime: DateTime.now(),
      );
    }

    return QueueEntryModel(
      id: doc.id,
      appointmentId: data['appointmentId'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      ticketNumber: _queueTicketAsInt(data['ticketNumber']),
      patientName: data['patientName'] as String? ?? '',
      position: data['position'] as int? ?? 0,
      status: data['status'] as String? ?? 'waiting',
      estimatedWaitTime: data['estimatedWaitTime'] as int? ?? 0,
      date: data['date'] as String? ?? '',
      checkInTime: data['checkInTime'] != null
          ? (data['checkInTime'] as Timestamp).toDate()
          : DateTime.now(),
      calledAt: data['calledAt'] != null
          ? (data['calledAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create a copy with modified fields
  QueueEntryModel copyWith({
    String? id,
    String? appointmentId,
    String? doctorId,
    int? ticketNumber,
    String? patientName,
    int? position,
    String? status,
    int? estimatedWaitTime,
    String? date,
    DateTime? checkInTime,
    DateTime? calledAt,
  }) {
    return QueueEntryModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      doctorId: doctorId ?? this.doctorId,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      patientName: patientName ?? this.patientName,
      position: position ?? this.position,
      status: status ?? this.status,
      estimatedWaitTime: estimatedWaitTime ?? this.estimatedWaitTime,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      calledAt: calledAt ?? this.calledAt,
    );
  }
}
