import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/route_repository.dart';

class AdminRoutesScreen extends ConsumerStatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  ConsumerState<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends ConsumerState<AdminRoutesScreen> {
  String _searchQuery = '';

  Future<void> _deleteRoute(RouteModel route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('¿Eliminar Ruta?', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la ruta "${route.name['es'] ?? route.name.values.first}"?',
          style: TextStyle(color: Colors.blueGrey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(routeRepositoryProvider).deleteRoute(route.id);
        ref.invalidate(allRoutesStreamProvider);
        ref.invalidate(routesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Ruta eliminada exitosamente'), backgroundColor: Colors.redAccent),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar ruta: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(allRoutesStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header y Buscador
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
            ),
            child: TextField(
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Buscar rutas turísticas por nombre...',
                hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.blueGrey),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Lista de Rutas
          Expanded(
            child: routesAsync.when(
              data: (routesList) {
                final filtered = routesList.where((r) {
                  if (_searchQuery.isEmpty) return true;
                  final nameEs = (r.name['es']?.toString() ?? '').toLowerCase();
                  final nameEn = (r.name['en']?.toString() ?? '').toLowerCase();
                  return nameEs.contains(_searchQuery) || nameEn.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.alt_route, size: 54, color: Colors.blueGrey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No se encontraron rutas',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crea una nueva ruta gastronómica con el botón inferior.',
                          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final route = filtered[index];
                    return _buildRouteCard(route);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              error: (err, _) => Center(
                child: Text('Error cargando rutas: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A), // Botón oscuro
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Colors.tealAccent, fontWeight: FontWeight.bold),
        label: const Text('Nueva Ruta', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/admin/routes/new'),
      ),
    );
  }

  Widget _buildRouteCard(RouteModel route) {
    final name = route.name['es'] ?? route.name.values.firstOrNull ?? 'Ruta';
    final narrative = route.narrative['es'] ?? route.narrative.values.firstOrNull ?? '';
    final distance = route.metrics['distance'] ?? '0 km';
    final time = route.metrics['estimatedTime'] ?? '0 min';
    final stopsCount = route.stops.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Image.network(
                route.bannerImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(child: Icon(Icons.alt_route, color: Color(0xFF0F172A), size: 40)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$stopsCount paradas',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (narrative.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    narrative,
                    style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.directions_walk, size: 14, color: Colors.blueGrey.shade400),
                    const SizedBox(width: 4),
                    Text(distance, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
                    const SizedBox(width: 14),
                    Icon(Icons.timer_outlined, size: 14, color: Colors.blueGrey.shade400),
                    const SizedBox(width: 4),
                    Text(time, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
                  ],
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit, size: 15, color: Color(0xFF0F172A)),
                      label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      onPressed: () => context.push('/admin/routes/edit', extra: route),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF2F2),
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                      label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      onPressed: () => _deleteRoute(route),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
