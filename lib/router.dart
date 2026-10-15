import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hue_quito/screens/welcome_screen.dart';
import 'package:hue_quito/screens/home_screen.dart';
import 'package:hue_quito/screens/preferences_screen.dart';
import 'package:hue_quito/screens/login_screen.dart';
import 'package:hue_quito/screens/register_screen.dart';
import 'package:hue_quito/screens/route_list_screen.dart';
import 'package:hue_quito/screens/scan_screen.dart';
import 'package:hue_quito/screens/album_screen.dart';
import 'package:hue_quito/screens/profile_screen.dart';
import 'package:hue_quito/screens/edit_profile_screen.dart';
import 'package:hue_quito/screens/hueca_detail_screen.dart';
import 'package:hue_quito/screens/route_detail_screen.dart';
import 'package:hue_quito/screens/map_screen.dart';
import 'package:hue_quito/screens/route_map_screen.dart';
import 'package:hue_quito/screens/navigation_screen.dart';
import 'package:hue_quito/screens/route_navigation_screen.dart';
import 'package:hue_quito/screens/reward_screen.dart';
import 'package:hue_quito/screens/main_layout.dart';
import 'package:hue_quito/screens/business/business_layout.dart';
import 'package:hue_quito/screens/business/dashboard_screen.dart';
import 'package:hue_quito/screens/business/menu_management_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hue_quito/screens/business/qr_generator_screen.dart';
import 'package:hue_quito/screens/business/profile_management_screen.dart';
import 'package:hue_quito/screens/business/gallery_management_screen.dart';
import 'package:hue_quito/screens/business/branch_management_screen.dart';
import 'package:hue_quito/screens/business/notification_management_screen.dart';
import 'package:hue_quito/screens/admin/admin_layout.dart';
import 'package:hue_quito/screens/admin/admin_dashboard_screen.dart';
import 'package:hue_quito/screens/admin/admin_huecas_screen.dart';
import 'package:hue_quito/screens/admin/admin_hueca_edit_screen.dart';
import 'package:hue_quito/screens/admin/admin_routes_screen.dart';
import 'package:hue_quito/screens/admin/admin_route_edit_screen.dart';
import 'package:hue_quito/screens/admin/admin_users_screen.dart';
import 'package:hue_quito/screens/admin/admin_reviews_screen.dart';
import 'package:hue_quito/screens/admin/admin_notifications_screen.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final path = state.uri.path;
      if (user == null && (path.startsWith('/business') || path.startsWith('/admin'))) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/preferences',
        builder: (context, state) => const PreferencesScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // BUSINESS SHELL ROUTE
      ShellRoute(
        builder: (context, state, child) => BusinessLayout(child: child),
        routes: [
          GoRoute(
            path: '/business/dashboard',
            builder: (context, state) => const BusinessDashboardScreen(),
          ),
          GoRoute(
            path: '/business/menu',
            builder: (context, state) => const BusinessMenuScreen(),
          ),
          GoRoute(
            path: '/business/notifications',
            builder: (context, state) => const BusinessNotificationScreen(),
          ),
          GoRoute(
            path: '/business/qr',
            builder: (context, state) => const BusinessQrScreen(),
          ),
          GoRoute(
            path: '/business/profile',
            builder: (context, state) => const BusinessProfileScreen(),
          ),
          GoRoute(
            path: '/business/gallery',
            builder: (context, state) {
              final extra = state.extra as String? ?? '';
              return GalleryManagementScreen(huecaId: extra);
            },
          ),
        ],
      ),
      // NORMAL USER SHELL ROUTE
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayout(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(path: '/edit_profile', builder: (context, state) => const EditProfileScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rutas', builder: (context, state) => const RouteListScreen(),
              ),
              GoRoute(
                path: '/mapa_interactivo', builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/album',
                builder: (context, state) => const AlbumScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/hueca_detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Hueca) {
            return HuecaDetailScreen(hueca: extra);
          }
          final id = extra is String ? extra : state.uri.queryParameters['id'];
          if (id != null) {
            final huecas = ref.read(huecasProvider).value ?? [];
            final found = huecas.where((h) => h.id == id).firstOrNull;
            if (found != null) {
              return HuecaDetailScreen(hueca: found);
            }
          }
          return HuecaDetailScreen(hueca: extra);
        }
      ),
      GoRoute(
        path: '/route_detail',
        builder: (context, state) {
          final extra = state.extra;
          return RouteDetailScreen(routeModel: extra);
        }
      ),
      GoRoute(
        path: '/route_map',
        builder: (context, state) {
          return const RouteMapScreen();
        }
      ),
      GoRoute(
        path: '/navigation',
        builder: (context, state) {
          final extra = state.extra as dynamic; 
          return NavigationScreen(targetHueca: extra);
        }
      ),
      GoRoute(
        path: '/route_navigation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>; 
          return RouteNavigationScreen(route: extra['route'], routeStops: extra['stops']);
        }
      ),
      GoRoute(
        path: '/reward',
        builder: (context, state) => const RewardScreen(),
      ),
      // ADMIN SHELL ROUTE
      ShellRoute(
        builder: (context, state, child) => AdminLayout(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/huecas',
            builder: (context, state) => const AdminHuecasScreen(),
          ),
          GoRoute(
            path: '/admin/notifications',
            builder: (context, state) => const AdminNotificationsScreen(),
          ),
          GoRoute(
            path: '/admin/routes',
            builder: (context, state) => const AdminRoutesScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
        ],
      ),
      // ADMIN EDIT & STANDALONE SCREENS
      GoRoute(
        path: '/admin/huecas/new',
        builder: (context, state) => const AdminHuecaEditScreen(),
      ),
      GoRoute(
        path: '/admin/huecas/edit',
        builder: (context, state) {
          final extra = state.extra as Hueca?;
          return AdminHuecaEditScreen(hueca: extra);
        },
      ),
      GoRoute(
        path: '/admin/huecas/branches',
        builder: (context, state) {
          final extra = state.extra;
          String huecaId = '';
          Hueca? initialHueca;
          if (extra is Hueca) {
            huecaId = extra.id;
            initialHueca = extra;
          } else if (extra is String) {
            huecaId = extra;
          }
          return BranchManagementScreen(
            huecaId: huecaId,
            initialHueca: initialHueca,
            isAdminMode: true,
          );
        },
      ),
      GoRoute(
        path: '/business/branches',
        builder: (context, state) {
          final extra = state.extra;
          String huecaId = '';
          Hueca? initialHueca;
          if (extra is Hueca) {
            huecaId = extra.id;
            initialHueca = extra;
          } else if (extra is String) {
            huecaId = extra;
          }
          return BranchManagementScreen(
            huecaId: huecaId,
            initialHueca: initialHueca,
          );
        },
      ),
      GoRoute(
        path: '/admin/routes/new',
        builder: (context, state) => const AdminRouteEditScreen(),
      ),
      GoRoute(
        path: '/admin/routes/edit',
        builder: (context, state) {
          final extra = state.extra as RouteModel?;
          return AdminRouteEditScreen(routeModel: extra);
        },
      ),
      GoRoute(
        path: '/admin/reviews',
        builder: (context, state) => const AdminReviewsScreen(),
      ),
    ],
  );
});
