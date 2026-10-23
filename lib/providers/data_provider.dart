import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/hueca_repository.dart';
import '../repositories/route_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/hueca_request_repository.dart';
import '../repositories/support_repository.dart';
import '../repositories/quiz_repository.dart';
import '../models/notification_model.dart';
import '../models/gastronomic_profile.dart';

final huecaRepositoryProvider = Provider<HuecaRepository>((ref) {
  return HuecaRepository();
});

// Cache the list of huecas globally, synchronized in real-time with Firestore stream
final huecasProvider = FutureProvider<List<Hueca>>((ref) async {
  final stream = ref.watch(allHuecasStreamProvider);
  if (stream.hasValue) {
    return stream.value!;
  }
  final repository = ref.watch(huecaRepositoryProvider);
  return await repository.getHuecas();
});

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository();
});

// Cache the list of routes globally
final routesProvider = FutureProvider<List<RouteModel>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  return await repository.getRoutes();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // Watch authState so when login/logout happens, this provider rebuilds.
  ref.watch(authStateProvider);
  final repository = ref.watch(userRepositoryProvider);
  return await repository.getCurrentUser();
});


final myHuecaProvider = FutureProvider<Hueca?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  // Solo usuarios con rol 'business' o 'admin' pueden gestionar una hueca.
  // Cualquier comensal con rol 'user' (o cuenta restablecida/eliminada) nunca tiene hueca asignada.
  if (user.role != 'business' && user.role != 'admin') return null;

  final huecas = await ref.watch(huecasProvider.future);
  try {
    return huecas.firstWhere((h) =>
        (h.ownerId.trim().isNotEmpty && h.ownerId.trim() == user.uid.trim()) ||
        h.branches.any((b) =>
            b.managerEmail != null &&
            b.managerEmail!.trim().isNotEmpty &&
            b.managerEmail!.trim().toLowerCase() == user.email.trim().toLowerCase()));
  } catch (e) {
    return null;
  }
});

final isOwnerProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  final myHueca = await ref.watch(myHuecaProvider.future);
  if (user == null || myHueca == null) return false;
  return myHueca.ownerId == user.uid;
});

final currentManagedBranchProvider = FutureProvider<HuecaBranch?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  final myHueca = await ref.watch(myHuecaProvider.future);
  if (user == null || myHueca == null) return null;
  if (myHueca.ownerId == user.uid) return null; // El dueño tiene acceso general
  try {
    return myHueca.branches.firstWhere((b) =>
        b.managerEmail != null &&
        b.managerEmail!.trim().toLowerCase() == user.email.trim().toLowerCase());
  } catch (e) {
    return null;
  }
});

final stampHistoryProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, huecaId) {
  return FirebaseFirestore.instance
      .collection('huecas')
      .doc(huecaId)
      .collection('stamp_history')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final pendingNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamPendingNotifications();
});

final allNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamAllNotifications();
});

final approvedNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamApprovedNotifications();
});

final myHuecaNotificationsProvider = StreamProvider.autoDispose.family<List<NotificationModel>, String>((ref, huecaId) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamNotificationsByHueca(huecaId);
});

// ADMIN PROVIDERS
final allHuecasStreamProvider = StreamProvider<List<Hueca>>((ref) {
  final repo = ref.watch(huecaRepositoryProvider);
  return repo.streamAllHuecas();
});

final allRoutesStreamProvider = StreamProvider<List<RouteModel>>((ref) {
  final repo = ref.watch(routeRepositoryProvider);
  return repo.streamRoutes();
});

final allUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return repo.streamAllUsers();
});

final globalReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final repo = ref.watch(huecaRepositoryProvider);
  return await repo.getGlobalReviews();
});

// HUECA REQUESTS PROVIDERS
final huecaRequestRepositoryProvider = Provider<HuecaRequestRepository>((ref) {
  return HuecaRequestRepository();
});

final pendingHuecaRequestsProvider = StreamProvider<List<HuecaRequest>>((ref) {
  final repo = ref.watch(huecaRequestRepositoryProvider);
  return repo.streamPendingRequests();
});

final allHuecaRequestsProvider = StreamProvider<List<HuecaRequest>>((ref) {
  final repo = ref.watch(huecaRequestRepositoryProvider);
  return repo.streamAllRequests();
});

final myHuecaRequestsProvider = StreamProvider.autoDispose.family<List<HuecaRequest>, String>((ref, userId) {
  final repo = ref.watch(huecaRequestRepositoryProvider);
  return repo.streamUserRequests(userId);
});

// SUPPORT MESSAGES PROVIDERS
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository();
});

final newSupportMessagesProvider = StreamProvider<List<SupportMessage>>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.streamNewMessages();
});

final allSupportMessagesProvider = StreamProvider<List<SupportMessage>>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.streamAllMessages();
});

final myHuecaSupportMessagesProvider = StreamProvider.autoDispose.family<List<SupportMessage>, String>((ref, huecaId) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.streamMessagesByHueca(huecaId);
});

// QUIZ QUESTIONS PROVIDERS
final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepository();
});

final quizQuestionsStreamProvider = StreamProvider<List<QuizQuestion>>((ref) {
  final repo = ref.watch(quizRepositoryProvider);
  return repo.streamQuestions();
});

// CUSTOM USER TOURS PROVIDER
final userToursStreamProvider = StreamProvider<List<RouteModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  final repo = ref.watch(routeRepositoryProvider);
  final uid = user?.uid ?? 'guest';
  return repo.streamUserTours(uid);
});



