import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/avatar_options.dart';
import '../../core/models/avatar_config.dart';
import '../../core/services/firebase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../home/providers/profile_provider.dart';
import 'providers/avatar_builder_provider.dart';
import '../../core/widgets/app_dialog.dart';

final editPersonaSavingProvider = StateProvider<bool>((ref) => false);

class EditPersonaScreen extends ConsumerStatefulWidget {
  const EditPersonaScreen({super.key});

  @override
  ConsumerState<EditPersonaScreen> createState() => _EditPersonaScreenState();
}

class _EditPersonaScreenState extends ConsumerState<EditPersonaScreen> {
  bool _initialized = false;
  bool _dirty = false;

  Future<bool> _handleBack() async {
    if (!_dirty) return true;

    final leave = await AppDialog.show(
      context,
      title: 'Discard changes?',
      body: 'Your updated persona has not been saved yet.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      isDestructive: true,
    );

    return leave;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(avatarBuilderProvider);
    final notifier = ref.read(avatarBuilderProvider.notifier);
    final saving = ref.watch(editPersonaSavingProvider);
    final currentProfile = ref.watch(currentProfileProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canLeave = await _handleBack();
        if (canLeave && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundMain,
        body: SafeArea(
          child: currentProfile.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            error: (_, __) => const Center(
              child: Text(
                'Could not load persona.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return const Center(
                  child: Text(
                    'Could not load persona.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              if (!_initialized) {
                _initialized = true;
                final map = profile.avatarConfig;
                final config = map.isNotEmpty
                    ? AvatarConfig.fromMap(map)
                    : _randomConfig();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  notifier.setFromConfig(config);
                });
              }

              return Column(
                children: [
                  _EditTopBar(
                    saving: saving,
                    onBack: () async {
                      final canLeave = await _handleBack();
                      if (canLeave && context.mounted) context.pop();
                    },
                    onRandomize: () {
                      HapticFeedback.selectionClick();
                      notifier.randomize();
                      setState(() => _dirty = true);
                    },
                    onSave: saving
                        ? null
                        : () async {
                      ref.read(editPersonaSavingProvider.notifier).state = true;
                      try {
                        final anonId =
                        await ref.read(currentAnonIdProvider.future);
                        if (anonId == null || anonId.isEmpty) {
                          throw Exception('Anon ID missing');
                        }

                        await FirebaseService.firestore
                            .collection('public_profiles')
                            .doc(anonId)
                            .set({
                          'avatarConfig': state.config.toMap(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        ref.invalidate(currentProfileProvider);
                        ref.invalidate(profileDataProvider(anonId));
                        ref.invalidate(mySpillsProvider(anonId));
                        ref.invalidate(myTeaProvider(anonId));
                        ref.invalidate(myLikedProvider(anonId));

                        _dirty = false;

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Persona updated'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          context.pop();
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to save persona'),
                            ),
                          );
                        }
                      } finally {
                        ref.read(editPersonaSavingProvider.notifier).state = false;
                      }
                    },
                  ),
                  _AvatarPreview(config: state.config),
                  const SizedBox(height: 8),
                  _EditHint(username: profile.username),
                  const SizedBox(height: 14),
                  _BuilderTabs(
                    selected: state.tab,
                    onSelect: (tab) {
                      HapticFeedback.selectionClick();
                      notifier.setTab(tab);
                    },
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (_) {
                        if (!_dirty) setState(() => _dirty = true);
                        return false;
                      },
                      child: _BuilderTabContent(state: state),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  AvatarConfig _randomConfig() {
    String pick(List<String> list) => list[(DateTime.now().microsecondsSinceEpoch + list.length) % list.length];
    return AvatarConfig(
      skinColor: pick(AvatarOptions.skinColors),
      hair: pick(AvatarOptions.hairStyles),
      hairColor: pick(AvatarOptions.hairColors),
      eyes: pick(AvatarOptions.eyes),
      eyebrows: pick(AvatarOptions.eyebrows),
      mouth: pick(AvatarOptions.mouths),
      glasses: null,
    );
  }
}

class _EditTopBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onRandomize;
  final VoidCallback? onSave;

  const _EditTopBar({
    required this.saving,
    required this.onBack,
    required this.onRandomize,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              LucideIcons.arrowLeft,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit persona',
                  style: AppTypography.h3.copyWith(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Change your avatar, not your identity.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
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
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Icon(
                LucideIcons.shuffle,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSave,
            child: Opacity(
              opacity: onSave == null ? 0.6 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: AppColors.accentPrimary,
                ),
                child: saving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.backgroundMain,
                  ),
                )
                    : Text(
                  'Save',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.backgroundMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _EditHint extends StatelessWidget {
  final String username;
  const _EditHint({required this.username});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '@$username stays the same. Only your avatar changes everywhere in Fess.',
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

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
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentPrimary.withOpacity(0.18),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPrimary.withOpacity(0.5),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Icon(
                      LucideIcons.user,
                      color: AppColors.textSecondary,
                      size: 40,
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

class _BuilderTabs extends StatelessWidget {
  final AvatarBuilderTab selected;
  final ValueChanged<AvatarBuilderTab> onSelect;

  const _BuilderTabs({
    required this.selected,
    required this.onSelect,
  });

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
          final active = selected == tab;
          return GestureDetector(
            onTap: () => onSelect(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? AppColors.accentPrimary.withOpacity(0.14)
                    : const Color(0xFF141414),
                border: Border.all(
                  color: active
                      ? AppColors.accentPrimary.withOpacity(0.35)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 12,
                  color: active
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BuilderTabContent extends ConsumerWidget {
  final AvatarBuilderState state;
  const _BuilderTabContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(avatarBuilderProvider.notifier);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
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
          ),
          AvatarBuilderTab.eyes => _PickerTab(
            items: AvatarOptions.eyes,
            selected: state.config.eyes,
            onSelect: notifier.setEyes,
          ),
          AvatarBuilderTab.brows => _PickerTab(
            items: AvatarOptions.eyebrows,
            selected: state.config.eyebrows,
            onSelect: notifier.setEyebrows,
          ),
          AvatarBuilderTab.mouth => _PickerTab(
            items: AvatarOptions.mouths,
            selected: state.config.mouth,
            onSelect: notifier.setMouth,
          ),
          AvatarBuilderTab.extras => _ExtrasTab(
            selectedGlasses: state.config.glasses,
            onGlasses: notifier.setGlasses,
          ),
        },
      ),
    );
  }
}

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
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AvatarOptions.skinColors.map((hex) {
              final active = selected == hex;
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
                      color: active
                          ? AppColors.accentPrimary
                          : Colors.transparent,
                      width: 2.5,
                    ),
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
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AvatarOptions.hairColors.map((hex) {
              final active = selectedHairColor == hex;
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
                      color: active
                          ? AppColors.accentPrimary
                          : Colors.transparent,
                      width: 2.5,
                    ),
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

class _PickerTab extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PickerTab({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final active = selected == item;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(item);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? AppColors.accentPrimary.withOpacity(0.14)
                    : const Color(0xFF141414),
                border: Border.all(
                  color: active
                      ? AppColors.accentPrimary.withOpacity(0.35)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Text(
                _format(item),
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: active
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _format(String raw) {
    final spaced = raw.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}');
    final words = spaced.trim().split(' ');
    return words
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _ExtrasTab extends StatelessWidget {
  final String? selectedGlasses;
  final ValueChanged<String?> onGlasses;

  const _ExtrasTab({
    required this.selectedGlasses,
    required this.onGlasses,
  });

  @override
  Widget build(BuildContext context) {
    final items = [null, ...AvatarOptions.glasses];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final label = item == null ? 'None' : _format(item);
          final active = selectedGlasses == item;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onGlasses(item);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? AppColors.accentPrimary.withOpacity(0.14)
                    : const Color(0xFF141414),
                border: Border.all(
                  color: active
                      ? AppColors.accentPrimary.withOpacity(0.35)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: active
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _format(String raw) {
    final spaced = raw.replaceAllMapped(RegExp(r'([A-Z0-9])'), (m) => ' ${m.group(0)}');
    final words = spaced.trim().split(' ');
    return words
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}