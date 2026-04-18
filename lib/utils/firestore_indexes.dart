/// MediQueue Required Firestore Composite Indexes
///
/// This file serves as documentation for the composite indexes required by the application.
/// If queries fail with a link to create an index, ensure these are configured in the
/// Firebase Console -> Firestore Database -> Indexes -> Composite.
///
/// 1. Collection: 'appointments'
///    Fields:
///      - patientId: Ascending
///      - status: Ascending
///      - date: Ascending
///      - timeSlot: Ascending
///    Query Scope: Collection
///    Used in: Home screen upcoming appointment banner
///
/// 2. Collection: 'counters'
///    Fields:
///      - id: Ascending
///      - date: Ascending
///    Query Scope: Collection
///    Used in: Booking service ticket generation
///
/// 3. Collection: 'doctors'
///    Fields:
///      - specialization: Ascending
///      - rating: Descending
///    Query Scope: Collection
///    Used in: Doctor browsing with sorting
///
/// 4. Collection: 'appointments'
///    Fields:
///      - doctorId: Ascending
///      - date: Ascending
///      - status: Ascending
///    Query Scope: Collection
///    Used in: Queue service queue list, doctor schedule picker booked slots
abstract class FirestoreIndexes {
  // Documentation only class. No methods required.
}
