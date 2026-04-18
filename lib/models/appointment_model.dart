import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/formatters.dart';

int _ticketAsInt(dynamic raw, {int fallback = 0}) {
  return AppFormatters.parseTicketNumber(raw, fallback: fallback);
}

DateTime _dateAsDateTime(dynamic raw, {DateTime? fallback}) {
  final defaultValue = fallback ?? DateTime.now();
  if (raw == null) return defaultValue;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed != null) return parsed;
  }
  return defaultValue;
}

String _dateAsYmd(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Model representing an Appointment in Firestore
class AppointmentModel {
  // Core identifiers
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialization;

  // Appointment details
  final DateTime date;
  final String timeSlot;
  final String
  status; // waiting/confirmed/in-progress/completed/cancelled/no-show
  final String
  paymentStatus; // pay_at_hospital/paid/free/(legacy values possible)
  final String priority; // "normal"/"urgent"/"emergency"
  final int ticketNumber;
  final int patientsAhead;
  final int estimatedWaitTime;

  // Fees
  final double totalFee;
  final double consultationFee;
  final double priorityFee;

  final String qrCode;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? checkInTime;
  final DateTime? completedAt;

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialization,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.paymentStatus,
    required this.priority,
    required this.ticketNumber,
    required this.patientsAhead,
    required this.estimatedWaitTime,
    required this.totalFee,
    required this.consultationFee,
    required this.priorityFee,
    required this.qrCode,
    required this.createdAt,
    required this.updatedAt,
    this.checkInTime,
    this.completedAt,
  });

  String _normalizedStatus() =>
      status.trim().toLowerCase().replaceAll('_', '-');

  String _normalizedPaymentStatus() => paymentStatus.trim().toLowerCase();

  /// True if the appointment is upcoming
  bool get isUpcoming =>
      _normalizedStatus() == 'waiting' ||
      _normalizedStatus() == 'confirmed' ||
      _normalizedStatus() == 'in-progress';

  /// True if the appointment is completed
  bool get isCompleted => status == 'completed';

  /// True if the appointment is cancelled
  bool get isCancelled =>
      _normalizedStatus() == 'cancelled' || _normalizedStatus() == 'no-show';

  /// True if the payment is settled
  bool get isPaid =>
      _normalizedPaymentStatus() == 'paid' ||
      _normalizedPaymentStatus() == 'free';

  /// Returns the formatted ticket number
  String get formattedTicketNumber => AppFormatters.formatTicket(ticketNumber);

  /// Convert model to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'patientName': patientName,
    'doctorId': doctorId,
    'doctorName': doctorName,
    'doctorSpecialization': doctorSpecialization,
    'date': date.toIso8601String(),
    'timeSlot': timeSlot,
    'status': status,
    'paymentStatus': paymentStatus,
    'priority': priority,
    'ticketNumber': ticketNumber,
    'patientsAhead': patientsAhead,
    'estimatedWaitTime': estimatedWaitTime,
    'totalFee': totalFee,
    'consultationFee': consultationFee,
    'priorityFee': priorityFee,
    'qrCode': qrCode,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'checkInTime': checkInTime?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  /// Create model from JSON
  factory AppointmentModel.fromJson(Map<String, dynamic> json) =>
      AppointmentModel(
        id: json['id'] as String? ?? '',
        patientId: json['patientId'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        doctorId: json['doctorId'] as String? ?? '',
        doctorName: json['doctorName'] as String? ?? '',
        doctorSpecialization: json['doctorSpecialization'] as String? ?? '',
        date: _dateAsDateTime(json['date']),
        timeSlot: json['timeSlot'] as String? ?? '',
        status: json['status'] as String? ?? 'waiting',
        paymentStatus: json['paymentStatus'] as String? ?? 'pay_at_hospital',
        priority: json['priority'] as String? ?? 'normal',
        ticketNumber: _ticketAsInt(json['ticketNumber']),
        patientsAhead: json['patientsAhead'] as int? ?? 0,
        estimatedWaitTime: json['estimatedWaitTime'] as int? ?? 0,
        totalFee: (json['totalFee'] as num?)?.toDouble() ?? 0.0,
        consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 0.0,
        priorityFee: (json['priorityFee'] as num?)?.toDouble() ?? 0.0,
        qrCode: json['qrCode'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        checkInTime: json['checkInTime'] != null
            ? DateTime.parse(json['checkInTime'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  /// Convert model to Firestore format
  Map<String, dynamic> toFirestore() => {
    'patientId': patientId,
    'patientName': patientName,
    'doctorId': doctorId,
    'doctorName': doctorName,
    'doctorSpecialization': doctorSpecialization,
    'date': _dateAsYmd(date),
    'timeSlot': timeSlot,
    'status': status,
    'paymentStatus': paymentStatus,
    'priority': priority,
    'ticketNumber': ticketNumber,
    'patientsAhead': patientsAhead,
    'estimatedWaitTime': estimatedWaitTime,
    'totalFee': totalFee,
    'consultationFee': consultationFee,
    'priorityFee': priorityFee,
    'qrCode': qrCode,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'checkInTime': checkInTime != null
        ? Timestamp.fromDate(checkInTime!)
        : null,
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
  };

  /// Create model from Firestore document
  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return AppointmentModel(
        id: doc.id,
        patientId: '',
        patientName: '',
        doctorId: '',
        doctorName: '',
        doctorSpecialization: '',
        date: DateTime.now(),
        timeSlot: '',
        status: 'waiting',
        paymentStatus: 'pay_at_hospital',
        priority: 'normal',
        ticketNumber: 0,
        patientsAhead: 0,
        estimatedWaitTime: 0,
        totalFee: 0.0,
        consultationFee: 0.0,
        priorityFee: 0.0,
        qrCode: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return AppointmentModel(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      patientName: data['patientName'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      doctorName: data['doctorName'] as String? ?? '',
      doctorSpecialization: data['doctorSpecialization'] as String? ?? '',
      date: _dateAsDateTime(data['date']),
      timeSlot: data['timeSlot'] as String? ?? '',
      status: data['status'] as String? ?? 'waiting',
      paymentStatus: data['paymentStatus'] as String? ?? 'pay_at_hospital',
      priority: data['priority'] as String? ?? 'normal',
      ticketNumber: _ticketAsInt(data['ticketNumber']),
      patientsAhead: data['patientsAhead'] as int? ?? 0,
      estimatedWaitTime: data['estimatedWaitTime'] as int? ?? 0,
      totalFee: (data['totalFee'] as num?)?.toDouble() ?? 0.0,
      consultationFee: (data['consultationFee'] as num?)?.toDouble() ?? 0.0,
      priorityFee: (data['priorityFee'] as num?)?.toDouble() ?? 0.0,
      qrCode: data['qrCode'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      checkInTime: data['checkInTime'] != null
          ? (data['checkInTime'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create a copy with modified fields
  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    String? doctorSpecialization,
    DateTime? date,
    String? timeSlot,
    String? status,
    String? paymentStatus,
    String? priority,
    int? ticketNumber,
    int? patientsAhead,
    int? estimatedWaitTime,
    double? totalFee,
    double? consultationFee,
    double? priorityFee,
    String? qrCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? checkInTime,
    DateTime? completedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorSpecialization: doctorSpecialization ?? this.doctorSpecialization,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      priority: priority ?? this.priority,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      patientsAhead: patientsAhead ?? this.patientsAhead,
      estimatedWaitTime: estimatedWaitTime ?? this.estimatedWaitTime,
      totalFee: totalFee ?? this.totalFee,
      consultationFee: consultationFee ?? this.consultationFee,
      priorityFee: priorityFee ?? this.priorityFee,
      qrCode: qrCode ?? this.qrCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checkInTime: checkInTime ?? this.checkInTime,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
