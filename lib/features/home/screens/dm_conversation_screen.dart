import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
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

class _DmConversationScreenState extends ConsumerState<DmConversationScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _msgKeys = {};

  bool _canSend = false;
  bool _loadingMore = false;

  String? _firstUnreadMessageId;
  bool _unreadIdCaptured = false;
  String? _highlightedMessageId;

  DmReplyTo? _replyTo;
  bool _replyIsFromMe = false;
  String? _editingMessageId;
  String _peerUsername = '';

  String get _myId => LocalStorageService.getCachedAnonId() ?? '';
  String get _convoId => conversationId(_myId, widget.peerId);

  @override
  void initState() {
    super.initState();
    _peerUsername = widget.initialUsername ?? 'anon';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeConversationIdProvider.notifier).state = _convoId;
    });
    _ctrl.addListener(() {
      final v = _ctrl.text.trim().isNotEmpty;
      if (v != _canSend) setState(() => _canSend = v);
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    ref.read(activeConversationIdProvider.notifier).state = null;
    _ctrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 160 &&
        !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final current = ref.read(dmMessageLimitProvider(_convoId));
    ref.read(dmMessageLimitProvider(_convoId).notifier).state = current + 25;
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _loadingMore = false);
  }

  void _scrollToMessage(String messageId) {
    final key = _msgKeys[messageId];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      alignment: 0.5,
    );
    setState(() => _highlightedMessageId = messageId);
    Future.delayed(const Duration(milliseconds: 1400),
            () => mounted ? setState(() => _highlightedMessageId = null) : null);
  }

  Future<void> _send() async {
    if (_editingMessageId != null) {
      await _confirmEdit();
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final reply = _replyTo;
    _ctrl.clear();
    setState(() {
      _canSend = false;
      _replyTo = null;
      _replyIsFromMe = false;
    });
    HapticFeedback.selectionClick();
    _focusNode.requestFocus();
    await ref
        .read(dmSendProvider.notifier)
        .send(peerId: widget.peerId, text: text, replyTo: reply);
  }

  Future<void> _confirmEdit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _editingMessageId == null) return;
    final id = _editingMessageId!;
    _ctrl.clear();
    setState(() {
      _canSend = false;
      _editingMessageId = null;
    });
    await ref
        .read(dmSendProvider.notifier)
        .edit(convoId: _convoId, messageId: id, newText: text);
  }

  void _cancelEdit() {
    _ctrl.clear();
    setState(() {
      _editingMessageId = null;
      _canSend = false;
    });
    _focusNode.unfocus();
  }

  void _startEdit(DmMessage msg) {
    _ctrl.text = msg.text;
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    setState(() {
      _editingMessageId = msg.id;
      _replyTo = null;
      _replyIsFromMe = false;
      _canSend = true;
    });
    _focusNode.requestFocus();
  }

  void _startReply(DmMessage msg) {
    setState(() {
      _replyTo = DmReplyTo(
        messageId: msg.id,
        senderId: msg.senderId,
        text: msg.isDeleted ? 'Deleted message' : msg.text,
      );
      _replyIsFromMe = msg.senderId == _myId;
      _editingMessageId = null;
    });
    _focusNode.requestFocus();
  }

  void _showMessageOptions(BuildContext context, DmMessage msg) {
    if (msg.isDeleted) return;
    final isMe = msg.senderId == _myId;
    HapticFeedback.mediumImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => _MessageOptionsDialog(
        msg: msg,
        isMe: isMe,
        onReply: () {
          Navigator.of(ctx).pop();
          _startReply(msg);
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: msg.text));
          Navigator.of(ctx).pop();
        },
        onEdit: isMe
            ? () {
          Navigator.of(ctx).pop();
          _startEdit(msg);
        }
            : null,
        onDelete: isMe
            ? () {
          Navigator.of(ctx).pop();
          ref.read(dmSendProvider.notifier).delete(
            convoId: _convoId,
            messageId: msg.id,
          );
        }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(dmMessagesProvider(_convoId));
    final peerAsync = ref.watch(dmPeerProfileProvider(widget.peerId));
    final isSending = ref.watch(dmSendProvider);

    peerAsync.whenData((p) {
      final name = p?['username'] as String?;
      if (name != null && name != _peerUsername) {
        WidgetsBinding.instance.addPostFrameCallback(
                (_) => mounted ? setState(() => _peerUsername = name) : null);
      }
    });

    ref.listen(dmMessagesProvider(_convoId), (prev, next) {
      next.whenData((msgs) {
        if (!_unreadIdCaptured && msgs.isNotEmpty) {
          final firstUnread = msgs.reversed
              .where((m) => m.senderId != _myId && m.readAt == null)
              .firstOrNull;
          _firstUnreadMessageId = firstUnread?.id;
          _unreadIdCaptured = true;
        }

        final hasUnreads =
        msgs.any((m) => m.senderId != _myId && m.readAt == null);
        if (hasUnreads) {
          markConversationRead(_convoId, _myId);
        }
      });
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.backgroundMain,
      appBar: _buildAppBar(peerAsync),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accentPrimary),
              ),
              error: (_, __) => _EmptyConvo(username: _peerUsername),
              data: (msgs) {
                if (msgs.isEmpty) return _EmptyConvo(username: _peerUsername);

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: msgs.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == msgs.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.accentPrimary),
                          ),
                        ),
                      );
                    }

                    final msg = msgs[i];
                    _msgKeys[msg.id] ??= GlobalKey();
                    final isMe = msg.senderId == _myId;

                    final isOldest = i == msgs.length - 1;
                    final olderMsg = isOldest ? null : msgs[i + 1];
                    final showDate = isOldest ||
                        !_sameDay(olderMsg!.createdAt, msg.createdAt);
                    final showUnreadSep = _firstUnreadMessageId != null &&
                        msg.id == _firstUnreadMessageId;

                    return Column(
                      key: _msgKeys[msg.id],
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showUnreadSep) const _UnreadSeparator(),
                        if (showDate) _DateDivider(msg.createdAt),
                        _SwipeableMessage(
                          msg: msg,
                          isMe: isMe,
                          onLongPress: () =>
                              _showMessageOptions(context, msg),
                          onSwipeReply: () => _startReply(msg),
                          child: _MessageBubble(
                            msg: msg,
                            isMe: isMe,
                            isHighlighted: _highlightedMessageId == msg.id,
                            myId: _myId,
                            peerUsername: _peerUsername,
                            onReplyTap: msg.replyTo != null
                                ? () =>
                                _scrollToMessage(msg.replyTo!.messageId)
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_replyTo != null)
            _ReplyPreview(
              replyTo: _replyTo!,
              myId: _myId,
              peerUsername: _peerUsername,
              onCancel: () => setState(() {
                _replyTo = null;
                _replyIsFromMe = false;
              }),
            ),
          if (_editingMessageId != null)
            _EditingBanner(onCancel: _cancelEdit),
          _InputBar(
            ctrl: _ctrl,
            focusNode: _focusNode,
            canSend: _canSend,
            isSending: isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      AsyncValue<Map<String, dynamic>?> peerAsync) {
    final avatarUrl = peerAsync.when(
      data: (p) {
        final raw = p?['avatarConfig'];
        if (raw == null) return widget.initialAvatarUrl;
        try {
          return AvatarConfig.fromMap(raw as Map<String, dynamic>)
              .buildUrl(size: 72);
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
            Text(
              '@$_peerUsername',
              style: AppTypography.bodyMedium.copyWith(
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFF1A1A1A)),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SwipeableMessage extends StatefulWidget {
  final DmMessage msg;
  final bool isMe;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;
  final Widget child;

  const _SwipeableMessage({
    required this.msg,
    required this.isMe,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.child,
  });

  @override
  State<_SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<_SwipeableMessage> {
  double _dragX = 0;
  bool _triggered = false;
  static const double _threshold = 64;

  void _onUpdate(DragUpdateDetails d) {
    final delta = d.delta.dx;
    if (widget.isMe && delta > 0) return;
    if (!widget.isMe && delta < 0) return;

    setState(() {
      _dragX = (_dragX + delta).clamp(
        widget.isMe ? -_threshold : 0.0,
        widget.isMe ? 0.0 : _threshold,
      );
    });

    if (_dragX.abs() >= _threshold && !_triggered) {
      _triggered = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onEnd(DragEndDetails _) {
    if (_triggered) widget.onSwipeReply();
    setState(() {
      _dragX = 0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.msg.isDeleted) {
      return GestureDetector(
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    final progress = (_dragX.abs() / _threshold).clamp(0.0, 1.0);
    final circleSize = 28.0 + progress * 14;
    final iconSize = 14.0 + progress * 6;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: widget.isMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.isMe ? 0 : 4,
                  right: widget.isMe ? 4 : 0,
                ),
                child: Opacity(
                  opacity: progress,
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentPrimary.withOpacity(0.12),
                      border: Border.all(
                        color:
                        AppColors.accentPrimary.withOpacity(progress * 0.7),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.cornerUpLeft,
                      size: iconSize,
                      color:
                      AppColors.accentPrimary.withOpacity(progress),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DmMessage msg;
  final bool isMe;
  final bool isHighlighted;
  final String myId;
  final String peerUsername;
  final VoidCallback? onReplyTap;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.isHighlighted,
    required this.myId,
    required this.peerUsername,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
              top: 2,
              bottom: 2,
              left: isMe ? 64 : 0,
              right: isMe ? 0 : 64),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(14),
            border:
            Border.all(color: const Color(0xFF1E1E1E), width: 0.7),
          ),
          child: Text(
            'Message deleted',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: AppColors.hintText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isMe ? 64 : 0,
            right: isMe ? 0 : 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.accentPrimary.withOpacity(0.18)
              : isMe
              ? AppColors.accentPrimary.withOpacity(0.13)
              : const Color(0xFF111118),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isHighlighted
                ? AppColors.accentPrimary.withOpacity(0.5)
                : isMe
                ? AppColors.accentPrimary.withOpacity(0.2)
                : const Color(0xFF1E1E2A),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.replyTo != null)
              GestureDetector(
                onTap: onReplyTap,
                child: _ReplyQuote(
                  replyTo: msg.replyTo!,
                  myId: myId,
                  peerUsername: peerUsername,
                ),
              ),
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
                if (msg.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Text(
                      'Edited',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.hintText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Text(
                  DateFormat('h:mm a').format(msg.createdAt.toLocal()),
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

class _ReplyQuote extends StatelessWidget {
  final DmReplyTo replyTo;
  final String myId;
  final String peerUsername;

  const _ReplyQuote({
    required this.replyTo,
    required this.myId,
    required this.peerUsername,
  });

  @override
  Widget build(BuildContext context) {
    final isReplyFromMe = replyTo.senderId == myId;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: AppColors.accentPrimary.withOpacity(0.6),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isReplyFromMe ? 'You' : '@$peerUsername',
            style: AppTypography.labelSmall.copyWith(
              fontSize: 10,
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo.text,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _UnreadSeparator extends StatelessWidget {
  const _UnreadSeparator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.accentPrimary.withOpacity(0.45),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentPrimary.withOpacity(0.45),
              width: 0.8,
            ),
          ),
          child: Text(
            'New messages',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accentPrimary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.accentPrimary.withOpacity(0.45),
          ),
        ),
      ],
    ),
  );
}

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
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFF2A2A2A), thickness: 0.5),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _label(),
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFF2A2A2A), thickness: 0.5),
        ),
      ],
    ),
  );
}

class _ReplyPreview extends StatelessWidget {
  final DmReplyTo replyTo;
  final String myId;
  final String peerUsername;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.replyTo,
    required this.myId,
    required this.peerUsername,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF0A0A0A),
      border:
      Border(top: BorderSide(color: Color(0xFF1E1E1E), width: 0.5)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replyTo.senderId == myId ? 'You' : '@$peerUsername',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 11,
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                replyTo.text,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onCancel,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(LucideIcons.x,
                size: 16, color: AppColors.hintText),
          ),
        ),
      ],
    ),
  );
}

