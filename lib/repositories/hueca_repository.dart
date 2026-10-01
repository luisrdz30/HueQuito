import 'package:cloud_firestore/cloud_firestore.dart';

class Hueca {
  final String id;
  final String name;
  final Map<String, dynamic> description;
  final String address;
  final String sector;
  final GeoPoint location;
  final String phone;
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> mainDish;
  final Map<String, dynamic> loyaltyCard;
  final Map<String, dynamic> secretSticker;
  final List<dynamic> menuItems;
  final List<String> tags;
  final String priceLevel;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final String ownerId;
  final bool isActive;

  Hueca({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.sector,
    required this.location,
    required this.phone,
    required this.schedule,
    required this.mainDish,
    required this.loyaltyCard,
    required this.secretSticker,
    required this.menuItems,
    required this.tags,
    required this.priceLevel,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.ownerId,
    required this.isActive,
  });

  factory Hueca.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Hueca(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? {},
      address: data['address'] ?? '',
      sector: data['sector'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      phone: data['phone'] ?? '',
      schedule: data['schedule'] ?? {},
      mainDish: data['mainDish'] ?? {},
      loyaltyCard: data['loyaltyCard'] ?? {},
      secretSticker: data['secretSticker'] ?? {},
      menuItems: data['menuItems'] ?? [],
      tags: List<String>.from(data['tags'] ?? []),
      priceLevel: data['priceLevel'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      ownerId: data['ownerId'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }
}

class HuecaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Hueca>> getHuecas() async {
    final snapshot = await _db.collection('huecas').get();
    return snapshot.docs.map((doc) => Hueca.fromFirestore(doc)).toList();
  }

  Future<Hueca?> getHuecaById(String id) async {
    final doc = await _db.collection('huecas').doc(id).get();
    if (doc.exists) {
      return Hueca.fromFirestore(doc);
    }
    return null;
  }

  Future<void> addReview(String huecaId, int rating, String comment, String userName, String userPic) async {
    final reviewRef = _db.collection('huecas').doc(huecaId).collection('reviews').doc();
    await reviewRef.set({
      'rating': rating,
      'comment': comment,
      'userName': userName,
      'userPic': userPic,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Review>> getReviews(String huecaId) async {
    final snapshot = await _db.collection('huecas').doc(huecaId).collection('reviews').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
  }
}

class Review {
  final int rating;
  final String comment;
  final String userName;
  final String userPic;
  final DateTime? createdAt;

  Review({
    required this.rating,
    required this.comment,
    required this.userName,
    required this.userPic,
    this.createdAt,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Review(
      rating: data['rating'] ?? 0,
      comment: data['comment'] ?? '',
      userName: data['userName'] ?? 'Anónimo',
      userPic: data['userPic'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
