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
import '../providers/feed_provider.dart';

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
        title: Text(
          'Messages',
          style: AppTypography.h3.copyWith(fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFF1A1A1A))
        )
      ),
      body: inboxAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentPrimary,
          )
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load messages.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            )
          )
        ),
        data: (convos) {
          if (convos.isEmpty) return _EmptyInbox();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: convos.length,
            separatorBuilder: (_, __) => const Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 72,
              color: Color(0xFF141414),
            ),
            itemBuilder: (ctx, i) => _ConvoTile(
              convo: convos[i],
              myId: myId,
            ),
          );
        }
      )
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
    final unread = convo.unreadFor(myId);

    return peerAsync.when(
      loading: () => const SizedBox(height: 72),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        final username =
            profile?['username'] as String? ?? 'anon';
        final avatarUrl = _avatarUrl(profile);
        final lastMsg = convo.lastMessage ?? '';
        final isFromMe = convo.lastSenderId == myId;

        return InkWell(
          onTap: () {
            context.push(
              '/dm/$peerId',
              extra: {'username': username, 'avatarUrl': avatarUrl},
            );
          },
          splashColor: Colors.transparent,
          highlightColor: const Color(0xFF0F0F0F),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                _DmAvatar(url: avatarUrl, size: 46),
                const SizedBox(width: 12),
                // Text
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
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (convo.lastMessageAt != null)
                            Text(
                              timeago.format(
                                  convo.lastMessageAt!,
                                  allowFromNow: true),
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: unread > 0
                                    ? AppColors.accentPrimary
                                    : AppColors.hintText,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isFromMe
                                  ? 'You: $lastMsg'
                                  : lastMsg,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                color: unread > 0
                                    ? AppColors.textSecondary
                                    : AppColors.hintText,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.accentPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
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
        );
      },
    );
  }

  String? _avatarUrl(Map<String, dynamic>? profile) {
    final raw = profile?['avatarConfig'];
    if (raw == null) return null;
    try {
      return AvatarConfig.fromMap(raw as Map<String, dynamic>)
          .buildUrl(size: 92);
    } catch (_) {
      return null;
    }
  }
}

class _EmptyInbox extends StatelessWidget {
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
              color: const Color(0xFF0F0F0F),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1E1E1E), width: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visit someone\'s profile and tap Message\n to start a private conversation',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: AppColors.hintText,
              height: 1.6
            )
          )
        ],
      )
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
        color: AppColors.accentPrimary.withOpacity(0.25),
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
        size: 20, color: AppColors.hintText),
  );
}
