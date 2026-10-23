import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/theme/theme.dart';

Future<void> showClientOnboardingDialog(
  BuildContext context, {
  bool markAsSeen = true,
  String lang = 'es',
}) async {
  if (markAsSeen) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_client_tutorial', true);
    } catch (_) {}
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ClientOnboardingDialog(
      lang: lang,
      markAsSeenOnClose: markAsSeen,
    ),
  );
}

class ClientOnboardingDialog extends StatefulWidget {
  final String lang;
  final bool markAsSeenOnClose;

  const ClientOnboardingDialog({
    super.key,
    this.lang = 'es',
    this.markAsSeenOnClose = true,
  });

  @override
  State<ClientOnboardingDialog> createState() => _ClientOnboardingDialogState();
}

class _ClientOnboardingDialogState extends State<ClientOnboardingDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    if (widget.markAsSeenOnClose) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_seen_client_tutorial', true);
      } catch (_) {}
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleClose();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.lang == 'en';

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 690),
        child: Column(
          children: [
            // Header con título, progreso y botón "Saltar"
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.explore_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? "Diner's Guide" : 'Guía del Comensal',
                          style: TextStyle(
                            color: Colors.blueGrey.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          isEn
                              ? 'Step ${_currentPage + 1} of $_totalPages'
                              : 'Paso ${_currentPage + 1} de $_totalPages',
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _handleClose,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      isEn ? 'Skip' : 'Saltar',
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.blueGrey, size: 20),
                    tooltip: isEn ? 'Close Guide' : 'Cerrar Guía',
                    visualDensity: VisualDensity.compact,
                    onPressed: _handleClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Contenido de las 6 diapositivas
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildSlide0Huecas(isEn),
                  _buildSlide1Mapa(isEn),
                  _buildSlide2Rutas(isEn),
                  _buildSlide3Sellos(isEn),
                  _buildSlide4Cromos(isEn),
                  _buildSlide5Escaneo(isEn),
                ],
              ),
            ),

            // Footer con navegación e indicadores
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: Colors.blueGrey.shade100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón Atrás
                  if (_currentPage > 0)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueGrey.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: _prevPage,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: Text(isEn ? 'Back' : 'Atrás', style: const TextStyle(fontSize: 12.5)),
                    )
                  else
                    const SizedBox(width: 60),

                  // Indicador de Puntos (Dots)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_totalPages, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primary : Colors.blueGrey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  // Botón Siguiente / Empezar
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    onPressed: _nextPage,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _totalPages - 1
                              ? (isEn ? 'Start Exploring!' : '¡A Comer!')
                              : (isEn ? 'Next' : 'Siguiente'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _currentPage == _totalPages - 1 ? Icons.check : Icons.arrow_forward,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 0: Descubre Huecas
  Widget _buildSlide0Huecas(bool isEn) {
    return _buildSlideTemplate(
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&auto=format&fit=crop&q=80',
      imageBadge: isEn ? '🇪🇨 Quito Tradition' : '🇪🇨 Tradición Quiteña',
      icon: Icons.restaurant,
      gradientColors: [const Color(0xFFEA580C), const Color(0xFFF97316)],
      title: isEn ? "Discover Quito's Huecas" : 'Descubre las Mejores Huecas',
      subtitle: isEn
          ? 'Find traditional local eateries, authentic dishes, schedules, and real diner reviews.'
          : 'Encuentra locales tradicionales, platos típicos auténticos, horarios y valoraciones reales.',
      pills: [
        _buildPill(Icons.place, isEn ? 'Filter by Quito zones' : 'Filtro por sectores de Quito'),
        _buildPill(Icons.fastfood, isEn ? 'Menus with prices and spice levels' : 'Menús con precios y nivel de picante'),
        _buildPill(Icons.search, isEn ? 'Smart search by dish or craving' : 'Búsqueda por plato, antojo o ingrediente'),
      ],
      tip: isEn
          ? 'Tip: Tap any spot to view branches, photos, schedules, and reviews.'
          : 'Tip: Toca cualquier hueca para ver sus sucursales, fotos, horarios y opiniones.',
    );
  }

  // Slide 1: Mapa Interactivo en Vivo
  Widget _buildSlide1Mapa(bool isEn) {
    return _buildSlideTemplate(
      imageUrl: 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=800&auto=format&fit=crop&q=80',
      imageBadge: isEn ? '🧭 Real-time GPS' : '🧭 GPS en Tiempo Real',
      icon: Icons.map_rounded,
      gradientColors: [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
      title: isEn ? 'Live Interactive Map' : 'Mapa Interactivo en Vivo',
      subtitle: isEn
          ? 'Locate huecas around you in real time with interactive markers and quick preview cards.'
          : 'Ubica huecas a tu alrededor en tiempo real con pines interactivos y tarjetas de vista previa.',
      pills: [
        _buildPill(Icons.my_location, isEn ? 'Real-time GPS centering on your location' : 'Centrado automático con tu GPS en tiempo real'),
        _buildPill(Icons.touch_app, isEn ? 'Tap any pin to view info, rating & photos' : 'Toca cualquier pin para ver calificación, fotos y menú'),
        _buildPill(Icons.directions, isEn ? 'Direct "How to get there" route in Google Maps' : 'Botón directo "Cómo llegar" para navegar al local'),
      ],
      tip: isEn
          ? 'Tip: Switch between Map view and List view anytime with the top bar toggle!'
          : 'Tip: ¡Puedes alternar entre vista de Mapa y Lista en cualquier momento!',
    );
  }

  // Slide 2: Rutas Gastronómicas
  Widget _buildSlide2Rutas(bool isEn) {
    return _buildSlideTemplate(
      imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&auto=format&fit=crop&q=80',
      imageBadge: isEn ? '🚶‍♂️ Food Routes' : '🚶‍♂️ Circuitos Culinarios',
      icon: Icons.alt_route_rounded,
      gradientColors: [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
      title: isEn ? 'Guided Food Routes' : 'Rutas Culinarias Guiadas',
      subtitle: isEn
          ? 'Explore curated itineraries step-by-step with guided GPS navigation across Quito.'
          : 'Recorre circuitos temáticos paso a paso con navegación guiada por los barrios de Quito.',
      pills: [
        _buildPill(Icons.timeline, isEn ? 'Ordered stops with time & distance' : 'Paradas ordenadas con tiempo y distancia'),
        _buildPill(Icons.navigation, isEn ? 'Turn-by-turn guidance to each spot' : 'Navegación guiada hasta cada parada'),
        _buildPill(Icons.groups, isEn ? 'Tours for families, friends & foodies' : 'Circuitos para familias, parejas y amigos'),
      ],
      tip: isEn
          ? 'Tip: Access routes from the Map or the Routes tab in the main menu.'
          : 'Tip: Encuentra las rutas en la pestaña Rutas del mapa o en el menú principal.',
    );
  }

  // Slide 3: Cartilla de Sellos
  Widget _buildSlide3Sellos(bool isEn) {
    return _buildSlideTemplate(
      imageUrl: 'https://images.unsplash.com/photo-1556742049-0a67c5574f73?w=800&auto=format&fit=crop&q=80',
      imageBadge: isEn ? '🎁 Free Rewards' : '🎁 Premios y Cortesías',
      icon: Icons.loyalty_rounded,
      gradientColors: [const Color(0xFFD97706), const Color(0xFFF59E0B)],
      title: isEn ? 'Loyalty Stamp Card' : 'Cartilla Digital de Sellos',
      subtitle: isEn
          ? 'Earn stamps on every visit! Fill your digital loyalty card to unlock free delicious rewards.'
          : '¡Gana sellos con cada consumo! Completa tu cartilla digital y canjea platos o premios gratis.',
      pills: [
        _buildPill(Icons.qr_code_2, isEn ? 'Ask the spot to stamp your digital card' : 'Pide tu sello digital al consumir en cada hueca'),
        _buildPill(Icons.check_circle_outline, isEn ? 'Target of 5 or 10 stamps per local' : 'Meta de 5 o 10 sellos según la hueca'),
        _buildPill(Icons.card_giftcard, isEn ? 'Free dishes and spot surprise gifts' : 'Platos de cortesía y premios sorpresa'),
      ],
      tip: isEn
          ? 'Tip: Check your active stamp cards under the "Cards by Spot" tab in My Album.'
          : 'Tip: Consulta tus sellos acumulados en la pestaña "Cartillas por Hueca" de Mi Álbum.',
    );
  }

  // Slide 4: Cromos Secretos por Sector
  Widget _buildSlide4Cromos(bool isEn) {
    return _buildSlideTemplate(
      imageUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=800&auto=format&fit=crop&q=80',
      imageBadge: isEn ? '🔑 Secret Stickers' : '🔑 Cromos Secretos',
      icon: Icons.collections_bookmark_rounded,
      gradientColors: [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
      title: isEn ? 'Secret Sector Stickers' : 'Álbum de Cromos por Sector',
      subtitle: isEn
          ? 'Discover secret stickers hidden in each spot to complete albums for every sector of Quito!'
          : '¡Descubre los stickers secretos ocultos en cada local y llena tu álbum por sectores de Quito!',
      pills: [
        _buildPill(Icons.star, isEn ? 'Find and scan secret QRs inside the spots' : 'Busca y escanea el QR secreto dentro de cada hueca'),
        _buildPill(Icons.map, isEn ? 'Albums for Centro Histórico, Floresta, Valles...' : 'Colecciones por Centro Histórico, Floresta, Valles...'),
        _buildPill(Icons.add_task, isEn ? '+50 bonus points for each new secret sticker' : '+50 puntos extra por cada cromo secreto'),
      ],
      tip: isEn
          ? 'Tip: Tap any sector in My Album to see locked mystery stickers and clues!'
          : 'Tip: Presiona un sector en "Mi Álbum" para ver las pistas de los cromos misteriosos.',
    );
  }

  // Slide 5: Escaneo Rápido y Modo Invitado
  Widget _buildSlide5Escaneo(bool isEn) {
    return _buildSlideTemplate(
      imageUrl: 'https://images.unsplash.com/photo-1595079672139-6274e1d74301?w=800&auto=format&fit=crop&q=80',
      imageBadge: isEn ? '📲 Guest & Cloud Mode' : '📲 Modo Invitado y Nube',
      icon: Icons.qr_code_scanner_rounded,
      gradientColors: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
      title: isEn ? "Instant Scan & Guest Safe Mode" : '¡Todo Listo para Empezar!',
      subtitle: isEn
          ? 'Scan stamps and secret stickers anytime! Even in Guest mode, your progress is saved on your device.'
          : '¡Escanea sellos y cromos en cualquier momento! Incluso como Invitado, tu progreso queda guardado en tu celular.',
      pills: [
        _buildPill(Icons.camera_alt, isEn ? 'Instant camera scanning from the center button' : 'Escaneo instantáneo con el botón central de la barra'),
        _buildPill(Icons.phone_android, isEn ? 'Guest stamps & stickers saved locally on device' : 'Sellos y cromos de invitado guardados en tu celular'),
        _buildPill(Icons.cloud_sync, isEn ? 'Automatic cloud sync whenever you sign in' : 'Sincronización automática a la nube al iniciar sesión'),
      ],
      tip: isEn
          ? 'Tip: You never lose progress: when you log in, local guest stamps merge into your account!'
          : 'Tip: ¡No pierdes nada! Al iniciar sesión con tu cuenta, tus sellos locales se unen a tu perfil.',
    );
  }

  Widget _buildSlideTemplate({
    required String imageUrl,
    required String imageBadge,
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required List<Widget> pills,
    required String tip,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Banner fotográfico de alta calidad con badge flotante
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  height: 125,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 125,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 48),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 125,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            gradientColors.first.withOpacity(0.3),
                            gradientColors.last.withOpacity(0.15),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(icon, color: Colors.blueGrey.shade400, size: 28),
                      ),
                    );
                  },
                ),
                // Gradiente inferior para legibilidad
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Badge flotante en la esquina inferior izquierda
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      imageBadge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Icono temático flotante en la esquina superior derecha
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Título
          Text(
            title,
            style: const TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),

          // Subtítulo
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade600,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Pills de características
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: pills,
            ),
          ),
          const SizedBox(height: 10),

          // Tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
