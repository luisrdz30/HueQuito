import 'package:flutter/material.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:go_router/go_router.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hue-Quito', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                Text('Rutas', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium)),
              ],
            )
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              // Location selected in list view
            },
            itemBuilder: (BuildContext context) => ['Quito', 'Centro Histórico', 'La Floresta', 'Conocoto'].map((String key) {
              return PopupMenuItem<String>(
                value: key,
                child: Text(key),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                  SizedBox(width: 4),
                  Text('Centro Histórico', style: TextStyle(color: AppTheme.textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                  Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Circuitos Gastronómicos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Recorridos a pie curados para saborear Quito', style: TextStyle(color: AppTheme.textMedium)),
                  const SizedBox(height: 16),
                  
                  // Toggle Map / List
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.format_list_bulleted, size: 16, color: AppTheme.primary),
                                SizedBox(width: 4),
                                Text('Lista de circuitos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.go('/mapa_interactivo'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(30)),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map, size: 16, color: AppTheme.textMedium),
                                  SizedBox(width: 4),
                                  Text('Mapa interactivo', style: TextStyle(color: AppTheme.textMedium, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('Todos los circuitos', true),
                  _buildFilterChip('A pie (≤ 30 min)', false),
                  _buildFilterChip('Tradición e Historia', false),
                  _buildFilterChip('Café y Dulces', false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Route Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network('https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=400&q=80', height: 160, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                            child: const Row(children: [Icon(Icons.local_fire_department, color: Colors.white, size: 12), SizedBox(width: 4), Text('Circuito Popular', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]),
                          ),
                        ),
                        const Positioned(
                          bottom: 12,
                          left: 12,
                          child: Text('Ruta del Hornado y Tradición Colonial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                        )
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Desde la Plaza Grande hasta San Francisco, pasando por los hornados a leña más antiguos de Quito.', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(children: [Icon(Icons.straighten, color: AppTheme.primary, size: 20), Text('3.2 km', style: TextStyle(fontWeight: FontWeight.bold)), Text('Distancia', style: TextStyle(fontSize: 10, color: AppTheme.textMedium))]),
                                Column(children: [Icon(Icons.directions_walk, color: AppTheme.primary, size: 20), Text('45 min', style: TextStyle(fontWeight: FontWeight.bold)), Text('A pie', style: TextStyle(fontSize: 10, color: AppTheme.textMedium))]),
                                Column(children: [Icon(Icons.storefront, color: AppTheme.primary, size: 20), Text('4 huecas', style: TextStyle(fontWeight: FontWeight.bold)), Text('Paradas', style: TextStyle(fontSize: 10, color: AppTheme.textMedium))]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('PARADAS DEL RECORRIDO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMedium)),
                          const SizedBox(height: 8),
                          _buildStop(1, 'Hornado San Francisco', 'Mercado', 'Hornado con mote, llapingachos...'),
                          _buildStop(2, 'Ponches Don Michi', 'Plaza Grande', 'Ponche batido a mano...'),
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.push('/route_detail'), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.navigation), SizedBox(width: 8), Text('Ver detalles')]))),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: isActive ? AppTheme.tertiary : Colors.white, borderRadius: BorderRadius.circular(20), border: isActive ? null : Border.all(color: Colors.grey[300]!)),
      child: Text(label, style: TextStyle(color: isActive ? Colors.white : AppTheme.textMedium, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildStop(int number, String title, String location, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: number == 1 ? AppTheme.primary : Colors.grey[300], shape: BoxShape.circle), child: Center(child: Text('$number', style: TextStyle(color: number == 1 ? Colors.white : AppTheme.textDark, fontSize: 12, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(location, style: const TextStyle(fontSize: 10, color: AppTheme.textMedium))]),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
