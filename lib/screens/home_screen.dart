import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/utils/auth_utils.dart';

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
  final String _selectedSort = 'Más cerca (km)';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<String> locations = lang == 'es' ? ['Todo Quito'] : ['All Quito'];
    List<String> filters = lang == 'es' ? ['🍽️ Todos'] : ['🍽️ All'];

    if (huecasAsync.value != null && huecasAsync.value!.isNotEmpty) {
      final huecas = huecasAsync.value!;
      final baseLoc = huecas.map((h) => h.sector).toSet().where((s) => s.isNotEmpty).toList();
      locations.addAll(baseLoc);
      
      Map<String, int> tagCounts = {};
      for (var h in huecas) {
        for (var t in h.tags) { tagCounts[t] = (tagCounts[t] ?? 0) + 1; }
      }
      var sortedTags = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      var topTags = sortedTags.take(6).map((e) => e.key).toList();

      for (var tag in topTags) {
         String emoji = '🏷️';
         String tLower = tag.toLowerCase();
         if (tLower.contains('sopa') || tLower.contains('caldo')) {
           emoji = '🍲';
         } else if (tLower.contains('plato') || tLower.contains('carne') || tLower.contains('cerdo') || tLower.contains('marisco') || tLower.contains('pescado')) emoji = '🍛';
         else if (tLower.contains('tradici') || tLower.contains('mercado')) emoji = '⭐';
         else if (tLower.contains('dulce') || tLower.contains('postre')) emoji = '🍰';
         else if (tLower.contains('snack') || tLower.contains('frito') || tLower.contains('empanada')) emoji = '🥟';
         
         String translatedTag = tag;
         if (lang == 'en') {
           if (tLower == 'platos fuertes') {
             translatedTag = 'Main Dishes';
           } else if (tLower == 'sopas') translatedTag = 'Soups';
           else if (tLower == 'tradición' || tLower == 'tradicional') translatedTag = 'Tradition';
           else if (tLower == 'dulces') translatedTag = 'Sweets';
         }
         filters.add('$emoji $translatedTag');
      }
    } else {
      locations = lang == 'es' ? ['Todo Quito', 'Centro Histórico', 'La Floresta', 'Conocoto'] : ['All Quito', 'Historic Center', 'La Floresta', 'Conocoto'];
      filters = lang == 'es' ? ['🍽️ Todos', '🍲 Sopas', '🍛 Platos Fuertes', '⭐ Tradición', '🍰 Dulces'] : ['🍽️ All', '🍲 Soups', '🍛 Main Dishes', '⭐ Tradition', '🍰 Sweets'];
    }

    if (!locations.contains(_selectedLocation)) {
      _selectedLocation = locations.first;
    }
    if (!filters.contains(_selectedFilter)) {
      _selectedFilter = filters.first;
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Row(
          children: [
            Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            SizedBox(width: 8),
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
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: isDark ? Colors.grey[800] : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]), borderRadius: BorderRadius.circular(20)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocation,
                icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textMedium, size: 16),
                isDense: true,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() { _selectedLocation = newValue; });
                  }
                },
                items: locations.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Qué se te antoja hoy?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((f) => _buildFilterChip(f, _selectedFilter == f)).toList(),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
          huecasAsync.when(
            data: (huecas) {
              var filtered = List<Hueca>.from(huecas);
              if (_selectedLocation != 'Todo Quito' && _selectedLocation != 'All Quito') {
                filtered = filtered.where((h) => h.sector.toLowerCase().contains(_selectedLocation.toLowerCase()) || h.address.toLowerCase().contains(_selectedLocation.toLowerCase())).toList();
              }
              if (!_selectedFilter.contains('Todos') && !_selectedFilter.contains('All')) {
                String uiTag = _selectedFilter.split(' ').skip(1).join(' ').toLowerCase();
                String targetTag = uiTag;
                if (lang == 'en') {
                  if (uiTag == 'main dishes') {
                    targetTag = 'plato';
                  } else if (uiTag == 'soups') targetTag = 'sopa';
                  else if (uiTag == 'tradition') targetTag = 'tradici';
                  else if (uiTag == 'sweets') targetTag = 'dulce';
                  else if (uiTag == 'seafood') targetTag = 'marisco';
                } else {
                  if (targetTag == 'platos fuertes') targetTag = 'plato';
                  if (targetTag == 'tradición') targetTag = 'tradici';
                  if (targetTag == 'dulces') targetTag = 'dulce';
                  if (targetTag == 'sopas') targetTag = 'sopa';
                  if (targetTag == 'mariscos') targetTag = 'marisco';
                }
                filtered = filtered.where((h) => h.tags.any((t) => t.toLowerCase().contains(targetTag))).toList();
              }

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      lang == 'es' ? 'No hay huecas con estos filtros.' : 'No huecas match these filters.',
                      style: TextStyle(color: AppTheme.textMedium),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildHuecaCard(context, hueca: filtered[index], lang: lang);
                  },
                  childCount: filtered.length,
                ),
              );
            },
            loading: () => SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
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
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.all(12),
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
                          margin: EdgeInsets.only(bottom: 4),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                          child: Text(t, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (!AuthUtils.checkAuthAndPrompt(context)) return;
                          await ref.read(userRepositoryProvider).toggleFavorite(hueca.id);
                          ref.invalidate(currentUserProvider);
                        },
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.8), shape: BoxShape.circle),
                          child: Icon((user?.favoriteHuecas.contains(hueca.id) ?? false) ? Icons.favorite : Icons.favorite_border, size: 18, color: (user?.favoriteHuecas.contains(hueca.id) ?? false) ? Colors.red : Theme.of(context).colorScheme.onSurface),
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
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [Icon(Icons.near_me, color: AppTheme.primary, size: 12), SizedBox(width: 4), Text('2.5 km', style: TextStyle(color: Colors.white, fontSize: 10))]),
                          ),
                          SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [Icon(Icons.payments, color: Colors.white, size: 12), SizedBox(width: 4), Text('\$${hueca.mainDish["price"] ?? "5.0"}', style: TextStyle(color: Colors.white, fontSize: 10))]),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.star, color: AppTheme.primary, size: 14),
                            SizedBox(width: 4),
                            Text('${hueca.rating}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(width: 2),
                            Text('(${hueca.reviewCount})', style: TextStyle(color: AppTheme.textMedium, fontSize: 10)),
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
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hueca.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppTheme.tertiary, size: 14),
                    SizedBox(width: 4),
                    Expanded(child: Text(hueca.address, style: TextStyle(color: AppTheme.textMedium, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isDark ? Colors.grey[800] : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Text('${hueca.mainDish["emoji"] ?? "🍲"}', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 8),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(height: 16),
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
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.grey[800] : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]), foregroundColor: AppTheme.secondary, elevation: 0),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions, size: 16), SizedBox(width: 4), Text(lang == 'es' ? 'Cómo llegar' : 'Directions', style: TextStyle(fontSize: 12))]),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
context.push('/hueca_detail', extra: hueca);
                        },
                        style: ElevatedButton.styleFrom(elevation: 4),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(lang == 'es' ? 'Ver Hueca' : 'View Spot', style: TextStyle(fontSize: 12)), SizedBox(width: 4), Icon(Icons.arrow_forward, size: 16)]),
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
