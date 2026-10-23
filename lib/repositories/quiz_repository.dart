import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gastronomic_profile.dart';

class QuizRepository {
  final FirebaseFirestore _firestore;

  QuizRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('quiz_questions');

  Stream<List<QuizQuestion>> streamQuestions() {
    try {
      return _collection
          .orderBy('order')
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              return defaultQuizQuestions;
            }
            return snapshot.docs
                .map((doc) => QuizQuestion.fromMap(doc.data(), doc.id))
                .toList();
          })
          .handleError((_) => defaultQuizQuestions);
    } catch (_) {
      return Stream.value(defaultQuizQuestions);
    }
  }

  Future<List<QuizQuestion>> getQuestions() async {
    try {
      final snapshot = await _collection.orderBy('order').get();
      if (snapshot.docs.isEmpty) {
        return defaultQuizQuestions;
      }
      return snapshot.docs
          .map((doc) => QuizQuestion.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return defaultQuizQuestions;
    }
  }

  Future<void> saveQuestion(QuizQuestion question) async {
    if (question.id.isEmpty) {
      final docRef = _collection.doc();
      final newQuestion = question.copyWith(id: docRef.id);
      await docRef.set(newQuestion.toMap());
    } else {
      await _collection.doc(question.id).set(question.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> deleteQuestion(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> resetToDefaults() async {
    try {
      final snapshot = await _collection.get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      for (var q in defaultQuizQuestions) {
        final docRef = _collection.doc();
        final item = q.copyWith(id: docRef.id);
        batch.set(docRef, item.toMap());
      }
      await batch.commit();
    } catch (e) {
      // Re-throw or let caller handle
      rethrow;
    }
  }
}
