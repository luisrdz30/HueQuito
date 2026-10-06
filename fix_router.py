import re
with open('lib/router.dart', 'r', encoding='utf-8') as f:
    c = f.read()

imports = '''import 'package:hue_quito/screens/business/business_layout.dart';
import 'package:hue_quito/screens/business/dashboard_screen.dart';
import 'package:hue_quito/screens/business/menu_management_screen.dart';
import 'package:hue_quito/screens/business/qr_generator_screen.dart';
import 'package:hue_quito/screens/business/profile_management_screen.dart';
'''

c = c.replace("import 'package:hue_quito/screens/main_layout.dart';", "import 'package:hue_quito/screens/main_layout.dart';\n" + imports)

routes = '''
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
            path: '/business/qr',
            builder: (context, state) => const BusinessQrScreen(),
          ),
          GoRoute(
            path: '/business/profile',
            builder: (context, state) => const BusinessProfileScreen(),
          ),
        ],
      ),
'''

c = c.replace('routes: [', 'routes: [' + routes)

with open('lib/router.dart', 'w', encoding='utf-8') as f:
    f.write(c)
