import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/dm_model.dart';
import '../../../core/services/local_storage_service.dart';
import '../providers/dm_provider.dart';

String? _resolveAvatarUrl(Map<String, dynamic>? profile) {
  final raw = profile?['avatarConfig'];
  if (raw == null) return null;
  try {
    return AvatarConfig.fromMap(raw as Map<String, dynamic>).buildUrl(size: 92);
  } catch (_) {
    return null;
  }
}

class DmInboxScreen extends ConsumerWidget {
  const DmInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(dmInboxProvider);
    final myId = LocalStorageService.getCachedAnonId() ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundMain,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('Messages', style: AppTypography.h3.copyWith(fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFF1A1A1A)),
        ),
      ),
      body: inboxAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accentPrimary),
        ),
        error: (e, _) => const _EmptyInbox(),
        data: (convos) {
          if (convos.isEmpty) return const _EmptyInbox();

          final pinned = convos.where((c) => c.isPinnedFor(myId)).toList();
          final rest = convos.where((c) => !c.isPinnedFor(myId)).toList();

          return CustomScrollView(
            slivers: [
              if (pinned.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PinnedRow(convos: pinned, myId: myId),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Column(
                    children: [
                      _ConvoTile(convo: rest[i], myId: myId),
                      const Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: 72,
                        color: Color(0xFF141414),
                      ),
                    ],
                  ),
                  childCount: rest.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PinnedRow extends ConsumerWidget {
  final List<DmConversation> convos;
  final String myId;

  const _PinnedRow({required this.convos, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: convos.length,
        itemBuilder: (ctx, i) {
          final convo = convos[i];
          final peerId = convo.otherParticipant(myId);
          final peerAsync = ref.watch(dmPeerProfileProvider(peerId));
          final unread = convo.isUnreadFor(myId);

          return peerAsync.when(
            loading: () => const SizedBox(width: 64),
            error: (_, __) => const SizedBox.shrink(),
            data: (profile) {
              final username = profile?['username'] as String? ?? 'anon';
              final avatarUrl = _resolveAvatarUrl(profile);
              return GestureDetector(
                onTap: () => context.push('/dm/$peerId',
                    extra: {'username': username, 'avatarUrl': avatarUrl}),
                onLongPress: () => togglePinConversation(convo.id, myId, false),
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          _DmAvatar(url: avatarUrl, size: 52),
                          if (unread)
                            Positioned(
                              right: -1,
                              top: -1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.accentPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.backgroundMain,
                                      width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 56,
                        child: Text(
                          username,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConvoTile extends ConsumerWidget {
  final DmConversation convo;
  final String myId;

  const _ConvoTile({required this.convo, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peerId = convo.otherParticipant(myId);
    final peerAsync = ref.watch(dmPeerProfileProvider(peerId));
    final unread = convo.isUnreadFor(myId);
    final peerTyping = convo.peerIsTyping(peerId);

    return peerAsync.when(
      loading: () => const SizedBox(height: 72),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        final username = profile?['username'] as String? ?? 'anon';
        final avatarUrl = _resolveAvatarUrl(profile);
        final lastMsg = convo.lastMessage ?? '';
        final isFromMe = convo.lastSenderId == myId;

        return Dismissible(
          key: ValueKey(convo.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            _showActionSheet(context, ref, convo, myId, username);
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: const Color(0xFF1A0808),
            child: const Icon(LucideIcons.moreHorizontal,
                color: AppColors.errorLight),
          ),
          child: InkWell(
            onTap: () => context.push('/dm/$peerId',
                extra: {'username': username, 'avatarUrl': avatarUrl}),
            splashColor: Colors.transparent,
            highlightColor: const Color(0xFF0F0F0F),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _DmAvatar(url: avatarUrl, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '@$username',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontFamily: 'DM Sans',
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: unread
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (convo.lastMessageAt != null)
                              Text(
                                timeago.format(convo.lastMessageAt!,
                                    allowFromNow: true),
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: unread
                                      ? AppColors.accentPrimary
                                      : AppColors.hintText,
                                  fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: peerTyping
                                  ? Text(
                                'typing...',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 13,
                                  color: AppColors.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                                  : Text(
                                isFromMe ? 'You: $lastMsg' : lastMsg,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 13,
                                  color: unread
                                      ? AppColors.textPrimary
                                      : AppColors.hintText,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref, DmConversation convo,
      String myId, String username) {
    final isPinned = convo.isPinnedFor(myId);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                color: AppColors.textPrimary,
              ),
              title: Text(
                isPinned ? 'Unpin conversation' : 'Pin conversation',
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                togglePinConversation(convo.id, myId, !isPinned);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.errorLight),
              title: Text(
                'Delete conversation',
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.errorLight, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E1E1E), width: 0.8),
            ),
            child: const Icon(LucideIcons.messageCircle,
                size: 28, color: AppColors.hintText),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: AppTypography.bodyMedium.copyWith(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Visit someone\'s profile and tap\nMessage to start a private chat.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
                fontSize: 13, color: AppColors.hintText, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _DmAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const _DmAvatar({this.url, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
          color: AppColors.accentPrimary.withOpacity(0.25), width: 1),
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
    child: const Icon(LucideIcons.user, size: 20, color: AppColors.hintText),
  );
}