import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/avatar_data.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // preload first few avatars so there's no flicker on first load
    for (int i = 0; i < 3; i++) {
      precacheImage(
        NetworkImage(AvatarData.urlForSeed(AvatarData.seedAt(i))),
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
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      // persona creation is required, block back navigation
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundMain,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: _usernameFocus.unfocus,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
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
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.0, 1.0),
                        delay: 100.ms,
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),

                      const Spacer(),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _UsernameField(
                          controller: _usernameController,
                          focusNode: _usernameFocus,
                          status: state.usernameStatus,
                          length: state.username.length,
                          onChanged:
                          ref.read(personaProvider.notifier).onUsernameChanged,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .slideY(
                          begin: 0.08,
                          end: 0,
                          delay: 200.ms,
                          duration: 400.ms),

                      const SizedBox(height: 8),

                      Text(
                        'Keep it as anonymous as possible!',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.hintText,
                        ),
                      ).animate().fadeIn(delay: 260.ms, duration: 400.ms),

                      const SizedBox(height: 28),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _TermsText(),
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: 28),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _EnterFessButton(
                          canSubmit: state.canSubmit,
                          isCreating: state.isCreating,
                          onTap: state.canSubmit ? _handleSubmit : null,
                        ),
                      ).animate().fadeIn(delay: 340.ms, duration: 400.ms),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Title
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

// Avatar Carousel
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

class _AvatarCarouselState extends State<_AvatarCarousel>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

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

    return SizedBox(
      height: 260,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowButton(
            icon: LucideIcons.chevronLeft,
            onTap: widget.isCreating ? null : _handlePrevious,
          ),

          const SizedBox(width: 16),

          // glow + circle + avatar — all stacked
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (widget.isCreating) return;
              final v = details.primaryVelocity ?? 0;
              if (v < -200) _handleNext();
              if (v > 200) _handlePrevious();
            },
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) => Transform.scale(
                scale: _glowAnim.value,
                child: child,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // purple radial glow behind the circle
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentSecondary.withOpacity(0.50),
                          AppColors.accentSecondary.withOpacity(0.16),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // gradient border ring
                  Container(
                    width: 190,
                    height: 190,
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
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, animation) {
                          final offset = Tween<Offset>(
                            begin: Offset(_isForward ? 0.4 : -0.4, 0),
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
          ),

          const SizedBox(width: 16),

          _ArrowButton(
            icon: LucideIcons.chevronRight,
            onTap: widget.isCreating ? null : _handleNext,
          ),
        ],
      ),
    );
  }
}

// Arrow button
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
          opacity: widget.onTap == null ? 0.25 : (_pressed ? 0.5 : 1.0),
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.elevated.withOpacity(0.5),
              border: Border.all(
                color: AppColors.elevated,
                width: 0.5,
              ),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Avtar Image with loading + Image state
class _AvatarImage extends StatelessWidget {
  final String url;

  const _AvatarImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.accentPrimary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            LucideIcons.user,
            size: 48,
            color: AppColors.textSecondary,
          ),
        );
      },
    );
  }
}

// Creating user OVerlay
class _CreatingOverlay extends StatelessWidget {
  const _CreatingOverlay();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 26,
          height: 26,
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

// Username field
class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final UsernameStatus status;
  final int length;
  final ValueChanged<String> onChanged;

  const _UsernameField({
    required this.controller,
    required this.focusNode,
    required this.status,
    required this.length,
    required this.onChanged,
  });

  Color _borderColor() {
    switch (status) {
      case UsernameStatus.available:
        return AppColors.accentPrimary;
      case UsernameStatus.taken:
      case UsernameStatus.invalid:
        return AppColors.errorLight;
      default:
        return AppColors.elevated;
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
            color: AppColors.elevated.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _borderColor(),
              width: _hasError || status == UsernameStatus.available ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                LucideIcons.dice6,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
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
                    hintText: 'Your anonymous name',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.hintText,
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusIndicator(status: status, length: length),
              const SizedBox(width: 16),
            ],
          ),
        ),

        // validation message shown below field
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _hasError
              ? Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              status == UsernameStatus.taken
                  ? 'This name is already taken'
                  : 'Only letters, numbers and _ allowed. Min 3 characters.',
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

// Status Indicator inside the field
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
        return Icon(
          LucideIcons.checkCircle2,
          size: 18,
          color: AppColors.accentPrimary,
        );
      case UsernameStatus.taken:
        return Icon(
          LucideIcons.xCircle,
          size: 18,
          color: AppColors.errorLight,
        );
      case UsernameStatus.invalid:
        return Icon(
          LucideIcons.alertCircle,
          size: 18,
          color: AppColors.errorLight,
        );
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

// ─── Terms & Privacy text ──────────────────────────────────────────────────────
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
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // gradient when ready, flat grey when not
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
            color: widget.canSubmit ? null : AppColors.elevated,
          ),
          child: Center(
            child: Text(
              'Enter Fess',
              style: AppTypography.labelLarge.copyWith(
                color: widget.canSubmit
                    ? AppColors.backgroundMain
                    : AppColors.hintText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}