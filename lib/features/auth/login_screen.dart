import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoadingGoogle = false;
  String? _errorMessage;

  Future<void> _handleMetaTap() async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Meta login coming soon',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.elevated,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    if (result == SignInResult.success) {
      HapticFeedback.mediumImpact();
      final anonId = await authService.getAnonId();
      if (!mounted) return;
      // TODO M3: if anonId == null → context.go('/persona/create')
      context.go('/home');
    } else if (result == SignInResult.cancelled) {
      setState(() => _isLoadingGoogle = false);
    } else {
      setState(() {
        _isLoadingGoogle = false;
        _errorMessage = 'Sign-in failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: Stack(
        children: [
          // Glow top-right
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentSecondary.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  Image.asset('assets/images/logo.png', width: 72, height: 72)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'You stay anonymous.\nAlways.',
                    style: AppTypography.h2.copyWith(height: 1.3),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 400.ms)
                      .slideY(
                      begin: 0.1,
                      end: 0,
                      delay: 150.ms,
                      duration: 400.ms),

                  const SizedBox(height: 14),

                  Text(
                    'No name. No photo. No trace.\nJust your thoughts, freely.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

                  const Spacer(flex: 2),

                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.errorLight.withOpacity(0.35)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.errorLight),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Primary: Meta
                  _MetaButton(
                    onPressed: _handleMetaTap,
                  )
                      .animate()
                      .fadeIn(delay: 350.ms, duration: 400.ms)
                      .slideY(
                      begin: 0.1,
                      end: 0,
                      delay: 350.ms,
                      duration: 400.ms),

                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: AppColors.elevated, thickness: 1)),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'or',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.hintText),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: AppColors.elevated, thickness: 1)),
                    ],
                  ).animate().fadeIn(delay: 420.ms, duration: 300.ms),

                  const SizedBox(height: 16),

                  // Secondary: Google
                  _SecondaryButton(
                    label: 'Continue with Google',
                    iconAsset: 'assets/images/icons/google_logo.png',
                    onPressed: _isLoadingGoogle ? null : _handleGoogleSignIn,
                    isLoading: _isLoadingGoogle,
                  ).animate().fadeIn(delay: 460.ms, duration: 400.ms),

                  const Spacer(flex: 1),

                  Text(
                    'Your real identity is never visible to other users.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.hintText,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 550.ms, duration: 400.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Meta button ──────────────────────────────────────────────────────────────
class _MetaButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _MetaButton({required this.onPressed});

  @override
  State<_MetaButton> createState() => _MetaButtonState();
}

class _MetaButtonState extends State<_MetaButton> {
  bool _pressed = false;

  // Meta brand blue
  static const Color _metaBlue = Color(0xFF0082FB);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _metaBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icons/meta_logo.png',
                width: 22,
                height: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Meta',
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Secondary button (Google) ─────────────────────────────────────────────────
class _SecondaryButton extends StatefulWidget {
  final String label;
  final String iconAsset;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SecondaryButton({
    required this.label,
    required this.iconAsset,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.elevated, width: 1.5),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentPrimary),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(widget.iconAsset,
                    width: 20, height: 20),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}