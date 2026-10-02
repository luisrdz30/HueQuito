import 'package:hue_quito/utils/seed_data.dart' as seed;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/utils/auth_utils.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/providers/auth_provider.dart' hide currentUserProvider;

import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedLocation = 'Todo Quito';
  String _selectedFilter = '🍲 Todos';
  String _selectedSort = 'Más cerca (km)';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> _locations = lang == 'es' ? ['Centro Histórico', 'La Floresta', 'Conocoto', 'Todo Quito'] : ['Historic Center', 'La Floresta', 'Conocoto', 'All Quito'];
    final List<String> _filters = lang == 'es' ? ['🍽️ Todos', '🍲 Sopas', '🍛 Platos Fuertes', '⭐ Tradición', '🍰 Dulces'] : ['🍽️ All', '🍲 Soups', '🍛 Main Dishes', '⭐ Tradition', '🍰 Sweets'];

    if (!_locations.contains(_selectedLocation)) {
      _selectedLocation = _locations.last;
    }
    if (!_filters.contains(_selectedFilter)) {
      _selectedFilter = _filters.first;
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.cloud_upload, color: AppTheme.primary),
          onPressed: () async {
            await seed.seedHuecas(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Huecas importadas a Firebase')));
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hue-Quito', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                Text(lang == 'es' ? 'Explorar' : 'Explore', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium)),
              ],
            )
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocation,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMedium, size: 16),
                isDense: true,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() { _selectedLocation = newValue; });
                  }
                },
                items: _locations.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Qué se te antoja hoy?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) => _buildFilterChip(f, _selectedFilter == f)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          huecasAsync.when(
            data: (huecas) {
              var filtered = List<Hueca>.from(huecas);
              if (_selectedLocation != 'Todo Quito') {
                filtered = filtered.where((h) => h.sector.toLowerCase().contains(_selectedLocation.toLowerCase()) || h.address.toLowerCase().contains(_selectedLocation.toLowerCase())).toList();
              }
              if (!_selectedFilter.contains('Todos')) {
                String tag = _selectedFilter.split(' ')[1].toLowerCase();
                if (tag == 'platos') tag = 'plato';
                filtered = filtered.where((h) => h.tags.any((t) => t.toLowerCase().contains(tag))).toList();
              }
              if (filtered.isEmpty) filtered = List<Hueca>.from(huecas);

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildHuecaCard(context, hueca: filtered[index], lang: lang);
                  },
                  childCount: filtered.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => SliverFillRemaining(child: Center(child: Text('Error: $err'))),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = text),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textMedium,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHuecaCard(BuildContext context, {required Hueca hueca, String lang = 'es'}) {
    final user = ref.watch(currentUserProvider).value;
    final imageUrl = hueca.images.isNotEmpty ? hueca.images[0] : 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: hueca.tags.map((t) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                          child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (!AuthUtils.checkAuthAndPrompt(context)) return;
                          await ref.read(userRepositoryProvider).toggleFavorite(hueca.id);
                          ref.invalidate(currentUserProvider);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.8), shape: BoxShape.circle),
                          child: Icon((user?.favoriteHuecas.contains(hueca.id) ?? false) ? Icons.favorite : Icons.favorite_border, size: 18, color: (user?.favoriteHuecas.contains(hueca.id) ?? false) ? Colors.red : AppTheme.textDark),
                        ),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            child: const Row(children: [Icon(Icons.near_me, color: AppTheme.primary, size: 12), SizedBox(width: 4), Text('2.5 km', style: TextStyle(color: Colors.white, fontSize: 10))]),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [const Icon(Icons.payments, color: Colors.white, size: 12), const SizedBox(width: 4), Text('\$${hueca.mainDish["price"] ?? "5.0"}', style: const TextStyle(color: Colors.white, fontSize: 10))]),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: AppTheme.primary, size: 14),
                            const SizedBox(width: 4),
                            Text('${hueca.rating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 2),
                            Text('(${hueca.reviewCount})', style: const TextStyle(color: AppTheme.textMedium, fontSize: 10)),
                          ],
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hueca.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.tertiary, size: 14),
                    const SizedBox(width: 4),
                    Expanded(child: Text(hueca.address, style: const TextStyle(color: AppTheme.textMedium, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Text('${hueca.mainDish["emoji"] ?? "🍲"}', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang == 'es' ? 'PLATO INSIGNIA' : 'SIGNATURE DISH', style: TextStyle(color: AppTheme.textMedium, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(
                              hueca.mainDish['name'] is Map 
                                ? (hueca.mainDish['name'][lang] ?? hueca.mainDish['name']['es'] ?? hueca.mainDish['name'].values.first)
                                : (hueca.mainDish['name'].toString().contains('$lang:') 
                                    ? hueca.mainDish['name'].toString().split('$lang:')[1].split('}')[0].trim() 
                                    : (hueca.mainDish['name'].toString().contains('es:') 
                                      ? hueca.mainDish['name'].toString().split('es:')[1].split('}')[0].trim() 
                                      : hueca.mainDish['name'].toString())), 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final availableMaps = await MapLauncher.installedMaps;
                          if (availableMaps.isNotEmpty) {
                            availableMaps.first.showMarker(
                              coords: Coords(hueca.location.latitude, hueca.location.longitude),
                              title: hueca.name,
                            );
                          } else {
                            final url = 'https://www.google.com/maps/search/?api=1&query=${hueca.location.latitude},${hueca.location.longitude}';
                            if (await canLaunchUrl(Uri.parse(url))) {
                              await launchUrl(Uri.parse(url));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], foregroundColor: AppTheme.secondary, elevation: 0),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions, size: 16), SizedBox(width: 4), Text('Cómo llegar', style: TextStyle(fontSize: 12))]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
context.push('/hueca_detail', extra: hueca);
                        },
                        style: ElevatedButton.styleFrom(elevation: 4),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Ver Hueca', style: TextStyle(fontSize: 12)), SizedBox(width: 4), Icon(Icons.arrow_forward, size: 16)]),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
