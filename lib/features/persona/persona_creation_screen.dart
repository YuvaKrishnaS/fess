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
import '../../core/constants/username_words.dart';
import '../../core/widgets/fess_snackbar.dart';
import '../persona/providers/avatar_builder_provider.dart';
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
  void dispose() {
    _usernameController.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  void _generateRandomUsername() {
    final adj =
    UsernameWords.adjectives[_random.nextInt(UsernameWords.adjectives.length)];
    final noun =
    UsernameWords.nouns[_random.nextInt(UsernameWords.nouns.length)];
    final num = 100 + _random.nextInt(900); // 100–999
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
    final avatarUrl =
    ref.watch(avatarBuilderProvider).config.buildUrl(size: 256);

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

                  // Tietle
                  const _TitleSection()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.08, end: 0, duration: 400.ms),

                  const SizedBox(height: 36),

                  // avatar
                  _StaticAvatar(url: avatarUrl, isCreating: state.isCreating)
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 500.ms)
                      .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.0, 1.0),
                    delay: 100.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),

                  // flexible gap — compresses naturally when keyboard opens
                  const Spacer(),

                  // username field
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
                  ).animate().fadeIn(delay: 240.ms),

                  const SizedBox(height: 24),

                  // terms
                  const _TermsText()
                      .animate()
                      .fadeIn(delay: 280.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // ── Enter Fess button ──────────────────────────────────
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

// title

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

// static avatar

class _StaticAvatar extends StatelessWidget {
  final String url;
  final bool isCreating;

  const _StaticAvatar({required this.url, required this.isCreating});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow — reduced
            Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x667B2FBE),
                    blurRadius: 60,
                    spreadRadius: 18,
                  ),
                  BoxShadow(
                    color: Color(0x337B2FBE),
                    blurRadius: 90,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),

            // Gradient ring
            Container(
              width: 192,
              height: 192,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7B2FBE),
                    Color(0xFF00BFA5),
                    Color(0xFF7B2FBE),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF07070F),
                ),
                clipBehavior: Clip.antiAlias,
                child: isCreating
                    ? const _CreatingOverlay()
                    : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00BFA5),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    LucideIcons.user,
                    size: 56,
                    color: Color(0xFF555566),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Edit avatar button — only visible when not creating
        if (!isCreating)
          GestureDetector(
            onTap: () => context.push('/avatar-builder'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00BFA5).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.pencil,
                    size: 12,
                    color: Color(0xFF00BFA5),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Edit Avatar',
                    style: AppTypography.bodySmall.copyWith(
                      color: const Color(0xFF00BFA5),
                      fontWeight: FontWeight.w500,
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

// creating overlay


class _CreatingOverlay extends StatelessWidget {
  const _CreatingOverlay();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Creating...',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// username field

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

              // Shuffle icon — tap to generate random name
              GestureDetector(
                onTap: onShuffleTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                  child: Icon(
                    LucideIcons.shuffle,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Input
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

              // Status indicator
              _StatusIndicator(status: status, length: length),

              const SizedBox(width: 14),
            ],
          ),
        ),

        // Inline error message
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

// status indicator inside field

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
        return Icon(LucideIcons.xCircle,
            size: 18, color: AppColors.errorLight);
      case UsernameStatus.invalid:
        return Icon(LucideIcons.alertCircle,
            size: 18, color: AppColors.errorLight);
      case UsernameStatus.idle:
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

// terms text

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

// enter fess button

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
                ? const LinearGradient(
              colors: [Color(0xFF7B2FBE), Color(0xFF00BFA5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            color: widget.canSubmit ? null : const Color(0xFF1A1A28),
          ),
          child: Center(
            child: widget.isCreating
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(
              'Enter Fess',
              style: AppTypography.labelLarge.copyWith(
                color: widget.canSubmit
                    ? Colors.white
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