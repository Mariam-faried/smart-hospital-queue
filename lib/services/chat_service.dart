import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  static String buildChatId({
    required String doctorId,
    required String patientId,
  }) {
    return '${doctorId}_$patientId';
  }

  Future<String> resolvePatientName(String patientId) async {
    if (patientId.trim().isEmpty) return 'Patient';
    final userDoc = await _firestore.collection('users').doc(patientId).get();
    final rawName = userDoc.data()?['name'];
    if (rawName is String && rawName.trim().isNotEmpty) {
      return rawName.trim();
    }
    return 'Patient';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String chatId) {
    return _firestore
        .collection('doctor_patient_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(250)
        .snapshots();
  }

  Future<void> ensurePatientChat({
    required String chatId,
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String patientName,
  }) async {
    final chatRef = _firestore.collection('doctor_patient_chats').doc(chatId);
    await chatRef.set({
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'participantIds': [doctorId, patientId],
      'lastMessage': '',
      'lastSenderId': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendPatientMessage({
    required String chatId,
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String patientName,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final chatRef = _firestore.collection('doctor_patient_chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final chatSnap = await transaction.get(chatRef);
      final basePayload = <String, dynamic>{
        'doctorId': doctorId,
        'doctorName': doctorName,
        'patientId': patientId,
        'patientName': patientName,
        'participantIds': [doctorId, patientId],
        'lastMessage': trimmedText,
        'lastSenderId': patientId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!chatSnap.exists) {
        transaction.set(chatRef, {
          ...basePayload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(chatRef, basePayload);
      }

      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'chatId': chatId,
        'senderId': patientId,
        'senderRole': 'patient',
        'text': trimmedText,
        'type': 'text',
        'readBy': [patientId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
