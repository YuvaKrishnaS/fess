import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/widgets/fess_snackbar.dart';
import '../providers/feed_provider.dart';

class CreateConfessionSheet extends ConsumerStatefulWidget {
  const CreateConfessionSheet({super.key});

  @override
  ConsumerState<CreateConfessionSheet> createState() =>
      _CreateConfessionSheetState();
}

class _CreateConfessionSheetState
    extends ConsumerState<CreateConfessionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _headingController = TextEditingController();
  final _bodyController = TextEditingController();
  int _bodyLength = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bodyController.addListener(() {
      setState(() => _bodyLength = _bodyController.text.length);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headingController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canPost => _headingController.text.trim().isNotEmpty;

  Future<void> _submitPost() async {
    if (!_canPost) return;
    HapticFeedback.mediumImpact();

    final success = await ref.read(createPostProvider.notifier).createConfession(
      heading: _headingController.text,
      body: _bodyController.text.isEmpty ? null : _bodyController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      FessSnackbar.show(
        context,
        'Confession posted.',
        type: SnackbarType.success,
      );
    } else {
      FessSnackbar.show(
        context,
        'Failed to post. Try again.',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPosting = ref.watch(createPostProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.6,
      snap: true,
      snapSizes: const [0.6, 0.92],
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Tab bar
              _SheetTabBar(tabController: _tabController),

              // Divider
              Container(height: 0.5, color: AppColors.border),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Confession tab
                    _ConfessionTab(
                      scrollController: scrollController,
                      profileAsync: profileAsync,
                      headingController: _headingController,
                      bodyController: _bodyController,
                      bodyLength: _bodyLength,
                      canPost: _canPost,
                      isPosting: isPosting,
                      onPost: _submitPost,
                      onHeadingChanged: (_) => setState(() {}),
                    ),

                    // ── Tea tab (M6)
                    _TeaPlaceholder(profileAsync: profileAsync),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetTabBar extends StatelessWidget {
  final TabController tabController;

  const _SheetTabBar({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabController,
      onTap: (_) => HapticFeedback.selectionClick(),
      indicatorColor: AppColors.accentPrimary,
      indicatorWeight: 2,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle:
      AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle:
      AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w400),
      tabs: const [
        Tab(text: 'Confession'),
        Tab(text: 'Tea'),
      ],
    );
  }
}

class _ConfessionTab extends StatelessWidget {
  final ScrollController scrollController;
  final AsyncValue<Map<String, dynamic>?> profileAsync;
  final TextEditingController headingController;
  final TextEditingController bodyController;
  final int bodyLength;
  final bool canPost;
  final bool isPosting;
  final VoidCallback onPost;
  final ValueChanged<String> onHeadingChanged;

  const _ConfessionTab({
    required this.scrollController,
    required this.profileAsync,
    required this.headingController,
    required this.bodyController,
    required this.bodyLength,
    required this.canPost,
    required this.isPosting,
    required this.onPost,
    required this.onHeadingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.value;
    final avatarUrl = profile?['avatarConfig'] != null
        ? AvatarConfig.fromMap(
        profile!['avatarConfig'] as Map<String, dynamic>)
        .buildUrl(size: 32)
        : null;
    final username = profile?['username'] as String? ?? 'anon';

    return Column(
      children: [
        // ── Author row + Post button
        Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _MiniAvatar(avatarUrl: avatarUrl),
              const SizedBox(width: 10),
              Text(
                '@$username',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _PostButton(
                canPost: canPost,
                isPosting: isPosting,
                onTap: onPost,
              ),
            ],
          ),
        ),

        Container(height: 0.5, color: AppColors.border),

        // ── Text fields
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                TextField(
                  controller: headingController,
                  onChanged: onHeadingChanged,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Give it a title...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.hintText,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyController,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: "What's on your mind...",
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.hintText,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLength: 500,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) {
                    return Text(
                      '$currentLength/500',
                      style: AppTypography.bodySmall.copyWith(
                        color: currentLength > 480
                            ? AppColors.errorLight
                            : AppColors.hintText,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // ── Bottom bar: image button (M4 — images wired in M6)
        Container(
          height: 0.5,
          color: AppColors.border,
        ),
        SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => FessSnackbar.show(
                    context,
                    'Image upload — Coming in next update',
                    type: SnackbarType.info,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundMain,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.image,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TeaPlaceholder extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> profileAsync;

  const _TeaPlaceholder({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.coffee, size: 40, color: AppColors.hintText),
          const SizedBox(height: 16),
          Text(
            'Spill the Tea coming soon.',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _MiniAvatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        color: AppColors.elevated,
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        )
            : Center(
          child: Icon(
            LucideIcons.user,
            size: 16,
            color: AppColors.hintText,
          ),
        ),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  final bool canPost;
  final bool isPosting;
  final VoidCallback onTap;

  const _PostButton({
    required this.canPost,
    required this.isPosting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canPost && !isPosting ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: canPost && !isPosting
              ? const LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
          )
              : null,
          color: canPost && !isPosting ? null : AppColors.backgroundMain,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: canPost ? AppColors.accentPrimary : AppColors.border,
            width: 1,
          ),
        ),
        child: isPosting
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white,
          ),
        )
            : Text(
          'Post',
          style: AppTypography.labelSmall.copyWith(
            color: canPost ? Colors.white : AppColors.hintText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}