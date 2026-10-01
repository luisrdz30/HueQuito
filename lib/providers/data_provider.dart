import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/hueca_repository.dart';
import '../repositories/route_repository.dart';
import '../repositories/user_repository.dart';

final huecaRepositoryProvider = Provider<HuecaRepository>((ref) {
  return HuecaRepository();
});

// Cache the list of huecas globally
final huecasProvider = FutureProvider<List<Hueca>>((ref) async {
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
  final repository = ref.watch(userRepositoryProvider);
  return await repository.getCurrentUser();
});
