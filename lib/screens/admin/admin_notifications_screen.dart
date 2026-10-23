import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/models/notification_model.dart';
import 'package:hue_quito/services/notification_service.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _historyTimeFilter = 'recent'; // 'recent', 'month', 'older', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveNotification(NotificationModel item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isScheduled = item.isScheduled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isScheduled ? '¿Aprobar Notificación Programada?' : '¿Aprobar y Emitir?'),
        content: Text(
          isScheduled
              ? 'La notificación "${item.title}" quedará aprobada y se emitirá automáticamente en la fecha programada (${item.formattedScheduledDate}) a los usuarios suscritos a ${item.huecaName}.'
              : 'La notificación "${item.title}" será enviada de inmediato al panel de Android de todos los usuarios suscritos a ${item.huecaName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isScheduled ? Colors.teal : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isScheduled ? 'Aprobar Programada' : 'Aprobar y Emitir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(notificationRepositoryProvider)
            .approveNotification(item.id, user.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Notificación aprobada y emitida exitosamente.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _rejectNotification(NotificationModel item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rechazar Notificación'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el motivo del rechazo para que el dueño de ${item.huecaName} pueda corregirlo:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ej. No se especifica fecha de vigencia o las condiciones de la promo...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Por favor escribe el motivo'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirmar Rechazo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(notificationRepositoryProvider).rejectNotification(
              notificationId: item.id,
              adminUid: user.uid,
              reason: reasonCtrl.text.trim(),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notificación rechazada y notificada al negocio.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingNotificationsProvider);
    final allAsync = ref.watch(allNotificationsProvider);
    final pendingRequestsAsync = ref.watch(pendingHuecaRequestsProvider);
    final newSupportAsync = ref.watch(newSupportMessagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingCount = pendingAsync.value?.length ?? 0;
    final pendingRequestsCount = pendingRequestsAsync.value?.length ?? 0;
    final newSupportCount = newSupportAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Moderación de Notificaciones', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Actualizar lista',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(pendingNotificationsProvider);
              ref.invalidate(allNotificationsProvider);
              ref.invalidate(pendingHuecaRequestsProvider);
              ref.invalidate(newSupportMessagesProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lista de notificaciones actualizada'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.secondary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pendientes'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Historial Completo'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildQuickAccessBar(context, pendingRequestsCount, newSupportCount),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(pendingAsync, isDark),
                _buildAllTab(allAsync, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessBar(BuildContext context, int pendingRequestsCount, int newSupportCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                'OTRAS BANDEJAS DE GESTIÓN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickNavCard(
                  context: context,
                  icon: Icons.add_business_rounded,
                  iconColor: Colors.amber,
                  title: 'Solicitudes',
                  subtitle: 'Huecas nuevas',
                  badgeCount: pendingRequestsCount,
                  badgeColor: Colors.amber.shade800,
                  onTap: () => context.push('/admin/solicitudes'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickNavCard(
                  context: context,
                  icon: Icons.support_agent_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'Soporte',
                  subtitle: 'De negocios',
                  badgeCount: newSupportCount,
                  badgeColor: Colors.redAccent,
                  onTap: () => context.push('/admin/support'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int badgeCount,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: badgeCount > 0 ? iconColor.withOpacity(0.4) : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingTab(AsyncValue<List<NotificationModel>> pendingAsync, bool isDark) {
    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 70, color: Colors.green.shade400),
                const SizedBox(height: 16),
                const Text(
                  '¡Al día! No hay notificaciones pendientes.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cuando los negocios soliciten anuncios, aparecerán aquí.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildPendingCard(item, isDark);
          },
        );
      },
    );
  }

  Widget _buildPendingCard(NotificationModel item, bool isDark) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hueca Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(item.categoryEmoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.huecaName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        item.branchName != null
                            ? 'Sucursal: ${item.branchName}'
                            : 'Categoría: ${item.categoryDisplay}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (item.discountTag != null && item.discountTag!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.discountTag!,
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (item.formattedScheduledDate != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Programada para: ${item.formattedScheduledDate}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Emisión solicitada: Inmediata tras aprobación',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Mockup Preview
            const Text(
              'Simulación de cómo saldrá en Android:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.restaurant, size: 12, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Hue-Quito • ahora',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.categoryEmoji} ${item.huecaName}: ${item.title}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: const TextStyle(fontSize: 12, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Color(0xFFDC2626), size: 18),
                    label: const Text('Rechazar', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _rejectNotification(item),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                    label: const Text('Aprobar y Emitir', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _approveNotification(item),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTab(AsyncValue<List<NotificationModel>> allAsync, bool isDark) {
    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No hay registros en el historial.'));
        }

        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));

        final recentCount = items.where((i) {
          final d = i.approvedAt ?? i.createdAt;
          return !d.isBefore(sevenDaysAgo);
        }).length;

        final monthCount = items.where((i) {
          final d = i.approvedAt ?? i.createdAt;
          return !d.isBefore(thirtyDaysAgo);
        }).length;

        final olderCount = items.where((i) {
          final d = i.approvedAt ?? i.createdAt;
          return d.isBefore(thirtyDaysAgo);
        }).length;

        final filteredItems = items.where((item) {
          final d = item.approvedAt ?? item.createdAt;
          if (_historyTimeFilter == 'recent') {
            return !d.isBefore(sevenDaysAgo);
          } else if (_historyTimeFilter == 'month') {
            return !d.isBefore(thirtyDaysAgo);
          } else if (_historyTimeFilter == 'older') {
            return d.isBefore(thirtyDaysAgo);
          }
          return true; // 'all'
        }).toList();

        return Column(
          children: [
            // Barra de filtros por período de tiempo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: '⚡ Esta Semana ($recentCount)',
                      isSelected: _historyTimeFilter == 'recent',
                      onTap: () => setState(() => _historyTimeFilter = 'recent'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '📅 Este Mes ($monthCount)',
                      isSelected: _historyTimeFilter == 'month',
                      onTap: () => setState(() => _historyTimeFilter = 'month'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '📜 Anteriores ($olderCount)',
                      isSelected: _historyTimeFilter == 'older',
                      onTap: () => setState(() => _historyTimeFilter = 'older'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '🌐 Todas (${items.length})',
                      isSelected: _historyTimeFilter == 'all',
                      onTap: () => setState(() => _historyTimeFilter = 'all'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            // Lista filtrada de notificaciones
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No hay notificaciones en este período',
                            style: TextStyle(
                              color: Colors.blueGrey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => setState(() => _historyTimeFilter = 'all'),
                            child: Text('Ver todas las notificaciones (${items.length})'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildHistoryItem(item, isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F172A)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.amber
                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.amber : (isDark ? Colors.white70 : const Color(0xFF334155)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(NotificationModel item, bool isDark) {
    Color badgeColor;
    String badgeText;

    if (item.status == 'approved') {
      badgeColor = Colors.green;
      badgeText = 'Aprobada';
    } else if (item.status == 'rejected') {
      badgeColor = Colors.red;
      badgeText = 'Rechazada';
    } else {
      badgeColor = Colors.amber.shade800;
      badgeText = 'Pendiente';
    }

    final pubDate = item.approvedAt ?? item.createdAt;
    final dateStr = '${pubDate.day.toString().padLeft(2, '0')}/${pubDate.month.toString().padLeft(2, '0')}/${pubDate.year}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${item.categoryEmoji} ${item.huecaName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(item.message, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (item.formattedScheduledDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Programada: ${item.formattedScheduledDate}',
                    style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if (item.rejectionReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Motivo: ${item.rejectionReason}',
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
