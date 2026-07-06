import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/notification_item.dart';
import '../providers/notification_history_provider.dart';

class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.chatMessage:
        return LucideIcons.messageCircle;
      case NotificationType.streakRisk:
        return LucideIcons.asterisk;
      case NotificationType.streakMilestone:
        return LucideIcons.flame;
      case NotificationType.reaction:
        return LucideIcons.heart;
      case NotificationType.systemAnnouncement:
        return LucideIcons.megaphone;
    }
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.chatMessage:
        return AppColors.accentPrimary;
      case NotificationType.streakRisk:
        return AppColors.errorLight;
      case NotificationType.streakMilestone:
        return AppColors.accentSecondary;
      case NotificationType.reaction:
        return AppColors.accentGlow;
      case NotificationType.systemAnnouncement:
        return AppColors.textSecondary;
    }
  }

  String _sectionFor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationHistoryProvider);
    final notifier = ref.read(notificationHistoryProvider.notifier);

    final grouped = <String, List<NotificationItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(_sectionFor(item.createdAt), () => []).add(item);
    }
    final sectionOrder = ['Today', 'Yesterday', 'Earlier'];

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: AppTypography.h3.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        await notifier.clearAll();
                      },
                      child: Text(
                        'Clear all',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.errorLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: sectionOrder.length,
                itemBuilder: (ctx, sectionIdx) {
                  final section = sectionOrder[sectionIdx];
                  final sectionItems = grouped[section];
                  if (sectionItems == null || sectionItems.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          section.toUpperCase(),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...sectionItems.map((item) => Slidable(
                        key: ValueKey(item.id),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.25,
                          children: [
                            SlidableAction(
                              onPressed: (_) => notifier.delete(item.id),
                              backgroundColor: AppColors.errorLight,
                              foregroundColor: Colors.white,
                              icon: LucideIcons.trash2,
                              label: 'Delete',
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            await notifier.markRead(item.id);
                            if (item.routePath != null && context.mounted) {
                              context.push(item.routePath!);
                            }
                          },
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _colorFor(item.type).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_iconFor(item.type), size: 18, color: _colorFor(item.type)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                          fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      timeago.format(item.createdAt, allowFromNow: true),
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 10,
                                        color: AppColors.hintText,
                                      ),
                                    ),
                                    if (!item.isRead) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: AppColors.accentPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
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
            child: const Icon(LucideIcons.bellOff, size: 28, color: AppColors.hintText),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}