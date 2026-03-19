import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/custom_button.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    if (result == SignInResult.success) {
      HapticFeedback.mediumImpact();

      // Check if user already has a persona
      final anonId = await authService.getAnonId();

      if (!mounted) return;

      if (anonId != null) {
        // Returning user with persona → home
        context.go('/home');
      } else {
        // New user → create persona
        context.go('/persona/create');
      }
    } else if (result == SignInResult.cancelled) {
      setState(() => _isLoading = false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign-in failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 72,
                height: 72,
              ),

              const SizedBox(height: 32),

              // Headline
              Text(
                'You stay anonymous.\nAlways.',
                style: AppTypography.h2.copyWith(height: 1.3),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Sub-headline
              Text(
                'We verify your identity once to keep Fess safe. Your name, photo, and social profile are never shared — ever.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.errorLight.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.errorLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Google sign-in button
              _SocialButton(
                label: 'Continue with Google',
                icon: _GoogleIcon(),
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 12),

              // More providers coming note
              Text(
                'More sign-in options coming soon',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.hintText,
                ),
              ),

              const Spacer(flex: 1),

              // Anonymity disclaimer
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy. Your real identity is never visible to other users.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.hintText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Social button ────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SocialButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.elevated,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(
            color: AppColors.elevated,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.accentPrimary,
            ),
          ),
        )
            : Row(
          children: [
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Google icon (painted, no asset needed) ───────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue arc
    canvas.drawArc(
      rect,
      -0.3,
      4.0,
      false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );

    // Red arc
    canvas.drawArc(
      rect,
      3.7,
      1.0,
      false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );

    // Yellow arc
    canvas.drawArc(
      rect,
      2.3,
      1.4,
      false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );

    // Green arc
    canvas.drawArc(
      rect,
      0.7,
      1.6,
      false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );

    // White center cut for the G
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()..color = AppColors.elevated,
    );

    // G horizontal bar (right side white block)
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - size.height * 0.1,
        radius * 0.75,
        size.height * 0.2,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
