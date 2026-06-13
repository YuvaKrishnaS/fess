import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_dialog.dart';
import '../providers/profile_provider.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '2.0.0';
  }
});

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Settings',
                      style: AppTypography.h3.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Section(
                title: 'Persona',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.userCircle2,
                    title: 'Edit Persona',
                    subtitle: 'Update your avatar across the app',
                    onTap: () => context.push('/persona/edit'),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _Section(
                title: 'Privacy & Safety',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.shield,
                    title: 'Blocked Users',
                    subtitle: 'Manage people you blocked',
                    badge: 'Soon',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: LucideIcons.eyeOff,
                    title: 'Privacy Controls',
                    subtitle: 'Control future visibility options',
                    badge: 'Soon',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _Section(
                title: 'Notifications',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.bell,
                    title: 'Push Notifications',
                    subtitle: 'Likes, replies and updates',
                    badge: 'Soon',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _Section(
                title: 'Support',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.badgeHelp,
                    title: 'Help & Feedback',
                    subtitle: 'Report issues and share feedback',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: LucideIcons.fileText,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: LucideIcons.scrollText,
                    title: 'Terms of Service',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _Section(
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.logOut,
                    title: 'Sign Out',
                    titleColor: AppColors.errorLight,
                    iconColor: AppColors.errorLight,
                    onTap: () async {
                      final confirmed = await AppDialog.show(
                        context,
                        title: 'Sign out?',
                        body: 'You will be returned to the login screen immediately.',
                        confirmLabel: 'Sign Out',
                        cancelLabel: 'Stay',
                        isDestructive: true,
                      );

                      if (!confirmed || !context.mounted) return;

                      final signOut = ref.read(signOutProvider);
                      await signOut();

                      if (context.mounted) {
                        context.go('/auth/login');
                      }
                    },
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
                child: Column(
                  children: [
                    Opacity(
                      opacity: 0.18,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 42,
                        height: 42,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Fess',
                      style: AppTypography.h3.copyWith(
                        color: const Color(0xFF3A3A3A),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    versionAsync.when(
                      loading: () => Text(
                        'Version...',
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF474747),
                          fontSize: 11,
                        ),
                      ),
                      error: (_, __) => Text(
                        'Version 2.0.0',
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF474747),
                          fontSize: 11,
                        ),
                      ),
                      data: (version) => Text(
                        'Version $version',
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF474747),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        color: _pressed ? const Color(0xFF181818) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 18,
              color: widget.iconColor ?? AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: AppColors.accentPrimary.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  widget.badge!,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (widget.titleColor == null)
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.hintText,
              ),
          ],
        ),
      ),
    );
  }
}