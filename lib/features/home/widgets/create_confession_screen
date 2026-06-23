import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// A minimal, bold, professional dialog for Fess.
/// Use [AppDialog.show] for all confirmation/alert dialogs in the app.
class AppDialog extends StatelessWidget {
  final String title;
  final String? body;
  final String confirmLabel;
  final String cancelLabel;
  final Color? confirmColor;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmColor,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  /// Show the dialog and return true if user confirmed, false otherwise.
  static Future<bool> show(
      BuildContext context, {
        required String title,
        String? body,
        String confirmLabel = 'Confirm',
        String cancelLabel = 'Cancel',
        bool isDestructive = false,
        Color? confirmColor,
      }) async {
    HapticFeedback.mediumImpact();
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) => AppDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        confirmColor: confirmColor,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final confirmBg = confirmColor ??
        (isDestructive ? AppColors.errorLight : AppColors.accentPrimary);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF252525), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    body!,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: _DialogButton(
                        label: cancelLabel,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onCancel?.call();
                        },
                        bg: const Color(0xFF1E1E1E),
                        fg: AppColors.textSecondary,
                        border: const Color(0xFF2A2A2A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Confirm
                    Expanded(
                      child: _DialogButton(
                        label: confirmLabel,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onConfirm?.call();
                        },
                        bg: confirmBg.withOpacity(0.15),
                        fg: confirmBg,
                        border: confirmBg.withOpacity(0.3),
                        bold: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color bg, fg, border;
  final bool bold;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.bg,
    required this.fg,
    required this.border,
    this.bold = false,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: widget.border, width: 1),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: AppTypography.labelMedium.copyWith(
                fontSize: 14,
                color: widget.fg,
                fontWeight:
                widget.bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}