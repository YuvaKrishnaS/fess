import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/local_storage_service.dart';
import 'providers/world_provider.dart';

class WorldSessionScreen extends ConsumerStatefulWidget {
  const WorldSessionScreen({super.key});

  @override
  ConsumerState<WorldSessionScreen> createState() => _WorldSessionScreenState();
}

class _WorldSessionScreenState extends ConsumerState<WorldSessionScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    await ref.read(worldProvider.notifier).sendMessage(text);
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(worldProvider);
    final session = state.session;
    final myAnonId = LocalStorageService.getCachedAnonId() ?? '';
    final sessionId = state.sessionId;

    if (session == null || sessionId == null) {
      return const Scaffold(backgroundColor: AppColors.backgroundMain);
    }

    // figure out partner
    final partnerId = session.participantIds
        .firstWhere((id) => id != myAnonId, orElse: () => '');
    final partnerProfile =
        session.participantProfiles[partnerId] as Map<String, dynamic>? ?? {};
    final partnerUsername =
        partnerProfile['username'] as String? ?? 'someone';
    final partnerMood = partnerId == session.participantIds.first
        ? session.moodA
        : session.moodB;
    final myMood = myAnonId == session.participantIds.first
        ? session.moodA
        : session.moodB;

    final moodPairLabel =
        '${_moodLabel(myMood)} meets ${_moodLabel(partnerMood)}';
    final secondsLeft = session.secondsRemaining;
    final isLast30 = secondsLeft <= 30;

    final messages = ref.watch(worldMessagesProvider(sessionId));

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            // ----------------------------------------------------------------
            // header
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // partner info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@$partnerUsername',
                          style: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          moodPairLabel,
                          style: const TextStyle(
                            fontFamily: 'DM Serif Display',
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // timer arc + number
                  _TimerWidget(
                    secondsLeft: secondsLeft,
                    totalSeconds: 300,
                    showNumber: isLast30,
                  ),

                  const SizedBox(width: 12),

                  // skip
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(worldProvider.notifier).skip();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.borderSubtle, width: 0.8),
                      ),
                      child: Text(
                        'Skip',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // thin divider
            const SizedBox(height: 14),
            Container(height: 0.5, color: AppColors.borderSubtle),

            // ----------------------------------------------------------------
            // messages
            // ----------------------------------------------------------------
            Expanded(
              child: messages.when(
                data: (msgs) {
                  if (msgs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Say something.',
                            style: const TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You have 5 minutes.',
                            style: const TextStyle(
                              fontFamily: 'DM Serif Display',
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              color: AppColors.hintText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: msgs.length,
                    itemBuilder: (ctx, i) {
                      final msg = msgs[i];
                      final isMe = msg.senderAnonId == myAnonId;
                      return _MessageBubble(
                        text: msg.text,
                        isMe: isMe,
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ----------------------------------------------------------------
            // input
            // ----------------------------------------------------------------
            Container(
              color: AppColors.backgroundMain,
              child: Column(
                children: [
                  Container(height: 0.5, color: AppColors.borderSubtle),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            focusNode: _focusNode,
                            style: AppTypography.bodyMedium,
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Say something...',
                              hintStyle: AppTypography.hint,
                              border: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _moodLabel(String id) {
    return kMoodOptions
        .firstWhere((m) => m.id == id, orElse: () => kMoodOptions.last)
        .label;
  }
}

// ---- message bubble ---------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _MessageBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.textPrimary : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Open Sans',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isMe ? AppColors.backgroundMain : AppColors.textPrimary,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

// ---- timer widget -----------------------------------------------------------

class _TimerWidget extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final bool showNumber;

  const _TimerWidget({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.showNumber,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / totalSeconds;
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: _ArcTimerPainter(
          progress: progress,
          isLow: secondsLeft <= 30,
        ),
        child: showNumber
            ? Center(
          child: Text(
            secondsLeft.toString(),
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: secondsLeft <= 30
                  ? AppColors.errorLight
                  : AppColors.textSecondary,
            ),
          ),
        )
            : null,
      ),
    );
  }
}

class _ArcTimerPainter extends CustomPainter {
  final double progress;
  final bool isLow;
  _ArcTimerPainter({required this.progress, required this.isLow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.borderSubtle
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // arc
    final arcPaint = Paint()
      ..color = isLow ? AppColors.errorLight : AppColors.accentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcTimerPainter old) =>
      old.progress != progress || old.isLow != isLow;
}