import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        Duration duration = const Duration(milliseconds: 2500),
      }) {
    // Dismiss any existing snackbar first
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
          icon: LucideIcons.checkCircle,
          accentColor: AppColors.accentPrimary,
        );
      case SnackbarType.error:
        return _SnackbarConfig(
          icon: LucideIcons.alertCircle,
          accentColor: AppColors.errorLight,
        );
      case SnackbarType.info:
        return _SnackbarConfig(
          icon: LucideIcons.info,
          accentColor: AppColors.textSecondary,
        );
    }
  }
}

class _SnackbarConfig {
  final IconData icon;
  final Color accentColor;
  const _SnackbarConfig({required this.icon, required this.accentColor});
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
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnim = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_dismissed) _exit();
    });
  }

  void _exit() async {
    if (_dismissed) return;
    _dismissed = true;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPad + 24,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(opacity: _fadeAnim.value, child: child),
        ),
        child: GestureDetector(
          onTap: _exit,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.07),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left accent bar
                  Container(
                    width: 3,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.config.accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    widget.config.icon,
                    size: 18,
                    color: widget.config.accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        widget.message,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}