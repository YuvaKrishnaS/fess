class AvatarOptions {
  AvatarOptions._();

  // --- Skin Colors (hex values only) -------------------------
  static const List<String> skinColors = [
    '614335', // deep brown
    'ae5d29', // medium brown
    'd08b5b', // tan
    'edb98a', // light tan
    'f8d25c', // yellow tone
    'fd9841', // warm orange
    'ffdbb4', // very light
  ];

  // ─── Hair Styles (top param) ------──────────
  static const List<String> hairStyles = [
    'bigHair',
    'bob',
    'bun',
    'curly',
    'curvy',
    'dreads',
    'dreads01',
    'dreads02',
    'frida',
    'frizzle',
    'fro',
    'froBand',
    'hat',
    'hijab',
    'longButNotTooLong',
    'miaWallace',
    'shaggy',
    'shaggyMullet',
    'shavedSides',
    'shortCurly',
    'shortFlat',
    'shortRound',
    'shortWaved',
    'sides',
    'straight01',
    'straight02',
    'straightAndStrand',
    'theCaesar',
    'theCaesarAndSidePart',
    'turban',
    'winterHat1',
    'winterHat02',
    'winterHat03',
    'winterHat04',
  ];

  // ─── Hair Colors (hex values only) ────────────────────────────────────────
  static const List<String> hairColors = [
    '2c1b18', // near black
    '4a312c', // very dark brown
    '724133', // dark brown
    'a55728', // medium brown
    'b58143', // warm brown
    'c93305', // auburn red
    'd6b370', // dark blonde
    'e8e1e1', // silver/grey
    'ecdcbf', // light blonde
    'f59797', // pinkish
  ];

  // ─── Eyes ─────────────────────────────────────────────────────────────────
  static const List<String> eyes = [
    'closed',
    'cry',
    'default',
    'eyeRoll',
    'happy',
    'hearts',
    'side',
    'squint',
    'surprised',
    'wink',
    'winkWacky',
    'xDizzy',
  ];

  // ─── Eyebrows ─────────────────────────────────────────────────────────────
  static const List<String> eyebrows = [
    'angry',
    'angryNatural',
    'default',
    'defaultNatural',
    'flatNatural',
    'frownNatural',
    'raisedExcited',
    'raisedExcitedNatural',
    'sadConcerned',
    'sadConcernedNatural',
    'unibrowNatural',
    'upDown',
    'upDownNatural',
  ];

  // ─── Mouth ────────────────────────────────────────────────────────────────
  static const List<String> mouths = [
    'concerned',
    'default',
    'disbelief',
    'eating',
    'grimace',
    'sad',
    'screamOpen',
    'serious',
    'smile',
    'tongue',
    'twinkle',
    'vomit',
  ];

  // ─── Accessories / Glasses ────────────────────────────────────────────────
  static const List<String> glasses = [
    'eyepatch',
    'kurt',
    'prescription01',
    'prescription02',
    'round',
    'sunglasses',
    'wayfarers',
  ];

  // ─── Accessories Colors ───────────────────────────────────────────────────
  static const List<String> accessoriesColors = [
    '262e33',
    '3c4f5c',
    '25557c',
    '5199e4',
    '65c9ff',
    'b1e2ff',
    '929598',
    'e6e6e6',
    'ffffff',
    'a7ffc4',
    'ff5c5c',
    'ff488e',
    'ffafb9',
    'ffdeb5',
    'ffffb1',
  ];

  // ─── Clothing ─────────────────────────────────────────────────────────────
  static const List<String> clothing = [
    'blazerAndShirt',
    'blazerAndSweater',
    'collarAndSweater',
    'graphicShirt',
    'hoodie',
    'overall',
    'shirtCrewNeck',
    'shirtScoopNeck',
    'shirtVNeck',
  ];

  // ─── Clothing Colors ──────────────────────────────────────────────────────
  static const List<String> clothingColors = [
    '262e33',
    '3c4f5c',
    '25557c',
    '5199e4',
    '65c9ff',
    'b1e2ff',
    '929598',
    'e6e6e6',
    'ffffff',
    'a7ffc4',
    'ff5c5c',
    'ff488e',
    'ffafb9',
    'ffdeb5',
    'ffffb1',
  ];

  // ─── Clothing Graphics (only used when clothing = 'graphicShirt') ─────────
  static const List<String> clothingGraphics = [
    'bat',
    'bear',
    'cumbia',
    'deer',
    'diamond',
    'hola',
    'pizza',
    'resist',
    'skull',
    'skullOutline',
  ];

  // ─── Facial Hair ─────────────────────────────────────────────────────────
  static const List<String> facialHair = [
    'beardLight',
    'beardMajestic',
    'beardMedium',
    'moustacheFancy',
    'moustacheMagnum',
  ];

  // ─── Facial Hair Colors ───────────────────────────────────────────────────
  static const List<String> facialHairColors = [
    '2c1b18',
    '4a312c',
    '724133',
    'a55728',
    'b58143',
    'c93305',
    'd6b370',
    'e8e1e1',
    'ecdcbf',
    'f59797',
  ];

  // ─── Hat Colors (for winterHat* and hat tops) ─────────────────────────────
  static const List<String> hatColors = [
    '262e33',
    '3c4f5c',
    '25557c',
    '5199e4',
    '65c9ff',
    'b1e2ff',
    '929598',
    'e6e6e6',
    'ffffff',
    'a7ffc4',
    'ff5c5c',
    'ff488e',
    'ffafb9',
    'ffdeb5',
    'ffffb1',
  ];
  static List<String> get eyeStyles => eyes;
  static List<String> get eyebrowStyles => eyebrows;
  static List<String> get mouthStyles => mouths;
  static List<String> get glassesStyles => glasses;

  // avataaars doesn't support earrings — return empty so builder renders nothing
  static const List<String> earringStyles = [];

  // avataaars doesn't have a standalone 'features' list — map to empty
  // builder will skip rendering this tab gracefully
  static const List<String> featureStyles = [];
}