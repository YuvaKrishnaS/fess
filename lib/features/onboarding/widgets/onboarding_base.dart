import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class OnboardingBase extends StatefulWidget {
  final String imagePath;
  final String title;
  final String? highlightWord;
  final String body;
  final bool enableFloat;
  final double horizontalImagePadding;

  const OnboardingBase({
    super.key,
    required this.imagePath,
    required this.title,
    this.highlightWord,
    required this.body,
    this.enableFloat = true,
    this.horizontalImagePadding = 28,
  });

  @override
  State<OnboardingBase> createState() => _OnboardingBaseState();
}

class _OnboardingBaseState extends State<OnboardingBase>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _floatAnimation = Tween<double>(begin: -9.0, end: 9.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    if (widget.enableFloat) {
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = (widget.highlightWord != null &&
        widget.title.contains(widget.highlightWord!))
        ? widget.title.split(widget.highlightWord!)
        : null;

    return Column(
      children: [
        const SizedBox(height: 8),

        // Image — larger (flex 6)
        Expanded(
          flex: 6,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalImagePadding),
            child: widget.enableFloat
                ? AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: child,
              ),
              child: _buildImage(),
            )
                : _buildImage(),
          ),
        ),

        const SizedBox(height: 24),

        // Text
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.h1,
                    children: parts != null
                        ? [
                      TextSpan(text: parts[0]),
                      TextSpan(
                        text: widget.highlightWord!,
                        style: AppTypography.h1.copyWith(
                          color: AppColors.accentPrimary,
                        ),
                      ),
                      if (parts.length > 1) TextSpan(text: parts[1]),
                    ]
                        : [TextSpan(text: widget.title)],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 380.ms)
                    .slideY(
                    begin: 0.14,
                    end: 0,
                    delay: 180.ms,
                    duration: 380.ms,
                    curve: Curves.easeOut),
                const SizedBox(height: 12),
                Text(
                  widget.body,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.65,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 280.ms, duration: 380.ms)
                    .slideY(
                    begin: 0.1,
                    end: 0,
                    delay: 280.ms,
                    duration: 380.ms,
                    curve: Curves.easeOut),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    return Image.asset(
      widget.imagePath,
      width: double.infinity,
      fit: BoxFit.contain,
    )
        .animate()
        .fadeIn(duration: 550.ms, curve: Curves.easeOut)
        .scale(
      begin: const Offset(0.88, 0.88),
      end: const Offset(1.0, 1.0),
      duration: 550.ms,
      curve: Curves.easeOutBack,
    );
  }
}