import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'feed_provider.dart';

// ─── ProfileData ──────────────────────────────────────────────────────────────

class ProfileData {
  final String anonId;
  final String username;
  final Map<String, dynamic> avatarConfig;
  final int totalPostCount;
  final int totalTeaCount;

  const ProfileData({
    required this.anonId,
    required this.username,
    required this.avatarConfig,
    required this.totalPostCount,
    required this.totalTeaCount,
  });

  factory ProfileData.fromMap(String anonId, Map<String, dynamic> data) {
    return ProfileData(
      anonId: anonId,
      username: data['username'] as String? ?? 'anon',
      avatarConfig: Map<String, dynamic>.from(
        (data['avatarConfig'] as Map?) ?? const {},
      ),
      totalPostCount: (data['totalPostCount'] as num?)?.toInt() ?? 0,
      totalTeaCount: (data['totalTeaCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── profileDataProvider ──────────────────────────────────────────────────────

final profileDataProvider =
FutureProvider.family<ProfileData?, String>((ref, anonId) async {
  if (anonId.isEmpty) return null;
  try {
    final doc = await FirebaseService.firestore
        .collection('public_profiles')
        .doc(anonId)
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return ProfileData.fromMap(anonId, Map<String, dynamic>.from(data));
  } catch (e) {
    debugPrint('[profileDataProvider] $e');
    return null;
  }
});

// ─── signOutProvider ──────────────────────────────────────────────────────────

final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(currentAnonIdProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(profileDataProvider);
    ref.invalidate(forYouFeedProvider);
    ref.invalidate(followingFeedProvider);
  };
});