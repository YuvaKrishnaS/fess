import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class DmNotificationPayload {
  final String peerId;
  final String username;
  final String? avatarUrl;
  final String messagePreview;

  const DmNotificationPayload({
    required this.peerId,
    required this.username,
    this.avatarUrl,
    required this.messagePreview,
  });
}

class DmNotificationOverlay {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
      BuildContext context,
      DmNotificationPayload payload,
      ) {
    _timer?.cancel();
    _entry?.remove();

    HapticFeedback.lightImpact();

    _entry = OverlayEntry(
      builder: (ctx) => _DmNotificationBanner(
        payload: payload,
        onTap: () {
          _dismiss();
          context.push(
            '/dm/${payload.peerId}',
            extra: {
              'username': payload.username,
              'avatarUrl': payload.avatarUrl,
            },
          );
        },
        onDismiss: _dismiss,
      ),
    );

    Overlay.of(context).insert(_entry!);

    _timer = Timer(const Duration(seconds: 4), _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }
}

class _DmNotificationBanner extends StatefulWidget {
  final DmNotificationPayload payload;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _DmNotificationBanner({
    required this.payload,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_DmNotificationBanner> createState() =>
      _DmNotificationBannerState();
}

class _DmNotificationBannerState extends State<_DmNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPad + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141420),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF2A2A3A), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _avatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '@${widget.payload.username}',
                            style: AppTypography.bodyMedium.copyWith(
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.payload.messagePreview,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Icon(LucideIcons.x,
                          size: 16, color: AppColors.hintText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final url = widget.payload.avatarUrl;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accentPrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback(),
        )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFF111111),
    child: const Icon(LucideIcons.user,
        size: 16, color: AppColors.hintText),
  );
}