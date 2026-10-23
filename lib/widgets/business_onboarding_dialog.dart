import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/theme/theme.dart';

Future<void> showBusinessOnboardingDialog(
  BuildContext context,
  Hueca hueca, {
  bool markAsSeen = true,
}) async {
  if (markAsSeen) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_business_tutorial_${hueca.id}', true);
    } catch (_) {}
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => BusinessOnboardingDialog(hueca: hueca),
  );
}

class BusinessOnboardingDialog extends StatefulWidget {
  final Hueca hueca;

  const BusinessOnboardingDialog({super.key, required this.hueca});

  @override
  State<BusinessOnboardingDialog> createState() => _BusinessOnboardingDialogState();
}

class _BusinessOnboardingDialogState extends State<BusinessOnboardingDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 7;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
      context.go('/business/profile');
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
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          children: [
            // Header con botón cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.rocket_launch, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guía de tu Negocio',
                          style: TextStyle(
                            color: Colors.blueGrey.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.hueca.name,
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.blueGrey),
                    tooltip: 'Cerrar Guía',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Contenido en PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeSlide(),
                  _buildProfileSlide(),
                  _buildMenuSlide(),
                  _buildQrSlide(),
                  _buildSubscriptionSlide(),
                  _buildNotificationsSlide(),
                  _buildDashboardSlide(),
                ],
              ),
            ),

            // Footer con indicadores de paso y botones
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  // Botón Atrás o Saltar
                  if (_currentPage > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueGrey.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _prevPage,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, size: 14),
                          SizedBox(width: 4),
                          Text('Atrás', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    )
                  else
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueGrey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Saltar', style: TextStyle(fontSize: 12)),
                    ),

                  // Indicadores de puntos
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_totalPages, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: isActive ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primary : Colors.blueGrey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  // Botón Siguiente o Finalizar
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    onPressed: _nextPage,
                    child: Text(
                      _currentPage == _totalPages - 1 ? '¡Configurar!' : 'Siguiente',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

  // SLIDE 0: Bienvenida
  Widget _buildWelcomeSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.deepOrange.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 54),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Bienvenido a HueQuito!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Pon tu hueca en orden en 6 sencillos pasos',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Tu local ya está registrado en HueQuito con datos básicos. Ahora es tu turno de subir fotos llamativas, digitalizar tu menú con IA y activar tus sellos QR para que los comensales se enamoren de tu sazón.',
              style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          _buildFeatureCheckItem(Icons.store, 'Pestaña Perfil: Horarios, fotos reales y Sticker Secreto imprimible'),
          _buildFeatureCheckItem(Icons.restaurant_menu, 'Pestaña Menú: Digitalización asistida por IA'),
          _buildFeatureCheckItem(Icons.qr_code, 'Pestaña Mi QR: Otorga puntos y sellos con QR dinámico antifraude'),
          _buildFeatureCheckItem(Icons.card_membership, 'Plan Gratuito: Tus primeros 50 sellos entregados son 100% gratis'),
          _buildFeatureCheckItem(Icons.campaign, 'Pestaña Avisos: Envía promociones a tus clientes'),
          _buildFeatureCheckItem(Icons.bar_chart, 'Pestaña Dashboard: Vistas y favoritos en tiempo real'),
        ],
      ),
    );
  }

  Widget _buildFeatureCheckItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.check, size: 14, color: Colors.green.shade800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // SLIDE 1: Pestaña Perfil
  Widget _buildProfileSlide() {
    return _buildStepSlide(
      stepNumber: '1',
      tabName: 'Perfil',
      tabIcon: Icons.store,
      title: 'Aca pones todo sobre tu negocio',
      subtitle: 'Fotos de tu local, horarios, teléfonos y tu Sticker Secreto',
      mockupWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Sube tus mejores fotos',
                      style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildMockField(Icons.location_on, 'Dirección: ${widget.hueca.address}'),
            _buildMockField(Icons.access_time, 'Horarios: Lun-Dom 08:00 - 18:00'),
            _buildMockField(Icons.stars, 'Sticker Secreto: Descárgalo e imprímelo aquí'),
          ],
        ),
      ),
      description:
          'En la pestaña "Perfil" personalizas la identidad de tu hueca: teléfonos de pedidos, horarios de atención y fotos de tu local. Además, aquí configuras y descargas tu Sticker Secreto oficial para imprimirlo y colocarlo físicamente en tu local.',
      actionLabel: 'Ir a Perfil',
      onAction: () {
        Navigator.of(context).pop();
        context.go('/business/profile');
      },
    );
  }

  // SLIDE 2: Pestaña Menú con IA
  Widget _buildMenuSlide() {
    return _buildStepSlide(
      stepNumber: '2',
      tabName: 'Menú',
      tabIcon: Icons.restaurant_menu,
      title: 'Aca gestionas tu menú con IA',
      subtitle: 'Foto a tu carta física y transcripción inteligente',
      mockupWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Escanear Carta con IA ✨',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plato Insignia • \$5.50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('Traducido automáticamente al inglés 🇺🇸', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      description:
          '¡Olvídate de escribir plato por plato! En la pestaña "Menú" toma una foto clara de tu menú físico o pizarra y la Inteligencia Artificial transcribirá tus platos, precios e ingredientes, traduciéndolos al inglés para los visitantes.',
      actionLabel: 'Ir a Menú con IA',
      onAction: () {
        Navigator.of(context).pop();
        context.go('/business/menu');
      },
    );
  }

  // SLIDE 3: Pestaña Mi QR
  Widget _buildQrSlide() {
    return _buildStepSlide(
      stepNumber: '3',
      tabName: 'Mi QR',
      tabIcon: Icons.qr_code,
      title: 'Aca entregas sellos y puntos con QR',
      subtitle: 'Elige los sellos a dar con un QR dinámico que se regenera',
      mockupWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Mi QR de Caja',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 13, color: Colors.blueGrey),
                      SizedBox(width: 4),
                      Text('Historial', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2, color: Colors.white, size: 48),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline, size: 12, color: Colors.orange.shade900),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Entrega: 1 a 10 sellos',
                                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 10.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: Colors.teal),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Se regenera cada 30s antifraude',
                              style: TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      description:
          'En "Mi QR" entregas sellos y puntos de fidelidad a tus comensales por su consumo. Puedes seleccionar cuántos sellos otorgar (1, 2, 3...) y el código se regenera automáticamente cada 30 segundos para evitar capturas. ¡Tus primeros 50 sellos son 100% gratuitos para que impulses tu negocio sin ningún costo inicial!',
      actionLabel: 'Ver Mi QR',
      onAction: () {
        Navigator.of(context).pop();
        context.go('/business/qr');
      },
    );
  }

  // SLIDE 4: Pestaña Plan Gratuito y Suscripción
  Widget _buildSubscriptionSlide() {
    return _buildStepSlide(
      stepNumber: '4',
      tabName: 'Suscripción',
      tabIcon: Icons.card_membership,
      title: 'Plan Gratuito y Suscripción',
      subtitle: 'Comienza 100% gratis y escala según tu crecimiento',
      mockupWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.green.shade800, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tus primeros 50 sellos son 100% GRATIS',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Meta Gratuita', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                        const Text('50 Sellos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('Sin costo inicial', style: TextStyle(fontSize: 9.5, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mensualidad', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                        const Text('\$9.99 / mes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        const Text('7 días de gracia', style: TextStyle(fontSize: 9.5, color: Colors.orange, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance, color: Colors.amber.shade900, size: 14),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Transferencia (Banco Pichincha) con foto de comprobante',
                      style: TextStyle(color: Color(0xFF78350F), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      description:
          '¡Queremos que pruebes HueQuito sin riesgo! Tus primeros 50 sellos entregados a tus comensales son 100% gratuitos. Al alcanzar los 50 sellos, se activará la suscripción mensual de \$9.99/mes con 7 días de gracia para que sigas fidelizando clientes sin interrupciones. Podrás transferir fácilmente a nuestra cuenta de Banco Pichincha y subir la foto del comprobante directamente desde tu panel para su verificación en 24-48 horas.',
      actionLabel: 'Ver Plan y Pagos',
      onAction: () {
        Navigator.of(context).pop();
        context.go('/business/dashboard');
      },
    );
  }

  // SLIDE 5: Pestaña Avisos
  Widget _buildNotificationsSlide() {
    return _buildStepSlide(
      stepNumber: '5',
      tabName: 'Avisos',
      tabIcon: Icons.campaign,
      title: 'Aca pides notificaciones y avisos',
      subtitle: 'Comunica promociones y platos del día a tus comensales',
      mockupWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¡Hoy Fritada Especial 2x1!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF78350F))),
                        Text('Enviado a los comensales que te tienen en favoritos', style: TextStyle(color: Color(0xFF92400E), fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified, size: 13, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Revisado y aprobado por administración',
                    style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      description:
          'En la pestaña "Avisos" puedes redactar avisos sobre promociones, platos de fin de semana o eventos. Tu solicitud pasa por una rápida revisión del administrador para asegurar la calidad antes de ser enviada a los teléfonos de tus clientes.',
      actionLabel: 'Ir a Avisos',
      onAction: () {
        Navigator.of(context).pop();
        context.go('/business/notifications');
      },
    );
  }

  // SLIDE 6: Pestaña Dashboard
  Widget _buildDashboardSlide() {
    return _buildStepSlide(
      stepNumber: '6',
      tabName: 'Dashboard',
      tabIcon: Icons.bar_chart,
      title: 'Aqui estan tus dashboards y métricas',
      subtitle: 'Monitorea el impacto de tu hueca en tiempo real',
      mockupWidget: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Row(
          children: [
            Expanded(child: _buildMetricTile('Vistas', '1.2k', Icons.visibility, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('Favoritos', '84', Icons.favorite, Colors.red)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('En Rutas', '3', Icons.alt_route, Colors.teal)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('Sellos', '45', Icons.stars, Colors.amber)),
          ],
        ),
      ),
      description:
          'En este "Dashboard" revisas tus métricas reales: cuántas personas han visto tu ficha, cuántos comensales te han marcado como favorito, en cuántas rutas gastronómicas de Quito estás y el estado de tu Plan Gratuito con tus días y sellos disponibles.',
      actionLabel: '¡Comenzar a Configurar!',
      onAction: () {
        Navigator.of(context).pop();
        context.go('/business/profile');
      },
    );
  }

  Widget _buildStepSlide({
    required String stepNumber,
    required String tabName,
    required IconData tabIcon,
    required String title,
    required String subtitle,
    required Widget mockupWidget,
    required String description,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tabIcon, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Paso $stepNumber • Pestaña "$tabName"',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
          ),
          const SizedBox(height: 14),
          mockupWidget,
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              description,
              style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              icon: Icon(tabIcon, size: 16),
              label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onAction,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockField(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.blueGrey.shade700)),
        ],
      ),
    );
  }
}
