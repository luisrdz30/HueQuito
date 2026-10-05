import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hue_quito/screens/welcome_screen.dart';
import 'package:hue_quito/screens/home_screen.dart';
import 'package:hue_quito/screens/preferences_screen.dart';
import 'package:hue_quito/screens/login_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
    ],
  );
});
