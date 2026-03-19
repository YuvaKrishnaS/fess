import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/local_storage_service.dart';
import 'providers/auth_provider.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isLoading = false;
  bool _linkSent = false;
  String? _errorMessage;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    final pendingEmail = LocalStorageService.getPendingEmail();
    if (pendingEmail != null) {
      _emailController.text = pendingEmail;
      _linkSent = true;
      _startResendCountdown(initial: 0);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _sendVerificationLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).sendEmailLink(email);

      HapticFeedback.mediumImpact();

      setState(() {
        _linkSent = true;
        _isLoading = false;
        _resendCountdown = 60;
      });

      _startResendCountdown();
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send link. Please try again.';
      if (e.code == 'invalid-continue-uri') {
        message = 'Auth link misconfigured (continue URL). Check Firebase.';
      } else if (e.code == 'unauthorized-continue-uri') {
        message = 'Domain not authorized in Firebase Auth settings.';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _startResendCountdown({int? initial}) {
    if (initial != null) {
      _resendCountdown = initial;
    }
    if (_resendCountdown <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                ),
              ),
              Expanded(
                child: _linkSent ? _buildLinkSentView() : _buildEmailInputView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailInputView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Image.asset(
          'assets/images/logo.png',
          width: 64,
          height: 64,
        ),
        const SizedBox(height: 32),
        Text(
          'Enter your email',
          style: AppTypography.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "We'll send you a magic link so that\nwe can confirm that it's you.",
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: AppTypography.bodyLarge,
          onSubmitted: (_) => _sendVerificationLink(),
          decoration: InputDecoration(
            hintText: 'Email address',
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppColors.textSecondary,
            ),
            errorText: _errorMessage,
            suffixIcon: _emailController.text.isNotEmpty
                ? IconButton(
              onPressed: () {
                _emailController.clear();
                setState(() => _errorMessage = null);
              },
              icon: const Icon(
                Icons.close,
                color: AppColors.textSecondary,
                size: 20,
              ),
            )
                : null,
          ),
          onChanged: (_) {
            if (_errorMessage != null) {
              setState(() => _errorMessage = null);
            }
          },
        ),
        const Spacer(flex: 2),
        CustomButton(
          text: 'Send magic link',
          onPressed: _isLoading ? null : _sendVerificationLink,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Text(
          'By continuing, you confirm that you are authorized to use this email and agree to receive a verification link.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.hintText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLinkSentView() {
    final email = _emailController.text.trim();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.accentPrimary.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: AppColors.accentPrimary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Check your email',
          style: AppTypography.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a magic link to:',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          email,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.accentPrimary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInstructionRow(
                Icons.open_in_new,
                'Tap the link in your email',
              ),
              const SizedBox(height: 12),
              _buildInstructionRow(
                Icons.smartphone,
                'Make sure to open it on this device',
              ),
              const SizedBox(height: 12),
              _buildInstructionRow(
                Icons.timer_outlined,
                'Link expires in 1 hour',
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),
        if (_resendCountdown > 0)
          Text(
            'Resend link in ${_resendCountdown}s',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.hintText,
            ),
          )
        else
          TextButton(
            onPressed: _sendVerificationLink,
            child: Text(
              'Resend magic link',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.accentPrimary,
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _linkSent = false;
              _errorMessage = null;
            });
          },
          child: Text(
            'Use different email',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accentPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
