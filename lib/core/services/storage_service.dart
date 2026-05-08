import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/storage_config.dart';

/// Abstract storage interface.
/// Swap the implementation class to migrate providers.
abstract class StorageService {
  Future<String> uploadAudio({
    required String localPath,
    required String anonId,
  });

  static final StorageService instance = _CloudinaryStorageService();
}

class _CloudinaryStorageService implements StorageService {
  @override
  Future<String> uploadAudio({
    required String localPath,
    required String anonId,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Audio file not found at $localPath');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(StorageConfig.uploadUrl),
    );

    request.fields['upload_preset'] = StorageConfig.uploadPreset;
    // folder organises by user — easy to manage/delete later
    request.fields['folder'] = 'tea_audio/$anonId';
    request.fields['resource_type'] = 'video'; // Cloudinary uses 'video' for audio

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      localPath,
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      debugPrint('[StorageService] Cloudinary error: $body');
      throw Exception('Upload failed: ${response.statusCode}');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;

    if (url == null) {
      throw Exception('No URL in Cloudinary response');
    }

    debugPrint('[StorageService] Uploaded: $url');
    return url;
  }
}

// Future migration example (uncomment + swap instance above)
//
// import 'package:firebase_storage/firebase_storage.dart';
//
// class _FirebaseStorageService implements StorageService {
//   @override
//   Future<String> uploadAudio({required String localPath, required String anonId}) async {
//     final ref = FirebaseStorage.instance.ref().child('tea_audio/$anonId/${const Uuid().v4()}.m4a');
//     await ref.putFile(File(localPath));
//     return await ref.getDownloadURL();
//   }
// }