class _EditingBanner extends StatelessWidget {
  final VoidCallback onCancel;
  const _EditingBanner({required this.onCancel});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF0A0A0A),
      border:
      Border(top: BorderSide(color: Color(0xFF1E1E1E), width: 0.5)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        const Icon(LucideIcons.pencil,
            size: 14, color: AppColors.accentSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Editing message',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: AppColors.accentSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: onCancel,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(LucideIcons.x,
                size: 16, color: AppColors.hintText),
          ),
        ),
      ],
    ),
  );
}

class _MessageOptionsDialog extends StatelessWidget {
  final DmMessage msg;
  final bool isMe;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageOptionsDialog({
    required this.msg,
    required this.isMe,
    required this.onReply,
    required this.onCopy,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: isMe ? 72 : 16,
          right: isMe ? 16 : 72,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141420),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF2A2A3A), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OptionTile(
                    icon: LucideIcons.cornerUpLeft,
                    label: 'Reply',
                    onTap: onReply),
                _divider(),
                _OptionTile(
                    icon: LucideIcons.copy, label: 'Copy', onTap: onCopy),
                if (onEdit != null) ...[
                  _divider(),
                  _OptionTile(
                      icon: LucideIcons.pencil,
                      label: 'Edit',
                      onTap: onEdit!),
                ],
                if (onDelete != null) ...[
                  _divider(),
                  _OptionTile(
                    icon: LucideIcons.trash2,
                    label: 'Delete',
                    onTap: onDelete!,
                    isDestructive: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(height: 0.5, color: const Color(0xFF1E1E2A));
}

class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? AppColors.errorLight
        : AppColors.textPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withOpacity(0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 17, color: color),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.ctrl,
    required this.focusNode,
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF050505),
          border: Border(
              top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF1E1E1E),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  maxLines: null,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
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
              canSend: canSend && !isSending,
              isSending: isSending,
              onTap: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final bool canSend;
  final bool isSending;
  final VoidCallback onTap;

  const _SendButton({
    required this.canSend,
    required this.isSending,
    required this.onTap,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
      widget.canSend ? (_) => setState(() => _pressed = true) : null,
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

class _EmptyConvo extends StatelessWidget {
  final String username;
  const _EmptyConvo({required this.username});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF1E1E1E), width: 0.8),
          ),
          child: const Icon(LucideIcons.messageCircle,
              size: 24, color: AppColors.hintText),
        ),
        const SizedBox(height: 16),
        Text(
          'Say hi to @$username',
          style: AppTypography.bodyMedium.copyWith(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is the beginning of your\nprivate conversation.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 13,
            color: AppColors.hintText,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

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