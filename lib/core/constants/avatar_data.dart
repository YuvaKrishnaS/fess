class AvatarData {
  AvatarData._();

  // 20 seeds that generate distinct, memorable characters
  static const List<String> seeds = [
    'shadow', 'whisper', 'ember', 'frost', 'storm',
    'drift', 'echo', 'phantom', 'nova', 'cipher',
    'ash', 'vale', 'rune', 'mist', 'spark',
    'dusk', 'flare', 'veil', 'shade', 'glow',
  ];

  static int get count => seeds.length;

  static String seedAt(int index) => seeds[index % seeds.length];

  // change adventurer to any other style here if needed later
  static String urlForSeed(String seed) =>
      'https://api.dicebear.com/9.x/adventurer/png?seed=$seed&size=200';
}