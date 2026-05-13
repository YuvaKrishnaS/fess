import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/avatar_options.dart';
import '../../../core/models/avatar_config.dart';

enum AvatarBuilderTab { skin, hair, eyes, brows, mouth, extras }

class AvatarBuilderState {
  final AvatarConfig config;
  final AvatarBuilderTab tab;

  const AvatarBuilderState({
    this.config = AvatarConfig.initial,
    this.tab = AvatarBuilderTab.skin,
  });

  AvatarBuilderState copyWith({AvatarConfig? config, AvatarBuilderTab? tab}) {
    return AvatarBuilderState(
      config: config ?? this.config,
      tab: tab ?? this.tab,
    );
  }
}

class AvatarBuilderNotifier extends Notifier<AvatarBuilderState> {
  final _rng = Random();

  @override
  AvatarBuilderState build() => const AvatarBuilderState();

  void setTab(AvatarBuilderTab tab) {
    state = state.copyWith(tab: tab);
  }

  void setSkinColor(String value) {
    state = state.copyWith(config: state.config.copyWith(skinColor: value));
  }

  void setHair(String value) {
    state = state.copyWith(config: state.config.copyWith(hair: value));
  }

  void setHairColor(String value) {
    state = state.copyWith(config: state.config.copyWith(hairColor: value));
  }

  void setEyes(String value) {
    state = state.copyWith(config: state.config.copyWith(eyes: value));
  }

  void setEyebrows(String value) {
    state = state.copyWith(config: state.config.copyWith(eyebrows: value));
  }

  void setMouth(String value) {
    state = state.copyWith(config: state.config.copyWith(mouth: value));
  }

  void setGlasses(String? value) {
    state = state.copyWith(
      config: value == null
          ? state.config.copyWith(clearGlasses: true)
          : state.config.copyWith(glasses: value),
    );
  }

  void setClothing(String value) {
    state = state.copyWith(config: state.config.copyWith(hair: value));
  }

  void randomize() {
    String pick(List<String> list) => list[_rng.nextInt(list.length)];

    final config = AvatarConfig(
      skinColor: pick(AvatarOptions.skinColors),
      hair: pick(AvatarOptions.hairStyles),
      hairColor: pick(AvatarOptions.hairColors),
      eyes: pick(AvatarOptions.eyes),
      eyebrows: pick(AvatarOptions.eyebrows),
      mouth: pick(AvatarOptions.mouths),
      glasses: _rng.nextBool() ? pick(AvatarOptions.glasses) : null,
    );

    state = state.copyWith(config: config);
  }
}

final avatarBuilderProvider =
NotifierProvider<AvatarBuilderNotifier, AvatarBuilderState>(
    AvatarBuilderNotifier.new);