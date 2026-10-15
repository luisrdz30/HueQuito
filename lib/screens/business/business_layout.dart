import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';

class BusinessLayout extends StatelessWidget {
  final Widget child;

  const BusinessLayout({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/business/dashboard')) return 0;
    if (location.startsWith('/business/menu')) return 1;
    if (location.startsWith('/business/notifications')) return 2;
    if (location.startsWith('/business/qr')) return 3;
    if (location.startsWith('/business/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/business/dashboard');
        break;
      case 1:
        context.go('/business/menu');
        break;
      case 2:
        context.go('/business/notifications');
        break;
      case 3:
        context.go('/business/qr');
        break;
      case 4:
        context.go('/business/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menú',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: 'Avisos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Mi QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
