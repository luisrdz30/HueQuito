import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRepo = ref.read(userRepositoryProvider);
        final userModel = await userRepo.getCurrentUser();

        if (userModel != null && userModel.role == 'business') {
          // Check last login for business
          final prefs = await SharedPreferences.getInstance();
          final lastLogin = prefs.getInt('last_login_time') ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;

          if (now - lastLogin > 24 * 60 * 60 * 1000) {
            // More than 24 hours, log out
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            return;
          } else {
            // Still valid
            if (mounted) context.go('/business/dashboard');
            return;
          }
        } else {
          // Normal user, persistent
          if (mounted) context.go('/home');
          return;
        }
      }
    } catch (_) {
      // Error fetching user data or headless test mode
    }

    // Not logged in or logged out
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.85);
    final cardBorder = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Imagen de fondo evocadora con overlay degradado
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&auto=format&fit=crop&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      bgColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // 2. Degradado multicapa para legibilidad y elegancia
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isDark ? Colors.black : Colors.black).withValues(alpha: 0.35),
                    bgColor.withValues(alpha: 0.85),
                    bgColor,
                  ],
                  stops: const [0.0, 0.45, 0.75],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. Contenido desplazable y adaptable
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Barra superior con badge de ciudad y cambio de idioma
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🇪🇨', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Quito · Ecuador',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.blueGrey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Selector de idioma rápido
                              Container(
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    ref.read(settingsProvider.notifier).setLanguage(isEn ? 'es' : 'en');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.language,
                                          size: 15,
                                          color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isEn ? 'English' : 'Español',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.blueGrey.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Emblema Central de Marca (Logo estilizado)
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Halo de luz suave
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppTheme.primary.withValues(alpha: 0.35),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Círculo exterior con borde dorado / naranja
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.4),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(3.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.restaurant,
                                        size: 40,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                // Pequeña insignia de mapa/fuego
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD97706),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Título de la Aplicación
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                fontFamily: Theme.of(context).textTheme.headlineMedium?.fontFamily,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Hue',
                                  style: TextStyle(color: AppTheme.primary),
                                ),
                                TextSpan(
                                  text: '-Quito',
                                  style: TextStyle(color: titleColor),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Slogan Principal y Subtítulo
                          Text(
                            isEn ? 'The Hidden Flavors of the Capital' : 'El sabor oculto de la capital',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              isEn
                                  ? 'Your guide to authentic traditional spots, guided culinary routes, and secret collectibles.'
                                  : 'Tu pasaporte a los locales tradicionales más auténticos, circuitos temáticos y cartilla de sellos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: subtitleColor,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 3 Cápsulas de valor de la app
                          _buildFeaturePill(
                            icon: Icons.storefront_rounded,
                            iconColor: const Color(0xFFEA580C),
                            title: isEn ? 'Authentic Spots' : 'Huecas Tradicionales',
                            subtitle: isEn
                                ? 'Real recipes, prices, and diner ratings'
                                : 'Recetas de antaño, precios y valoraciones',
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                          ),
                          const SizedBox(height: 10),
                          _buildFeaturePill(
                            icon: Icons.navigation_rounded,
                            iconColor: const Color(0xFF0284C7),
                            title: isEn ? 'GPS Map & Routes' : 'Mapa & Circuitos Guiados',
                            subtitle: isEn
                                ? 'Turn-by-turn routes to discover every corner'
                                : 'Rutas temáticas paso a paso por los barrios',
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                          ),
                          const SizedBox(height: 10),
                          _buildFeaturePill(
                            icon: Icons.loyalty_rounded,
                            iconColor: const Color(0xFFD97706),
                            title: isEn ? 'Stamps & Rewards' : 'Cartilla de Sellos & Cromos',
                            subtitle: isEn
                                ? 'Collect stamps, unlock secret stickers and win gifts'
                                : 'Acumula sellos en cada visita y canjea platos gratis',
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                          ),

                          const Spacer(),
                          const SizedBox(height: 24),

                          // Botón Principal de Comienzo
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () => context.push('/preferences'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isEn ? 'Start Exploring' : 'Comenzar Aventura',
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Fila de acciones secundarias: Iniciar sesión / Entrar como invitado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEn ? 'Already have an account?' : '¿Ya tienes una cuenta?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  isEn ? 'Log in' : 'Iniciar Sesión',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
