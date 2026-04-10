import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

enum SnackbarType { info, success, error }

class FessSnackbar {
  FessSnackbar._();

  static void show(
      BuildContext context,
      String message, {
        SnackbarType type = SnackbarType.info,
        Duration duration = const Duration(seconds: 2),
      }) {
    final config = _getConfig(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                config.icon,
                size: 16,
                color: config.iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.elevated,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: config.borderColor,
              width: 0.5,
            ),
          ),
          elevation: 0,
        ),
      );
  }

  static _SnackbarConfig _getConfig(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarConfig(
          icon: LucideIcons.checkCircle,
          iconColor: AppColors.accentPrimary,
          borderColor: AppColors.accentPrimary.withOpacity(0.3),
        );
      case SnackbarType.error:
        return _SnackbarConfig(
          icon: LucideIcons.alertCircle,
          iconColor: AppColors.errorLight,
          borderColor: AppColors.errorLight.withOpacity(0.3),
        );
      case SnackbarType.info:
        return _SnackbarConfig(
          icon: LucideIcons.info,
          iconColor: AppColors.textSecondary,
          borderColor: AppColors.elevated,
        );
    }
  }
}

class _SnackbarConfig {
  final IconData icon;
  final Color iconColor;
  final Color borderColor;

  const _SnackbarConfig({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
  });
}