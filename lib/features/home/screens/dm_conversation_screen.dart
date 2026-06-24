import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/models/avatar_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/dm_model.dart';
import '../../../core/services/local_storage_service.dart';
import '../providers/dm_provider.dart';

class DmConversationScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String? initialUsername;
  final String? initialAvatarUrl;

  const DmConversationScreen({
    super.key,
    required this.peerId,
    this.initialUsername,
    this.initialAvatarUrl,
  });

  @override
  ConsumerState<DmConversationScreen> createState() =>
      _DmConversationScreenState();
}

class _DmConversationScreenState
    extends ConsumerState<DmConversationScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _canSend = false;

  String get _myId =>
      LocalStorageService.getCachedAnonId() ?? '';

  String get _convoId => conversationId(_myId, widget.peerId);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final v = _ctrl.text.trim().isNotEmpty;
      if (v != _canSend) setState(() => _canSend = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _markRead() {
    if (_myId.isNotEmpty) {
      markConversationRead(_convoId, _myId);
    }
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollCtrl.hasClients) return;
    final target = _scrollCtrl.position.maxScrollExtent;
    if (animated) {
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _canSend = false);
    HapticFeedback.selectionClick();

    final ok = await ref.read(dmSendProvider.notifier).send(
      peerId: widget.peerId,
      text: text,
    );

    if (ok) {
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(animated: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
    ref.watch(dmMessageProvider(_convoId));
    final peerAsync =
    ref.watch(dmPeerProfileProvider(widget.peerId));
    final isSending = ref.watch(dmSendProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    final username = peerAsync.when(
      data: (p) => p?['username'] as String? ?? widget.initialUsername ?? 'anon',
      loading: () => widget.initialUsername ?? 'anon',
      error: (_, __) => widget.initialUsername ?? 'anon',
    );

    // Mark read whenever new messages arrive
    ref.listen(dmMessageProvider(_convoId), (_, __) => _markRead());

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: _buildAppBar(username, peerAsync),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentPrimary,
                ),
              ),
              error: (e, _) => Center(
                child: Text('Could not load messages.',
                    style: AppTypography.bodySmall),
              ),
              data: (msgs) {
                if (msgs.isEmpty) return _EmptyConvo();

                // Auto-scroll when list grows
                WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final msg = msgs[i];
                    final isMe = msg.senderId == _myId;
                    final showDate = i == 0 ||
                        !_sameDay(
                            msgs[i - 1].createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate) _DateDivider(msg.createdAt),
                        _MessageBubble(
                          msg: msg,
                          isMe: isMe,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundMain,
              border: Border(
                top: BorderSide(
                    color: Color(0xFF1A1A1A), width: 0.5),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, 8 + bottomPad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints:
                    const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF1E1E1E),
                        width: 0.8,
                      ),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      maxLines: null,
                      maxLength: 500,
                      buildCounter: (_, {required currentLength,
                        required isFocused, maxLength}) =>
                      null,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          fontSize: 15,
                          color: AppColors.hintText,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      cursorColor: AppColors.accentPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(
                  canSend: _canSend && !isSending,
                  isSending: isSending,
                  onTap: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      String username, AsyncValue<Map<String, dynamic>?> peerAsync) {
    final avatarUrl = peerAsync.when(
      data: (p) {
        final raw = p?['avatarConfig'];
        if (raw == null) return widget.initialAvatarUrl;
        try {
          return _buildAvatarUrl(raw as Map<String, dynamic>);
        } catch (_) {
          return widget.initialAvatarUrl;
        }
      },
      loading: () => widget.initialAvatarUrl,
      error: (_, __) => widget.initialAvatarUrl,
    );

    return AppBar(
      backgroundColor: AppColors.backgroundMain,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft,
            size: 20, color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: () => context.push('/profile/${widget.peerId}'),
        child: Row(
          children: [
            _DmAvatarSmall(url: avatarUrl),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: AppTypography.bodyMedium.copyWith(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child:
        Container(height: 0.5, color: const Color(0xFF1A1A1A)),
      ),
    );
  }

  String? _buildAvatarUrl(Map<String, dynamic> raw) {
    try {
      final cfg = AvatarConfig.fromMap(raw);
      return cfg.buildUrl(size: 72);
    } catch (_) {
      return null;
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// Message bubble

class _MessageBubble extends StatelessWidget {
  final DmMessage msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accentPrimary.withOpacity(0.15)
              : const Color(0xFF111118),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe
                ? AppColors.accentPrimary.withOpacity(0.2)
                : const Color(0xFF1E1E2A),
            width: 0.7,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(msg.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.hintText,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead
                        ? LucideIcons.checkCheck
                        : LucideIcons.check,
                    size: 12,
                    color: msg.isRead
                        ? AppColors.accentPrimary
                        : AppColors.hintText,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Date divider

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider(this.date);

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        const Expanded(
            child: Divider(
                color: Color(0xFF1E1E1E), thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _label(),
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: AppColors.hintText,
            ),
          ),
        ),
        const Expanded(
            child: Divider(
                color: Color(0xFF1E1E1E), thickness: 0.5)),
      ],
    ),
  );
}

// Empty conversation

class _EmptyConvo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.lock,
            size: 28, color: AppColors.hintText),
        const SizedBox(height: 12),
        Text(
          'End-to-end encrypted',
          style: AppTypography.bodyMedium.copyWith(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Only you and this person can see\nwhat you send here.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color: AppColors.hintText,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

// Small avatar for app bar

class _DmAvatarSmall extends StatelessWidget {
  final String? url;
  const _DmAvatarSmall({this.url});

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: AppColors.accentPrimary.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: ClipOval(
      child: url != null
          ? CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: const Color(0xFF111111)),
        errorWidget: (_, __, ___) => _fallback(),
      )
          : _fallback(),
    ),
  );

  Widget _fallback() => Container(
    color: const Color(0xFF111111),
    child: const Icon(LucideIcons.user,
        size: 16, color: AppColors.hintText),
  );
}

// Send button

class _SendButton extends StatefulWidget {
  final bool canSend;
  final bool isSending;
  final VoidCallback onTap;
  const _SendButton(
      {required this.canSend,
        required this.isSending,
        required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.canSend
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.canSend
          ? (_) {
        setState(() => _pressed = false);
        widget.onTap();
      }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: widget.canSend ? 1.0 : 0.3,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.accentPrimary,
              shape: BoxShape.circle,
            ),
            child: widget.isSending
                ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              ),
            )
                : const Icon(LucideIcons.arrowUp,
                size: 18, color: Colors.black),
          ),
        ),
      ),
    );
  }
}