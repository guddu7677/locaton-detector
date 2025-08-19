import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<UserModel>> getSenderUsers() {
    return _firestore
        .collection("users")
        .where("role", isEqualTo: "sender")
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection("users").doc(uid).get();
      if (doc.exists) return UserModel.fromFirestore(doc);
    } catch (_) {}
    return null;
  }
}
