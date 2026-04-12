import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/avatar_options.dart';
import '../../../core/models/avatar_config.dart';

enum AvatarBuilderTab {
  skin,
  hair,
  eyes,
  brows,
  mouth,
  glasses,
  extras,
}

class AvatarBuilderState {
  final AvatarConfig config;
  final AvatarBuilderTab tab;

  const AvatarBuilderState({
    this.config = AvatarConfig.initial,
    this.tab = AvatarBuilderTab.skin,
  });

  AvatarBuilderState copyWith({
    AvatarConfig? config,
    AvatarBuilderTab? tab,
  }) {
    return AvatarBuilderState(
      config: config ?? this.config,
      tab: tab ?? this.tab,
    );
  }
}

class AvatarBuilderNotifier extends Notifier<AvatarBuilderState> {
  final _random = Random();

  @override
  AvatarBuilderState build() {
    return const AvatarBuilderState();
  }

  void setTab(AvatarBuilderTab tab) {
    state = state.copyWith(tab: tab);
  }

  void setSkinColor(String value) {
    state = state.copyWith(
      config: state.config.copyWith(skinColor: value),
    );
  }

  void setHairStyle(String value) {
    state = state.copyWith(
      config: state.config.copyWith(hair: value),
    );
  }

  void setHairColor(String value) {
    state = state.copyWith(
      config: state.config.copyWith(hairColor: value),
    );
  }

  void setEyes(String value) {
    state = state.copyWith(
      config: state.config.copyWith(eyes: value),
    );
  }

  void setBrows(String value) {
    state = state.copyWith(
      config: state.config.copyWith(eyebrows: value),
    );
  }

  void setMouth(String value) {
    state = state.copyWith(
      config: state.config.copyWith(mouth: value),
    );
  }

  void setGlasses(String? value) {
    state = state.copyWith(
      config: value == null
          ? state.config.copyWith(clearGlasses: true)
          : state.config.copyWith(glasses: value),
    );
  }

  void setEarrings(String? value) {
    state = state.copyWith(
      config: value == null
          ? state.config.copyWith(clearEarrings: true)
          : state.config.copyWith(earrings: value),
    );
  }

  void toggleFeature(String value) {
    final current = [...state.config.features];
    if (current.contains(value)) {
      current.remove(value);
    } else {
      current.add(value);
    }

    state = state.copyWith(
      config: state.config.copyWith(features: current),
    );
  }

  void randomize() {
    state = state.copyWith(
      config: AvatarConfig(
        skinColor: AvatarOptions.skinColors[
        _random.nextInt(AvatarOptions.skinColors.length)],
        hair: AvatarOptions.hairStyles[
        _random.nextInt(AvatarOptions.hairStyles.length)],
        hairColor: AvatarOptions.hairColors[
        _random.nextInt(AvatarOptions.hairColors.length)],
        eyes: AvatarOptions.eyeStyles[
        _random.nextInt(AvatarOptions.eyeStyles.length)],
        eyebrows: AvatarOptions.eyebrowStyles[
        _random.nextInt(AvatarOptions.eyebrowStyles.length)],
        mouth: AvatarOptions.mouthStyles[
        _random.nextInt(AvatarOptions.mouthStyles.length)],
        glasses: _random.nextBool()
            ? null
            : AvatarOptions.glassesStyles[
        _random.nextInt(AvatarOptions.glassesStyles.length)],
        earrings: _random.nextBool()
            ? null
            : AvatarOptions.earringStyles[
        _random.nextInt(AvatarOptions.earringStyles.length)],
        features: AvatarOptions.featureStyles
            .where((_) => _random.nextBool())
            .toList(),
      ),
    );
  }
}

final avatarBuilderProvider =
NotifierProvider<AvatarBuilderNotifier, AvatarBuilderState>(
  AvatarBuilderNotifier.new,
);