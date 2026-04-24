import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
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
  late TabController _tab;
  final TextEditingController _heading = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final FocusNode _headingFocus = FocusNode();

  bool get _canPost => _heading.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _heading.addListener(() => setState(() {}));
    // Auto-focus heading after sheet animates in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _headingFocus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _heading.dispose();
    _body.dispose();
    _headingFocus.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (!_canPost) return;
    HapticFeedback.mediumImpact();

    final success = await ref.read(createPostProvider.notifier).createConfession(
      heading: _heading.text,
      body: _body.text.isNotEmpty ? _body.text : null,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Handle(),
              _SheetHeader(onClose: () => Navigator.of(context).pop()),
              _TypeSelector(controller: _tab),
              const SizedBox(height: 4),
              _ConfessionBody(
                tab: _tab,
                headingController: _heading,
                bodyController: _body,
                headingFocus: _headingFocus,
              ),
              _BottomBar(
                headingLength: _heading.text.length,
                bodyLength: _body.text.length,
                canPost: _canPost,
                isPosting: isPosting,
                onPost: _post,
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(
      begin: 0.05,
      end: 0,
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

// ─── Handle ───────────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Text(
            'New Confession',
            style: AppTypography.h4.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Type selector (Confession | Tea) ─────────────────────────────────────────

class _TypeSelector extends StatefulWidget {
  final TabController controller;

  const _TypeSelector({required this.controller});

  @override
  State<_TypeSelector> createState() => _TypeSelectorState();
}

class _TypeSelectorState extends State<_TypeSelector> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _TypePill(
            label: 'Confession',
            isSelected: widget.controller.index == 0,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.controller.animateTo(0);
            },
          ),
          const SizedBox(width: 8),
          _TypePill(
            label: 'Tea  🔒',
            isSelected: false,
            isLocked: true,
            onTap: () {
              HapticFeedback.selectionClick();
              FessSnackbar.show(
                context,
                'Tea drops in the next update.',
                type: SnackbarType.info,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.isSelected,
    this.isLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary.withOpacity(0.5)
                : const Color(0xFF2A2A2A),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.accentPrimary
                : isLocked
                ? AppColors.textSecondary.withOpacity(0.5)
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Confession form body ─────────────────────────────────────────────────────

class _ConfessionBody extends StatefulWidget {
  final TabController tab;
  final TextEditingController headingController;
  final TextEditingController bodyController;
  final FocusNode headingFocus;

  const _ConfessionBody({
    required this.tab,
    required this.headingController,
    required this.bodyController,
    required this.headingFocus,
  });

  @override
  State<_ConfessionBody> createState() => _ConfessionBodyState();
}

class _ConfessionBodyState extends State<_ConfessionBody> {
  @override
  void initState() {
    super.initState();
    widget.headingController.addListener(() => setState(() {}));
    widget.bodyController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading field
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextField(
                controller: widget.headingController,
                focusNode: widget.headingFocus,
                maxLength: 80,
                maxLines: 2,
                minLines: 1,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                null,
                style: AppTypography.bodyMedium.copyWith(
                  fontFamily: 'DM Sans',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: "What's your confession?",
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    fontFamily: 'DM Sans',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.hintText,
                    height: 1.4,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(right: 40, bottom: 4),
                  filled: false,
                ),
                textInputAction: TextInputAction.next,
              ),
              // Char counter
              Text(
                '${widget.headingController.text.length}/80',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: widget.headingController.text.length > 70
                      ? AppColors.errorLight.withOpacity(0.8)
                      : AppColors.hintText,
                ),
              ),
            ],
          ),
          // Divider between heading and body
          Container(
            height: 0.5,
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 8),
          ),
          // Body field
          TextField(
            controller: widget.bodyController,
            maxLength: 500,
            maxLines: 4,
            minLines: 2,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
            null,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Add more... (optional)',
              hintStyle: AppTypography.bodySmall.copyWith(
                fontSize: 14,
                color: AppColors.hintText,
                height: 1.6,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Bottom action bar ────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int headingLength;
  final int bodyLength;
  final bool canPost;
  final bool isPosting;
  final VoidCallback onPost;

  const _BottomBar({
    required this.headingLength,
    required this.bodyLength,
    required this.canPost,
    required this.isPosting,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 0.5, color: const Color(0xFF1E1E1E)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
          child: Row(
            children: [
              // Body char counter
              if (bodyLength > 0)
                Text(
                  '$bodyLength/500',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: bodyLength > 450
                        ? AppColors.errorLight.withOpacity(0.8)
                        : AppColors.hintText,
                  ),
                ),
              const Spacer(),
              // Post button
              _PostButton(
                canPost: canPost,
                isPosting: isPosting,
                onPost: onPost,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostButton extends StatelessWidget {
  final bool canPost;
  final bool isPosting;
  final VoidCallback onPost;

  const _PostButton({
    required this.canPost,
    required this.isPosting,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (canPost && !isPosting) ? onPost : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: canPost ? 1.0 : 0.35,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF1DE9B6)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: isPosting
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            'Post',
            style: AppTypography.labelMedium.copyWith(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}