import 'package:flutter/foundation.dart';

class AvatarConfig {
  final String skinColor;
  final String hair;
  final String hairColor;
  final String eyes;
  final String eyebrows;
  final String mouth;
  final String? glasses;
  final String? earrings;
  final List<String> features;

  const AvatarConfig({
    required this.skinColor,
    required this.hair,
    required this.hairColor,
    required this.eyes,
    required this.eyebrows,
    required this.mouth,
    this.glasses,
    this.earrings,
    this.features = const [],
  });

  AvatarConfig copyWith({
    String? skinColor,
    String? hair,
    String? hairColor,
    String? eyes,
    String? eyebrows,
    String? mouth,
    String? glasses,
    bool clearGlasses = false,
    String? earrings,
    bool clearEarrings = false,
    List<String>? features,
  }) =>
      AvatarConfig(
        skinColor: skinColor ?? this.skinColor,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        eyes: eyes ?? this.eyes,
        eyebrows: eyebrows ?? this.eyebrows,
        mouth: mouth ?? this.mouth,
        glasses: clearGlasses ? null : (glasses ?? this.glasses),
        earrings: clearEarrings ? null : (earrings ?? this.earrings),
        features: features ?? this.features,
      );

  Map<String, dynamic> toMap() => {
    'skinColor': skinColor,
    'hair': hair,
    'hairColor': hairColor,
    'eyes': eyes,
    'eyebrows': eyebrows,
    'mouth': mouth,
    'glasses': glasses,
    'earrings': earrings,
    'features': features,
  };

  factory AvatarConfig.fromMap(Map<String, dynamic> map) => AvatarConfig(
    skinColor: map['skinColor'] as String? ?? 'light',
    hair: map['hair'] as String? ?? 'shortHairShortFlat',
    hairColor: map['hairColor'] as String? ?? '2c1b18',
    eyes: map['eyes'] as String? ?? 'default',
    eyebrows: map['eyebrows'] as String? ?? 'default',
    mouth: map['mouth'] as String? ?? 'default',
    glasses: map['glasses'] as String?,
    earrings: map['earrings'] as String?,
    features:
    (map['features'] as List?)?.cast<String>() ?? const [],
  );

  /// Builds a DiceBear avataaars PNG URL.
  /// Old adventurer param values are passed as-is — DiceBear ignores
  /// unrecognised values and renders style defaults. No crash.
  String buildUrl({int size = 128}) {
    final params = <String, String>{
      'size': '$size',
      'skinColor': skinColor,
      'top': hair,
      'hairColor': hairColor,
      'eyes': eyes,
      'eyebrows': eyebrows,
      'mouth': mouth,
      'backgroundColor': 'transparent',
      'radius': '50',
      'style': 'circle',
    };

    if (glasses != null) {
      params['accessories'] = glasses!;
      params['accessoriesColor'] = hairColor;
    }

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://api.dicebear.com/9.x/avataaars/png?$query';
  }

  static const AvatarConfig initial = AvatarConfig(
    skinColor: 'light',
    hair: 'shortHairShortFlat',
    hairColor: '2c1b18',
    eyes: 'default',
    eyebrows: 'default',
    mouth: 'default',
  );
}