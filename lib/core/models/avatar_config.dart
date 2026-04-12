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
  }) {
    return AvatarConfig(
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
  }

  Map<String, dynamic> toMap() {
    return {
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
  }

  factory AvatarConfig.fromMap(Map<String, dynamic> map) {
    return AvatarConfig(
      skinColor: map['skinColor'] as String? ?? 'f2d3b1',
      hair: map['hair'] as String? ?? 'short03',
      hairColor: map['hairColor'] as String? ?? '2c1b18',
      eyes: map['eyes'] as String? ?? 'variant01',
      eyebrows: map['eyebrows'] as String? ?? 'variant01',
      mouth: map['mouth'] as String? ?? 'variant01',
      glasses: map['glasses'] as String?,
      earrings: map['earrings'] as String?,
      features: (map['features'] as List?)?.cast<String>() ?? const [],
    );
  }

  String buildUrl({int size = 256}) {
    final params = <String, String>{
      'size': '$size',
      'skinColor': skinColor,
      'hair': hair,
      'hairColor': hairColor,
      'eyes': eyes,
      'eyebrows': eyebrows,
      'mouth': mouth,
      'backgroundColor': 'transparent',
      'radius': '50',
    };

    if (glasses != null) params['glasses'] = glasses!;
    if (earrings != null) params['earrings'] = earrings!;
    if (features.isNotEmpty) params['features'] = features.join(',');

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://api.dicebear.com/9.x/adventurer/png?$query';
  }

  static const AvatarConfig initial = AvatarConfig(
    skinColor: 'f2d3b1',
    hair: 'short03',
    hairColor: '2c1b18',
    eyes: 'variant01',
    eyebrows: 'variant01',
    mouth: 'variant01',
    glasses: null,
    earrings: null,
    features: [],
  );
}