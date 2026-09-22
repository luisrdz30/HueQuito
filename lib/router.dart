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
import 'package:hue_quito/screens/hueca_detail_screen.dart';
import 'package:hue_quito/screens/route_detail_screen.dart';
import 'package:hue_quito/screens/map_screen.dart';
import 'package:hue_quito/screens/route_map_screen.dart';
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rutas',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const RouteListScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 200),
                ),
              ),
              GoRoute(
                path: '/mapa_interactivo',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const MapScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 200),
                ),
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
        builder: (context, state) => const HuecaDetailScreen(),
      ),
      GoRoute(
        path: '/route_detail',
        builder: (context, state) => const RouteDetailScreen(),
      ),
      GoRoute(
        path: '/route_map',
        builder: (context, state) => const RouteMapScreen(),
      ),
      GoRoute(
        path: '/reward',
        builder: (context, state) => const RewardScreen(),
      ),
    ],
  );
});
