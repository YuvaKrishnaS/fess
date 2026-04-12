import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/avatar_options.dart';
import 'providers/avatar_builder_provider.dart';

class AvatarBuilderScreen extends ConsumerWidget {
  const AvatarBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avatarBuilderProvider);
    final notifier = ref.read(avatarBuilderProvider.notifier);
    final canPop = Navigator.canPop(context);

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: AppColors.backgroundMain,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                canGoBack: canPop,
                onBack: () => context.pop(),
                onRandomize: () {
                  HapticFeedback.lightImpact();
                  notifier.randomize();
                },
              ),
              Expanded(
                child: _AvatarPreview(url: state.config.buildUrl()),
              ),
              _CategoryTabs(
                selected: state.tab,
                onTap: (t) {
                  HapticFeedback.selectionClick();
                  notifier.setTab(t);
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 164,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(state.tab),
                    child: _OptionsPanel(state: state, notifier: notifier),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _DoneButton(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/persona/create');
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// header

class _Header extends StatelessWidget {
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onRandomize;

  const _Header({
    required this.canGoBack,
    required this.onBack,
    required this.onRandomize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (canGoBack)
            IconButton(
              onPressed: onBack,
              icon: const Icon(LucideIcons.arrowLeft),
              color: AppColors.textSecondary,
              iconSize: 22,
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          Column(
            children: [
              Text(
                'Build Your Avatar',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'make it yours',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onRandomize,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Icon(
                LucideIcons.shuffle,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// avatar preview
class _AvatarPreview extends StatelessWidget {
  final String url;
  const _AvatarPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow (reduced)
          Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x667B2FBE),
                  blurRadius: 60,
                  spreadRadius: 18,
                ),
                BoxShadow(
                  color: Color(0x337B2FBE),
                  blurRadius: 90,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),

          // Gradient ring
          Container(
            width: 196,
            height: 196,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7B2FBE),
                  Color(0xFF00BFA5),
                  Color(0xFF7B2FBE),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF07070F),
              ),
              clipBehavior: Clip.antiAlias,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: CachedNetworkImage(
                  key: ValueKey(url),
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00BFA5),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    LucideIcons.user,
                    size: 56,
                    color: Color(0xFF555566),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// category tables
class _TabMeta {
  final AvatarBuilderTab tab;
  final IconData icon;
  final String label;
  const _TabMeta(this.tab, this.icon, this.label);
}

class _CategoryTabs extends StatelessWidget {
  final AvatarBuilderTab selected;
  final ValueChanged<AvatarBuilderTab> onTap;

  const _CategoryTabs({required this.selected, required this.onTap});

  static final _tabs = [
    _TabMeta(AvatarBuilderTab.skin, LucideIcons.palette, 'Skin'),
    _TabMeta(AvatarBuilderTab.hair, LucideIcons.scissors, 'Hair'),
    _TabMeta(AvatarBuilderTab.eyes, LucideIcons.eye, 'Eyes'),
    _TabMeta(AvatarBuilderTab.brows, LucideIcons.alignJustify, 'Brows'),
    _TabMeta(AvatarBuilderTab.mouth, LucideIcons.smile, 'Mouth'),
    _TabMeta(AvatarBuilderTab.glasses, LucideIcons.scan, 'Glasses'),
    _TabMeta(AvatarBuilderTab.extras, LucideIcons.star, 'Extras'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final meta = _tabs[i];
          final isSelected = selected == meta.tab;

          return GestureDetector(
            onTap: () => onTap(meta.tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00BFA5).withOpacity(0.12)
                    : AppColors.elevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00BFA5)
                      : AppColors.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    meta.icon,
                    size: 14,
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    meta.label,
                    style: AppTypography.labelSmall.copyWith(
                      color: isSelected
                          ? const Color(0xFF00BFA5)
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Option panel

class _OptionsPanel extends StatelessWidget {
  final AvatarBuilderState state;
  final AvatarBuilderNotifier notifier;

  const _OptionsPanel({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    switch (state.tab) {
      case AvatarBuilderTab.skin:
        return _ColorSwatchRow(
          colors: AvatarOptions.skinColors,
          selected: state.config.skinColor,
          onSelect: notifier.setSkinColor,
        );
      case AvatarBuilderTab.hair:
        return _HairPanel(
          selectedStyle: state.config.hair,
          selectedColor: state.config.hairColor,
          onStyleSelect: notifier.setHairStyle,
          onColorSelect: notifier.setHairColor,
        );
      case AvatarBuilderTab.eyes:
        return _StyleTileRow(
          styles: AvatarOptions.eyeStyles,
          selected: state.config.eyes,
          onSelect: notifier.setEyes,
        );
      case AvatarBuilderTab.brows:
        return _StyleTileRow(
          styles: AvatarOptions.eyebrowStyles,
          selected: state.config.eyebrows,
          onSelect: notifier.setBrows,
        );
      case AvatarBuilderTab.mouth:
        return _StyleTileRow(
          styles: AvatarOptions.mouthStyles,
          selected: state.config.mouth,
          onSelect: notifier.setMouth,
        );
      case AvatarBuilderTab.glasses:
        return _NullableStylePanel(
          styles: AvatarOptions.glassesStyles,
          selected: state.config.glasses,
          icon: LucideIcons.scan,
          onSelect: notifier.setGlasses,
        );
      case AvatarBuilderTab.extras:
        return _ExtrasPanel(
          selectedEarrings: state.config.earrings,
          activeFeatures: state.config.features,
          onEarringsSelect: notifier.setEarrings,
          onFeatureToggle: notifier.toggleFeature,
        );
    }
  }
}

// ─── Color swatch row (skin + hair colors) ────────────────────────────────────

class _ColorSwatchRow extends StatelessWidget {
  final List<String> colors;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ColorSwatchRow({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: colors.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final hex = colors[i];
            final isSelected = selected == hex;
            final color = Color(int.parse('FF$hex', radix: 16));

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(hex);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: const Color(0xFF00BFA5).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: Colors.white,
                )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Hair panel (style tiles + color swatches) ────────────────────────────────

class _HairPanel extends StatelessWidget {
  final String selectedStyle;
  final String selectedColor;
  final ValueChanged<String> onStyleSelect;
  final ValueChanged<String> onColorSelect;

  const _HairPanel({
    required this.selectedStyle,
    required this.selectedColor,
    required this.onStyleSelect,
    required this.onColorSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('STYLE'),
        SizedBox(
          height: 72,
          child: _StyleTileRow(
            styles: AvatarOptions.hairStyles,
            selected: selectedStyle,
            onSelect: onStyleSelect,
          ),
        ),
        _sectionLabel('COLOUR', topPadding: 8),
        SizedBox(
          height: 52,
          child: _ColorSwatchRow(
            colors: AvatarOptions.hairColors,
            selected: selectedColor,
            onSelect: onColorSelect,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, {double topPadding = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: 20, bottom: 4, top: topPadding),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF666680),
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Generic style tile row ───────────────────────────────────────────────────

class _StyleTileRow extends StatelessWidget {
  final List<String> styles;
  final String selected;
  final ValueChanged<String> onSelect;

  const _StyleTileRow({
    required this.styles,
    required this.selected,
    required this.onSelect,
  });

  String _label(String value) {
    if (value.startsWith('short')) return 'S${value.substring(5)}';
    if (value.startsWith('long')) return 'L${value.substring(4)}';
    if (value.startsWith('variant')) return value.substring(7);
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: styles.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final style = styles[i];
        final isSelected = selected == style;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(style);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00BFA5).withOpacity(0.12)
                  : AppColors.elevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00BFA5)
                    : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                _label(style),
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF00BFA5)
                      : AppColors.textSecondary,
                  fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Nullable style panel (glasses + earrings) ────────────────────────────────

class _NullableStylePanel extends StatelessWidget {
  final List<String> styles;
  final String? selected;
  final IconData icon;
  final ValueChanged<String?> onSelect;

  const _NullableStylePanel({
    required this.styles,
    required this.selected,
    required this.icon,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <String?>[null, ...styles];

    return Center(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final style = items[i];
          final isSelected = selected == style;
          final label = style == null ? 'None' : style.substring(7);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(style);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 62,
              height: 68,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00BFA5).withOpacity(0.12)
                    : AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00BFA5)
                      : AppColors.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    style == null ? LucideIcons.x : icon,
                    size: 20,
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF00BFA5)
                          : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Extras panel (earrings + feature toggles) ───────────────────────────────

class _ExtrasPanel extends StatelessWidget {
  final String? selectedEarrings;
  final List<String> activeFeatures;
  final ValueChanged<String?> onEarringsSelect;
  final ValueChanged<String> onFeatureToggle;

  const _ExtrasPanel({
    required this.selectedEarrings,
    required this.activeFeatures,
    required this.onEarringsSelect,
    required this.onFeatureToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 4),
          child: Text(
            'EARRINGS',
            style: TextStyle(
              color: Color(0xFF666680),
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: _NullableStylePanel(
            styles: AvatarOptions.earringStyles,
            selected: selectedEarrings,
            icon: LucideIcons.circle,
            onSelect: onEarringsSelect,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20, top: 8, bottom: 6),
          child: Text(
            'FEATURES',
            style: TextStyle(
              color: Color(0xFF666680),
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: AvatarOptions.featureStyles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final feature = AvatarOptions.featureStyles[i];
              final isActive = activeFeatures.contains(feature);
              final label =
                  feature[0].toUpperCase() + feature.substring(1);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onFeatureToggle(feature);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF00BFA5).withOpacity(0.12)
                        : AppColors.elevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF00BFA5)
                          : AppColors.border,
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF00BFA5)
                          : AppColors.textSecondary,
                      fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Done button ─────────────────────────────────────────────────────────────

class _DoneButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DoneButton({required this.onTap});

  @override
  State<_DoneButton> createState() => _DoneButtonState();
}

class _DoneButtonState extends State<_DoneButton> {
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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF7B2FBE), Color(0xFF00BFA5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Done',
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.arrowRight,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}