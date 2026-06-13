import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/world_session_model.dart';
import '../../../core/services/local_storage_service.dart';
import 'providers/world_provider.dart';

class WorldSessionScreen extends ConsumerStatefulWidget {
  const WorldSessionScreen({super.key});

  @override
  ConsumerState<WorldSessionScreen> createState() => _WorldSessionScreenState();
}

class _WorldSessionScreenState extends ConsumerState<WorldSessionScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _timer;
  int _secondsLeft = 300; // 5 min

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    final session = ref.read(worldProvider).session;
    if (session != null) {
      _secondsLeft = session.secondsRemaining;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        // End session on timer (only creator side; Firestore status update)
        _endByTimer();
      }
    });
  }

  Future<void> _endByTimer() async {
    final sessionId = ref.read(worldProvider).sessionId;
    if (sessionId == null) return;
    try {
      await worldNotifier.skip(); // reuses same status update path
    } catch (_) {}
  }

  WorldNotifier get worldNotifier => ref.read(worldProvider.notifier);

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worldState = ref.watch(worldProvider);
    final session = worldState.session;
    final myAnonId = LocalStorageService.getCachedAnonId() ?? '';
    final sessionId = worldState.sessionId;

    if (session == null || sessionId == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundMain,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Partner info
    final partnerAnonId =
    session.participantIds.firstWhere((id) => id != myAnonId,
        orElse: () => '');
    final partnerProfile =
    session.participantProfiles[partnerAnonId] as Map<String, dynamic>?;
    final partnerUsername = partnerProfile?['username'] as String? ?? 'anon';
    final partnerAvatarConfig = partnerProfile?['avatarConfig'];
    final partnerAvatarUrl = partnerAvatarConfig != null
        ? AvatarConfig.fromMap(
        partnerAvatarConfig as Map<String, dynamic>)
        .buildUrl(size: 72)
        : null;
    final partnerMood = session.participantProfiles[partnerAnonId]?['mood'] as String?;
    final partnerMoodEmoji = kMoodOptions
        .firstWhere((m) => m.id == (partnerMood ?? ''),
        orElse: () => kMoodOptions.last)
        .emoji;

    final timerColor = _secondsLeft <= 30
        ? AppColors.errorLight
        : _secondsLeft <= 60
        ? const Color(0xFFE8C547)
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF1A1A1A), width: 0.5)),
              ),
              child: Row(
                children: [
                  // Partner avatar
                  _WorldAvatar(url: partnerAvatarUrl, size: 36),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$partnerUsername $partnerMoodEmoji',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'anonymous · world',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Timer
                  Text(
                    _fmt(_secondsLeft),
                    style: AppTypography.bodyMedium.copyWith(
                      fontFamily: 'DM Mono',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: timerColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Messages ──────────────────────────────────────────────────────
            Expanded(
              child: _MessagesView(
                sessionId: sessionId,
                myAnonId: myAnonId,
                scrollCtrl: _scrollCtrl,
              ),
            ),

            // ── Input bar ─────────────────────────────────────────────────────
            _InputBar(
              ctrl: _msgCtrl,
              onSend: () async {
                final text = _msgCtrl.text.trim();
                if (text.isEmpty) return;
                _msgCtrl.clear();
                HapticFeedback.selectionClick();
                await worldNotifier.sendMessage(text);
                await Future.delayed(const Duration(milliseconds: 100));
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(
                    _scrollCtrl.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              },
              onSkip: () async {
                HapticFeedback.mediumImpact();
                await worldNotifier.skip();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Messages view ────────────────────────────────────────────────────────────

class _MessagesView extends ConsumerWidget {
  final String sessionId;
  final String myAnonId;
  final ScrollController scrollCtrl;

  const _MessagesView({
    required this.sessionId,
    required this.myAnonId,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgsAsync = ref.watch(worldMessagesProvider(sessionId));

    return msgsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (msgs) {
        if (msgs.isEmpty) {
          return Center(
            child: Text(
              'Say hi 👋\nYou have 5 minutes.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          itemCount: msgs.length,
          itemBuilder: (ctx, i) {
            final msg = msgs[i];
            final isMe = msg.senderAnonId == myAnonId;
            return _MessageBubble(msg: msg, isMe: isMe);
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final WorldMessageModel msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accentPrimary.withOpacity(0.15)
              : const Color(0xFF141420),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe
                ? AppColors.accentPrimary.withOpacity(0.25)
                : const Color(0xFF1E1E2A),
            width: 0.8,
          ),
        ),
        child: Text(
          msg.text,
          style: AppTypography.bodyMedium.copyWith(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final VoidCallback onSkip;

  const _InputBar({
    required this.ctrl,
    required this.onSend,
    required this.onSkip,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A10),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5)),
      ),
      child: Row(
        children: [
          // Skip button
          GestureDetector(
            onTap: widget.onSkip,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF141420),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A2A3A), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.skip_next_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Skip',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: const Color(0xFF111118),
                borderRadius: BorderRadius.circular(20),
                border:
                Border.all(color: const Color(0xFF1E1E2A), width: 0.8),
              ),
              child: TextField(
                controller: widget.ctrl,
                maxLines: null,
                style: AppTypography.bodyMedium.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type something...',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    fontSize: 14,
                    color: AppColors.hintText,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                cursorColor: AppColors.accentPrimary,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: widget.ctrl.text.trim().isEmpty ? null : widget.onSend,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: widget.ctrl.text.trim().isEmpty ? 0.35 : 1.0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    size: 18, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar helper ────────────────────────────────────────────────────────────

class _WorldAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const _WorldAvatar({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.accentPrimary.withOpacity(0.3), width: 1),
      ),
      child: ClipOval(
        child: url != null
            ? Image.network(url!, fit: BoxFit.cover)
            : Container(
          color: const Color(0xFF1A1A28),
          child: const Icon(Icons.person,
              size: 16, color: AppColors.hintText),
        ),
      ),
    );
  }
}