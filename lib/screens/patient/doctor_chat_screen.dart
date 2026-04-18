import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../utils/app_colors.dart';

class DoctorChatScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorChatScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isInitializing = true;
  bool _isSending = false;
  String? _chatId;
  String? _patientId;
  String _patientName = 'Patient';
  String? _initError;

  String get _displayDoctorName {
    final name = widget.doctorName.trim();
    if (name.isEmpty) return 'Doctor';
    final lower = name.toLowerCase();
    if (lower.startsWith('dr.') || lower.startsWith('dr ')) {
      return name;
    }
    return 'Dr. $name';
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final uid = _chatService.currentUserId;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _initError = 'Please sign in again to use secure in-app chat.';
        _isInitializing = false;
      });
      return;
    }

    try {
      final chatId = ChatService.buildChatId(
        doctorId: widget.doctorId,
        patientId: uid,
      );
      final patientName = await _chatService.resolvePatientName(uid);
      await _chatService.ensurePatientChat(
        chatId: chatId,
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        patientId: uid,
        patientName: patientName,
      );
      if (!mounted) return;

      setState(() {
        _patientId = uid;
        _patientName = patientName;
        _chatId = chatId;
        _initError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initError = _mapChatError(error, isInitialization: true);
      });
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _sendMessage() async {
    final chatId = _chatId;
    final patientId = _patientId;
    final message = _messageController.text.trim();

    if (_isSending || message.isEmpty || chatId == null || patientId == null) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await _chatService.sendPatientMessage(
        chatId: chatId,
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        patientId: patientId,
        patientName: _patientName,
        text: message,
      );

      if (!mounted) return;
      _messageController.clear();
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapChatError(error, isInitialization: false)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _mapChatError(Object error, {required bool isInitialization}) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return isInitialization
              ? 'Secure chat is blocked by permissions. Please sign in again and retry.'
              : 'Message blocked by chat permissions. Please try again in a moment.';
        case 'unavailable':
        case 'network-request-failed':
          return isInitialization
              ? 'Network issue while opening chat. Please check your connection.'
              : 'Network issue while sending message. Please retry.';
      }
    }
    return isInitialization
        ? 'Could not initialize secure chat. Please try again shortly.'
        : 'Could not send message. Please try again.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatId = _chatId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text('Message $_displayDoctorName'),
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _initError != null
                ? _ChatEmptyState(
                    icon: Icons.lock_outline,
                    title: 'Chat Unavailable',
                    subtitle: _initError!,
                  )
                : chatId == null
                ? const _ChatEmptyState(
                    icon: Icons.lock_outline,
                    title: 'Chat Unavailable',
                    subtitle: 'Please sign in again to use secure in-app chat.',
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _chatService.streamMessages(chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return const _ChatEmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'Could not load messages',
                          subtitle: 'Please check your internet and try again.',
                        );
                      }

                      final docs = snapshot.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return const _ChatEmptyState(
                          icon: Icons.mark_chat_unread_outlined,
                          title: 'No messages yet',
                          subtitle:
                              'Start the conversation and the doctor will reply here.',
                        );
                      }

                      _scrollToBottom();

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final senderId =
                              (data['senderId'] as String?)?.trim() ?? '';
                          final text = (data['text'] as String?)?.trim() ?? '';
                          final createdAt = data['createdAt'];
                          final isMine = senderId == _patientId;

                          return _ChatBubble(
                            text: text,
                            isMine: isMine,
                            timestamp: createdAt,
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: chatId != null && !_isSending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppColors.surfaceGrey,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSending || chatId == null
                        ? null
                        : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final dynamic timestamp;

  const _ChatBubble({
    required this.text,
    required this.isMine,
    required this.timestamp,
  });

  String _formatTime(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) return '';
    final date = rawTimestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: isMine ? null : Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isMine
                    ? AppColors.onPrimary.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ChatEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
