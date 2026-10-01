import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/utils/auth_utils.dart';

class MainLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({
    super.key,
    required this.navigationShell,
  });

  void _goBranch(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isActive = navigationShell.currentIndex == index;
    // Determine active color based on dark mode vs light mode context
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppTheme.primary;
    final inactiveColor = isDark ? Colors.white54 : AppTheme.textMedium.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => _goBranch(context, index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(isActive ? 14 : 8),
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isActive ? [
                BoxShadow(color: activeColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
              ] : [],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : inactiveColor,
              size: isActive ? 26 : 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildNavItem(context, 0, LucideIcons.compass, 'Explorar'),
            _buildNavItem(context, 1, LucideIcons.map, 'Rutas'),
            _buildNavItem(context, 2, Icons.qr_code_scanner, 'Escanear'),
            _buildNavItem(context, 3, Icons.menu_book_rounded, 'Mi Álbum'),
            _buildNavItem(context, 4, LucideIcons.user, 'Perfil'),
          ],
        ),
      ),
    );
  }
}
