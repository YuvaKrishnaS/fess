import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/local_message.dart';

class DmMessageBubble extends StatelessWidget {
  final LocalMessage message;
  final bool isMine;
  final DateTime? peerLastRead;
  final void Function(String emoji) onReact;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DmMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.peerLastRead,
    required this.onReact,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isSeen =>
      isMine && peerLastRead != null && message.createdAt.isBefore(peerLastRead!);

  void _showLongPressSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '😂', '😮', '😢', '👍', '🔥'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onReact(emoji);
                        Navigator.pop(ctx);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFF262626)),
              ListTile(
                leading: const Icon(LucideIcons.info, color: AppColors.textSecondary, size: 18),
                title: Text(
                  'Sent at ${DateFormat('MMM d, h:mm a').format(message.createdAt)}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontSize: 13),
                ),
                subtitle: isMine
                    ? Text(
                  _isSeen ? 'Seen' : 'Not seen yet',
                  style: AppTypography.bodySmall.copyWith(
                    color: _isSeen ? AppColors.accentPrimary : AppColors.hintText,
                    fontSize: 12,
                  ),
                )
                    : null,
              ),
              if (isMine && message.syncState != MessageSyncState.pending) ...[
                ListTile(
                  leading: const Icon(LucideIcons.pencil, color: AppColors.textSecondary, size: 18),
                  title: Text('Edit', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.trash2, color: AppColors.errorLight, size: 18),
                  title: Text('Delete', style: AppTypography.bodyMedium.copyWith(color: AppColors.errorLight, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Message deleted',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.hintText,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final hasReactions = message.reactions.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 48 : 16,
        right: isMine ? 16 : 48,
        top: 4,
        bottom: hasReactions ? 14 : 4,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: isMine ? Alignment.bottomRight : Alignment.bottomLeft,
        children: [
          GestureDetector(
            onLongPress: () => _showLongPressSheet(context),
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.accentPrimary : AppColors.elevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                  ),
                  child: Opacity(
                    opacity: message.syncState == MessageSyncState.pending ? 0.6 : 1.0,
                    child: Text(
                      message.text,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14.5,
                        height: 1.35,
                        color: isMine ? AppColors.backgroundMain : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.syncState == MessageSyncState.failed)
                      GestureDetector(
                        onTap: onRetry,
                        child: Row(
                          children: [
                            const Icon(LucideIcons.refreshCw, size: 11, color: AppColors.errorLight),
                            const SizedBox(width: 3),
                            Text('Failed, tap to retry',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.errorLight, fontSize: 10)),
                          ],
                        ),
                      )
                    else if (message.syncState == MessageSyncState.pending)
                      Text('Sending...',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.hintText, fontSize: 10))
                    else if (isMine)
                        Text(_isSeen ? 'Seen' : 'Sent',
                            style: AppTypography.bodySmall.copyWith(
                              color: _isSeen ? AppColors.accentPrimary : AppColors.hintText,
                              fontSize: 10,
                            )),
                  ],
                ),
              ],
            ),
          ),
          if (hasReactions)
            Positioned(
              bottom: -12,
              right: isMine ? 4 : null,
              left: isMine ? null : 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundMain,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  message.reactions.values.first,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}