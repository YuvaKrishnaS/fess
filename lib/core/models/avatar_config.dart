
class AvatarConfig {
  final String skinColor;   // hex: e.g. 'edb98a'
  final String hair;        // avataaars 'top' param: e.g. 'shortFlat'
  final String hairColor;   // hex: e.g. '2c1b18'
  final String eyes;        // e.g. 'default'
  final String eyebrows;    // e.g. 'default'
  final String mouth;       // e.g. 'smile'
  final String? glasses;    // accessories param: e.g. 'prescription01'
  final String? earrings;   // not supported in avataaars — ignored safely
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
    skinColor: map['skinColor'] as String? ?? 'edb98a',
    hair: map['hair'] as String? ?? 'shortFlat',
    hairColor: map['hairColor'] as String? ?? '2c1b18',
    eyes: map['eyes'] as String? ?? 'default',
    eyebrows: map['eyebrows'] as String? ?? 'default',
    mouth: map['mouth'] as String? ?? 'smile',
    glasses: map['glasses'] as String?,
    earrings: map['earrings'] as String?,
    features: (map['features'] as List?)?.cast<String>() ?? const [],
  );

  /// Builds a valid DiceBear avataaars PNG URL.
  /// All param names and values are verified against the 9.x API docs.
  String buildUrl({int size = 128}) {
    final buffer = StringBuffer(
      'https://api.dicebear.com/9.x/avataaars/png'
          '?size=$size'
          '&skinColor=${Uri.encodeComponent(skinColor)}'
          '&top=${Uri.encodeComponent(hair)}'
          '&hairColor=${Uri.encodeComponent(hairColor)}'
          '&eyes=${Uri.encodeComponent(eyes)}'
          '&eyebrows=${Uri.encodeComponent(eyebrows)}'
          '&mouth=${Uri.encodeComponent(mouth)}'
          '&topProbability=100'
          '&facialHairProbability=0'
          '&backgroundColor=transparent',
    );

    if (glasses != null) {
      buffer.write('&accessories=${Uri.encodeComponent(glasses!)}');
      buffer.write('&accessoriesProbability=100');
    } else {
      buffer.write('&accessoriesProbability=0');
    }

    return buffer.toString();
  }

  static const AvatarConfig initial = AvatarConfig(
    skinColor: 'edb98a',   // valid hex — medium skin
    hair: 'shortFlat',     // valid 'top' value
    hairColor: '2c1b18',   // valid hex — dark brown
    eyes: 'default',       // valid eyes value
    eyebrows: 'default',   // valid eyebrows value
    mouth: 'smile',        // valid mouth value
  );
}