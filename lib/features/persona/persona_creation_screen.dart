import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/avatar_data.dart';
import '../../core/constants/username_words.dart';
import '../../core/widgets/fess_snackbar.dart';
import 'providers/persona_provider.dart';

class PersonaCreationScreen extends ConsumerStatefulWidget {
  const PersonaCreationScreen({super.key});

  @override
  ConsumerState<PersonaCreationScreen> createState() =>
      _PersonaCreationScreenState();
}

class _PersonaCreationScreenState
    extends ConsumerState<PersonaCreationScreen> {
  final _usernameController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _random = Random();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // preload all 20 avatars into cache in background
    for (int i = 0; i < AvatarData.count; i++) {
      precacheImage(
        CachedNetworkImageProvider(
            AvatarData.urlForSeed(AvatarData.seedAt(i))),
        context,
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  void _generateRandomUsername() {
    final adj = UsernameWords
        .adjectives[_random.nextInt(UsernameWords.adjectives.length)];
    final noun =
    UsernameWords.nouns[_random.nextInt(UsernameWords.nouns.length)];
    final num = 10 + _random.nextInt(89);
    final name = '${adj}_${noun}_$num';

    _usernameController.text = name;
    _usernameController.selection =
        TextSelection.fromPosition(TextPosition(offset: name.length));
    ref.read(personaProvider.notifier).onUsernameChanged(name);
    HapticFeedback.lightImpact();
  }

  Future<void> _handleSubmit() async {
    _usernameFocus.unfocus();
    final success =
    await ref.read(personaProvider.notifier).createPersona();
    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      context.go('/home');
    } else {
      final error = ref.read(personaProvider).errorMessage;
      if (error != null) {
        FessSnackbar.show(context, error, type: SnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personaProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundMain,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: _usernameFocus.unfocus,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 36),

                  _TitleSection()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.08, end: 0, duration: 400.ms),

                  const SizedBox(height: 40),

                  _AvatarCarousel(
                    currentIndex: state.avatarIndex,
                    isCreating: state.isCreating,
                    onPrevious: () {
                      final i = ref.read(personaProvider).avatarIndex;
                      ref.read(personaProvider.notifier).selectAvatar(
                        (i - 1 + AvatarData.count) % AvatarData.count,
                      );
                    },
                    onNext: () {
                      final i = ref.read(personaProvider).avatarIndex;
                      ref.read(personaProvider.notifier).selectAvatar(
                        (i + 1) % AvatarData.count,
                      );
                    },
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 500.ms)
                      .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.0, 1.0),
                    delay: 100.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),

                  // flexible gap — compresses when keyboard opens
                  const Spacer(),

                  _UsernameField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    status: state.usernameStatus,
                    length: state.username.length,
                    onChanged:
                    ref.read(personaProvider.notifier).onUsernameChanged,
                    onShuffleTap: _generateRandomUsername,
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .slideY(begin: 0.08, end: 0, delay: 200.ms),

                  const SizedBox(height: 8),

                  Text(
                    'Keep it as anonymous as possible!',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.hintText,
                    ),
                  ).animate().fadeIn(delay: 240.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: _TermsText(),
                  ).animate().fadeIn(delay: 280.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  _EnterFessButton(
                    canSubmit: state.canSubmit,
                    isCreating: state.isCreating,
                    onTap: state.canSubmit ? _handleSubmit : null,
                  ).animate().fadeIn(delay: 320.ms, duration: 400.ms),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Title ─────────────────────────────────────────────────────────────────────

class _TitleSection extends StatelessWidget {
  const _TitleSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Create Your',
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Anonymous ',
                style: AppTypography.h2.copyWith(
                  color: AppColors.accentSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: 'Profile',
                style: AppTypography.h2.copyWith(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Avatar carousel ───────────────────────────────────────────────────────────

class _AvatarCarousel extends StatefulWidget {
  final int currentIndex;
  final bool isCreating;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _AvatarCarousel({
    required this.currentIndex,
    required this.isCreating,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  State<_AvatarCarousel> createState() => _AvatarCarouselState();
}

class _AvatarCarouselState extends State<_AvatarCarousel> {
  bool _isForward = true;

  void _handlePrevious() {
    setState(() => _isForward = false);
    widget.onPrevious();
  }

  void _handleNext() {
    setState(() => _isForward = true);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final seed = AvatarData.seedAt(widget.currentIndex);
    final url = AvatarData.urlForSeed(seed);

    // purple glow color — use hardcoded hex to be safe regardless of AppColors definition
    const glowColor = Color(0xFF7B2FBE);

    return SizedBox(
      height: 255,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowButton(
            icon: LucideIcons.chevronLeft,
            onTap: widget.isCreating ? null : _handlePrevious,
          ),

          const SizedBox(width: 20),

          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (widget.isCreating) return;
              final v = details.primaryVelocity ?? 0;
              if (v < -200) _handleNext();
              if (v > 200) _handlePrevious();
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Glow: static, no animation, strong and visible ──
                Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x99_7B2FBE), // ~60% opacity purple
                        blurRadius: 75,
                        spreadRadius: 28,
                      ),
                      BoxShadow(
                        color: Color(0x55_7B2FBE), // ~33% outer haze
                        blurRadius: 120,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),

                // ── Gradient border ring ──
                Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.accentSecondary,
                        AppColors.accentPrimary,
                        AppColors.accentSecondary,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF07070F),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.isCreating
                        ? const _CreatingOverlay()
                        : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: Offset(_isForward ? 0.35 : -0.35, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ));
                        return SlideTransition(
                          position: offset,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _AvatarImage(
                        key: ValueKey(widget.currentIndex),
                        url: url,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          _ArrowButton(
            icon: LucideIcons.chevronRight,
            onTap: widget.isCreating ? null : _handleNext,
          ),
        ],
      ),
    );
  }
}

// ─── Arrow button — no background, just the icon ──────────────────────────────

class _ArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ArrowButton({required this.icon, this.onTap});

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: AnimatedOpacity(
          opacity: widget.onTap == null ? 0.2 : (_pressed ? 0.45 : 0.8),
          duration: const Duration(milliseconds: 100),
          child: Center(
            child: Icon(
              widget.icon,
              size: 26,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Avatar image ──────────────────────────────────────────────────────────────

class _AvatarImage extends StatelessWidget {
  final String url;

  const _AvatarImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
            AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(LucideIcons.user, size: 48, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─── Creating overlay ──────────────────────────────────────────────────────────

class _CreatingOverlay extends StatelessWidget {
  const _CreatingOverlay();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
            AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Creating user ...',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Username field ─────────────────────────────────────────────────────────────

class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final UsernameStatus status;
  final int length;
  final ValueChanged<String> onChanged;
  final VoidCallback onShuffleTap;

  const _UsernameField({
    required this.controller,
    required this.focusNode,
    required this.status,
    required this.length,
    required this.onChanged,
    required this.onShuffleTap,
  });

  Color _borderColor() {
    switch (status) {
      case UsernameStatus.available:
        return AppColors.accentPrimary;
      case UsernameStatus.taken:
      case UsernameStatus.invalid:
        return AppColors.errorLight;
      default:
        return const Color(0xFF2A2A3E);
    }
  }

  double _borderWidth() {
    switch (status) {
      case UsernameStatus.available:
      case UsernameStatus.taken:
      case UsernameStatus.invalid:
        return 1.5;
      default:
        return 1.0;
    }
  }

  bool get _hasError =>
      status == UsernameStatus.taken || status == UsernameStatus.invalid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            // subtle dark tint — not a flat grey, just barely visible
            color: const Color(0xFF0D0D16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _borderColor(),
              width: _borderWidth(),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),

              // shuffle/dice icon — tappable
              GestureDetector(
                onTap: onShuffleTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                  child: Icon(
                    LucideIcons.shuffle,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLength: 25,
                  buildCounter: (context,
                      {required currentLength,
                        required isFocused,
                        maxLength}) =>
                  null,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'Your anonymous name',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.hintText,
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(width: 10),
              _StatusIndicator(status: status, length: length),
              const SizedBox(width: 14),
            ],
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _hasError
              ? Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              status == UsernameStatus.taken
                  ? 'This name is already taken'
                  : 'Letters, numbers and _ only. Min 3 characters.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.errorLight,
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final UsernameStatus status;
  final int length;

  const _StatusIndicator({required this.status, required this.length});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case UsernameStatus.checking:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor:
            AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
          ),
        );
      case UsernameStatus.available:
        return Icon(LucideIcons.checkCircle2,
            size: 18, color: AppColors.accentPrimary);
      case UsernameStatus.taken:
        return Icon(LucideIcons.xCircle, size: 18, color: AppColors.errorLight);
      case UsernameStatus.invalid:
        return Icon(LucideIcons.alertCircle,
            size: 18, color: AppColors.errorLight);
      default:
        if (length > 0) {
          return Text(
            '$length/25',
            style: AppTypography.bodySmall.copyWith(
              color: length >= 23 ? AppColors.errorLight : AppColors.hintText,
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }
}

// ─── Terms ─────────────────────────────────────────────────────────────────────

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
          height: 1.65,
        ),
        children: [
          const TextSpan(
              text: 'By continuing, you confirm that you agree to the '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => FessSnackbar.show(
                context,
                'Coming soon',
                type: SnackbarType.info,
              ),
              child: Text(
                'Terms and Conditions',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.accentSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const TextSpan(text: ' and the '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => FessSnackbar.show(
                context,
                'Coming soon',
                type: SnackbarType.info,
              ),
              child: Text(
                'Fess Privacy Policy',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.accentSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const TextSpan(
            text:
            ' also. Your data may or may not be untraceable, for more details read the Fess Privacy Policy above.',
          ),
        ],
      ),
    );
  }
}

// ─── Enter Fess button ─────────────────────────────────────────────────────────

class _EnterFessButton extends StatefulWidget {
  final bool canSubmit;
  final bool isCreating;
  final VoidCallback? onTap;

  const _EnterFessButton({
    required this.canSubmit,
    required this.isCreating,
    this.onTap,
  });

  @override
  State<_EnterFessButton> createState() => _EnterFessButtonState();
}

class _EnterFessButtonState extends State<_EnterFessButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.canSubmit && !widget.isCreating
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.canSubmit && !widget.isCreating
          ? (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.canSubmit
                ? LinearGradient(
              colors: [
                AppColors.accentSecondary,
                AppColors.accentPrimary,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            color: widget.canSubmit ? null : const Color(0xFF1A1A28),
          ),
          child: Center(
            child: Text(
              'Enter Fess',
              style: AppTypography.labelLarge.copyWith(
                color: widget.canSubmit
                    ? AppColors.backgroundMain
                    : AppColors.hintText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}