import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

enum SnackbarType { info, success, error }

class FessSnackbar {
  FessSnackbar._();

  static OverlayEntry? _currentEntry;

  static void show(
      BuildContext context,
      String message, {
        SnackbarType type = SnackbarType.info,
        Duration duration = const Duration(milliseconds: 2800),
      }) {
    _dismiss();
    HapticFeedback.lightImpact();

    final overlay = Overlay.of(context, rootOverlay: true);
    final config = _config(type);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FessSnackbarWidget(
        message: message,
        config: config,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _dismiss() {
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }

  static _SnackbarConfig _config(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarConfig(
          icon: LucideIcons.checkCircle2,
          accentColor: const Color(0xFF1DE9B6),
          bgColor: const Color(0xFF0D1F1B),
          borderColor: const Color(0xFF1DE9B6),
        );
      case SnackbarType.error:
        return _SnackbarConfig(
          icon: LucideIcons.xCircle,
          accentColor: AppColors.errorLight,
          bgColor: const Color(0xFF1F0D0D),
          borderColor: AppColors.errorLight,
        );
      case SnackbarType.info:
        return _SnackbarConfig(
          icon: LucideIcons.info,
          accentColor: AppColors.textSecondary,
          bgColor: const Color(0xFF141414),
          borderColor: const Color(0xFF2A2A2A),
        );
    }
  }
}

class _SnackbarConfig {
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  const _SnackbarConfig({
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });
}

class _FessSnackbarWidget extends StatefulWidget {
  final String message;
  final _SnackbarConfig config;
  final Duration duration;
  final VoidCallback onDismiss;

  const _FessSnackbarWidget({
    required this.message,
    required this.config,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_FessSnackbarWidget> createState() => _FessSnackbarWidgetState();
}

class _FessSnackbarWidgetState extends State<_FessSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnim = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _ctrl.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_dismissed) _exit();
    });
  }

  void _exit() async {
    if (_dismissed) return;
    _dismissed = true;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPad + 28,
      left: 24,
      right: 24,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(opacity: _fadeAnim.value, child: child),
        ),
        child: GestureDetector(
          onTap: _exit,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: widget.config.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.config.borderColor.withOpacity(0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.config.icon,
                    size: 16,
                    color: widget.config.accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}