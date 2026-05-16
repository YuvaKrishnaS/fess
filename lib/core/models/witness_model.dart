import 'package:cloud_firestore/cloud_firestore.dart';

class WitnessModel {
  final String witnesserId;
  final String witnessedId;
  final DateTime? createdAt;

  const WitnessModel({
    required this.witnesserId,
    required this.witnessedId,
    this.createdAt,
  });

  String get docId => '${witnesserId}_$witnessedId';

  factory WitnessModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WitnessModel(
      witnesserId: d['witnesserId'] as String? ?? '',
      witnessedId: d['witnessedId'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'witnesserId': witnesserId,
    'witnessedId': witnessedId,
    'createdAt': FieldValue.serverTimestamp(),
  };
}