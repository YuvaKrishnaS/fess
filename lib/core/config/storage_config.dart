/// Cloudinary configuration.
/// To migrate to Firebase Storage or any other provider,
/// only update [StorageService] in storage_service.dart.
/// This file just holds the constants.
class StorageConfig {
  StorageConfig._();

  static const String cloudName = 'di70mlf4b';
  static const String uploadPreset = 'fess-development';

  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/video/upload';
}