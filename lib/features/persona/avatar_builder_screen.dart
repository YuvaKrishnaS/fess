import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/avatar_options.dart';
import '../../core/models/avatar_config.dart';
import 'providers/avatar_builder_provider.dart';

class AvatarBuilderScreen extends ConsumerWidget {
  const AvatarBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avatarBuilderProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundMain,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onRandomize: () {
                  HapticFeedback.selectionClick();
                  ref.read(avatarBuilderProvider.notifier).randomize();
                },
                onNext: () => context.go('/persona/create'),
              ),
              _AvatarPreview(config: state.config),
              const SizedBox(height: 8),
              _TabBar(
                selected: state.tab,
                onSelect: (tab) {
                  HapticFeedback.selectionClick();
                  ref.read(avatarBuilderProvider.notifier).setTab(tab);
                },
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _TabContent(state: state),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// top bar with randomize + next

class _TopBar extends StatelessWidget {
  final VoidCallback onRandomize;
  final VoidCallback onNext;

  const _TopBar({required this.onRandomize, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build your persona',
                  style: AppTypography.h3.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  'You stay anonymous. Always.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRandomize,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevated,
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 0.5,
                ),
              ),
              child: const Center(
                child: Icon(LucideIcons.shuffle,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onNext();
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    AppColors.accentSecondary,
                    AppColors.accentPrimary,
                  ],
                ),
              ),
              child: Text(
                'Next',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.backgroundMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// avatar preview with gradient ring and glow

class _AvatarPreview extends StatelessWidget {
  final AvatarConfig config;

  const _AvatarPreview({required this.config});

  @override
  Widget build(BuildContext context) {
    final url = config.buildUrl(size: 256);

    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // outer glow
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentSecondary.withOpacity(0.4),
                    blurRadius: 60,
                    spreadRadius: 18,
                  ),
                  BoxShadow(
                    color: AppColors.accentSecondary.withOpacity(0.2),
                    blurRadius: 90,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
            // gradient ring
            Container(
              width: 164,
              height: 164,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentSecondary,
                    AppColors.accentPrimary,
                    AppColors.accentSecondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.backgroundMain,
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: CachedNetworkImage(
                      key: ValueKey(url),
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _AvatarSpinner(),
                      errorWidget: (_, __, ___) => const _AvatarFallback(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarSpinner extends StatelessWidget {
  const _AvatarSpinner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child:
        Icon(LucideIcons.user, size: 48, color: AppColors.textSecondary),
      ),
    );
  }
}

// tab bar — 6 tabs

class _TabBar extends StatelessWidget {
  final AvatarBuilderTab selected;
  final ValueChanged<AvatarBuilderTab> onSelect;

  const _TabBar({required this.selected, required this.onSelect});

  static const _tabs = [
    (AvatarBuilderTab.skin, 'Skin'),
    (AvatarBuilderTab.hair, 'Hair'),
    (AvatarBuilderTab.eyes, 'Eyes'),
    (AvatarBuilderTab.brows, 'Brows'),
    (AvatarBuilderTab.mouth, 'Mouth'),
    (AvatarBuilderTab.extras, 'Extras'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (tab, label) = _tabs[i];
          final isActive = selected == tab;
          return GestureDetector(
            onTap: () => onSelect(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isActive
                    ? AppColors.accentSecondary.withOpacity(0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? AppColors.accentSecondary.withOpacity(0.6)
                      : Colors.white.withOpacity(0.07),
                  width: 0.8,
                ),
              ),
              child: Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: isActive
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// tab content router

class _TabContent extends ConsumerWidget {
  final AvatarBuilderState state;

  const _TabContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(avatarBuilderProvider.notifier);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey(state.tab),
        child: switch (state.tab) {
          AvatarBuilderTab.skin => _SkinTab(
            selected: state.config.skinColor,
            selectedHairColor: state.config.hairColor,
            onSkin: notifier.setSkinColor,
            onHairColor: notifier.setHairColor,
          ),
          AvatarBuilderTab.hair => _PickerTab(
            items: AvatarOptions.hairStyles,
            selected: state.config.hair,
            onSelect: notifier.setHair,
            labelBuilder: _formatLabel,
          ),
          AvatarBuilderTab.eyes => _PickerTab(
            items: AvatarOptions.eyes,
            selected: state.config.eyes,
            onSelect: notifier.setEyes,
            labelBuilder: _formatLabel,
          ),
          AvatarBuilderTab.brows => _PickerTab(
            items: AvatarOptions.eyebrows,
            selected: state.config.eyebrows,
            onSelect: notifier.setEyebrows,
            labelBuilder: _formatLabel,
          ),
          AvatarBuilderTab.mouth => _PickerTab(
            items: AvatarOptions.mouths,
            selected: state.config.mouth,
            onSelect: notifier.setMouth,
            labelBuilder: _formatLabel,
          ),
          AvatarBuilderTab.extras => _ExtrasTab(
            selectedGlasses: state.config.glasses,
            onGlasses: notifier.setGlasses,
          ),
        },
      ),
    );
  }

  static String _formatLabel(String raw) {
    // camelCase or PascalCase → readable words
    // e.g. "shortFlat" → "Short Flat", "bigHair" → "Big Hair"
    final spaced = raw.replaceAllMapped(
      RegExp(r'([A-Z])'),
          (m) => ' ${m.group(0)}',
    );
    final words = spaced.trim().split(' ');
    return words
        .map((w) => w.isEmpty
        ? ''
        : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// skin color + hair color pickers

class _SkinTab extends StatelessWidget {
  final String selected;
  final String selectedHairColor;
  final ValueChanged<String> onSkin;
  final ValueChanged<String> onHairColor;

  const _SkinTab({
    required this.selected,
    required this.selectedHairColor,
    required this.onSkin,
    required this.onHairColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skin tone',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AvatarOptions.skinColors.map((hex) {
              final isSelected = selected == hex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSkin(hex);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hexToColor(hex),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: AppColors.accentPrimary.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Hair colour',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AvatarOptions.hairColors.map((hex) {
              final isSelected = selectedHairColor == hex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onHairColor(hex);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hexToColor(hex),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: AppColors.accentPrimary.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

// generic text-pill picker used for hair, eyes, brows, mouth

class _PickerTab extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;
  final String Function(String) labelBuilder;

  const _PickerTab({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = selected == item;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(item);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isSelected
                    ? AppColors.accentSecondary.withOpacity(0.18)
                    : const Color(0xFF141414),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentSecondary.withOpacity(0.7)
                      : Colors.white.withOpacity(0.07),
                  width: 0.8,
                ),
              ),
              child: Text(
                labelBuilder(item),
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// extras: glasses toggle pills + "None" option

class _ExtrasTab extends StatelessWidget {
  final String? selectedGlasses;
  final ValueChanged<String?> onGlasses;

  const _ExtrasTab({
    required this.selectedGlasses,
    required this.onGlasses,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Glasses / accessories',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // None option
              _glassesPill(
                label: 'None',
                value: null,
                selected: selectedGlasses == null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onGlasses(null);
                },
              ),
              ...AvatarOptions.glasses.map((item) {
                return _glassesPill(
                  label: _format(item),
                  value: item,
                  selected: selectedGlasses == item,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onGlasses(item);
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'More customisation — coming in a future update',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.hintText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassesPill({
    required String label,
    required String? value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.accentSecondary.withOpacity(0.18)
              : const Color(0xFF141414),
          border: Border.all(
            color: selected
                ? AppColors.accentSecondary.withOpacity(0.7)
                : Colors.white.withOpacity(0.07),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  static String _format(String raw) {
    final spaced = raw.replaceAllMapped(
      RegExp(r'([A-Z0-9])'),
          (m) => ' ${m.group(0)}',
    );
    final words = spaced.trim().split(' ');
    return words
        .map((w) =>
    w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}