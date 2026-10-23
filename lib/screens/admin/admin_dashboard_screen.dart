import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/models/notification_model.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final huecasAsync = ref.watch(allHuecasStreamProvider);
    final usersAsync = ref.watch(allUsersStreamProvider);
    final pendingNotifsAsync = ref.watch(pendingNotificationsProvider);
    final pendingRequestsAsync = ref.watch(pendingHuecaRequestsProvider);
    final newSupportAsync = ref.watch(newSupportMessagesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFF0F172A),
        onRefresh: () async {
          ref.invalidate(allHuecasStreamProvider);
          ref.invalidate(allUsersStreamProvider);
          ref.invalidate(pendingNotificationsProvider);
          ref.invalidate(pendingHuecaRequestsProvider);
          ref.invalidate(newSupportMessagesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner (Dark executive banner)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.shade400, width: 2),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 34),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Centro de Control',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gestión global del ecosistema gastronómico',
                            style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // KPI Cards Grid
              const Text(
                'Métricas Clave',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Huecas',
                      icon: Icons.restaurant,
                      iconColor: Colors.deepOrange,
                      value: huecasAsync.when(
                        data: (h) => '${h.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      subtitle: huecasAsync.when(
                        data: (h) => '${h.where((x) => x.isActive).length} activas',
                        loading: () => 'Cargando...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => context.go('/admin/huecas'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Usuarios',
                      icon: Icons.people,
                      iconColor: Colors.blue.shade700,
                      value: usersAsync.when(
                        data: (u) => '${u.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      subtitle: usersAsync.when(
                        data: (u) {
                          final businessCount = u.where((x) => x.role == 'business').length;
                          return '$businessCount negocios';
                        },
                        loading: () => 'Cargando...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => context.go('/admin/users'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Avisos Pendientes',
                      icon: Icons.campaign,
                      iconColor: Colors.amber.shade800,
                      value: pendingNotifsAsync.when(
                        data: (p) => '${p.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      subtitle: pendingNotifsAsync.when(
                        data: (p) => p.isEmpty ? 'Todo al día' : 'Requieren revisión',
                        loading: () => 'Cargando...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => context.go('/admin/notifications'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Sectores y Cromos',
                      icon: Icons.collections_bookmark,
                      iconColor: Colors.teal.shade700,
                      value: '22',
                      subtitle: 'Álbum y mapa',
                      onTap: () => context.push('/admin/sectors'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Solicitudes Huecas',
                      icon: Icons.how_to_reg,
                      iconColor: Colors.deepPurple,
                      value: pendingRequestsAsync.when(
                        data: (p) => '${p.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      subtitle: pendingRequestsAsync.when(
                        data: (p) => p.isEmpty ? 'Sin solicitudes' : '${p.length} por revisar',
                        loading: () => 'Cargando...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => context.go('/admin/solicitudes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Bandeja Soporte',
                      icon: Icons.support_agent,
                      iconColor: Colors.indigo.shade600,
                      value: newSupportAsync.when(
                        data: (s) => '${s.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      subtitle: newSupportAsync.when(
                        data: (s) => s.isEmpty ? 'Todo respondido' : '${s.length} nuevos',
                        loading: () => 'Cargando...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => context.push('/admin/support'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Suscripciones',
                      icon: Icons.payments,
                      iconColor: Colors.green.shade700,
                      value: huecasAsync.when(
                        data: (h) {
                          final underReview = h.where((x) => x.subscription['status'] == 'under_review').length;
                          return '$underReview';
                        },
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      subtitle: huecasAsync.when(
                        data: (h) {
                          final underReview = h.where((x) => x.subscription['status'] == 'under_review').length;
                          return underReview == 0 ? 'Sin comprobantes' : '$underReview por validar';
                        },
                        loading: () => 'Cargando...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => context.go('/admin/subscriptions'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Quiz y ADN',
                      icon: Icons.quiz,
                      iconColor: Colors.pink.shade700,
                      value: '4',
                      subtitle: 'Preguntas activas',
                      onTap: () => context.push('/admin/quiz'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Acciones Rápidas (Botones Oscuros como solicitó)
              const Text(
                'Acciones Rápidas',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      label: 'Nueva Hueca',
                      icon: Icons.add_business,
                      color: Colors.amber.shade400,
                      onTap: () => context.push('/admin/huecas/new'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      label: 'Sectores y Cromos',
                      icon: Icons.collections_bookmark,
                      color: Colors.tealAccent.shade400,
                      onTap: () => context.push('/admin/sectors'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      label: 'Quiz Gastronómico',
                      icon: Icons.quiz,
                      color: Colors.orangeAccent.shade400,
                      onTap: () => context.push('/admin/quiz'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      label: 'Solicitudes Huecas',
                      icon: Icons.assignment_turned_in,
                      color: Colors.lightGreenAccent.shade400,
                      onTap: () => context.go('/admin/solicitudes'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      label: 'Bandeja Soporte',
                      icon: Icons.headset_mic,
                      color: Colors.cyanAccent.shade400,
                      onTap: () => context.push('/admin/support'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      label: 'Reseñas',
                      icon: Icons.reviews,
                      color: Colors.purple.shade300,
                      onTap: () => context.push('/admin/reviews'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Avisos pendientes destacados
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Moderación de Avisos',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/admin/notifications'),
                    child: Text('Ver todos', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              pendingNotifsAsync.when(
                data: (pendingList) {
                  if (pendingList.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 40),
                          const SizedBox(height: 8),
                          const Text(
                            '¡No hay avisos pendientes!',
                            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Todas las solicitudes de los negocios han sido procesadas.',
                            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: pendingList.take(3).map((notif) {
                      return _buildPendingNotifItem(context, ref, notif);
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFF0F172A)),
                  ),
                ),
                error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.blueGrey.shade300, size: 12),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        elevation: 2,
        side: const BorderSide(color: Color(0xFF1E293B)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingNotifItem(BuildContext context, WidgetRef ref, NotificationModel notif) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.campaign, color: Colors.amber.shade800, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'De: ${notif.huecaName}',
                  style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => context.go('/admin/notifications'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
            icon: const Icon(Icons.arrow_forward, size: 14, color: Colors.amber),
            label: const Text('Revisar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
