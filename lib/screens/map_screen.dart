import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/utils/map_navigation_helper.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _quitoCenter = const LatLng(-0.2100, -78.4800); // Spans Central Quito & Valleys
  
  Hueca? _selectedHueca;
  HuecaBranch? _selectedBranch;
  String _selectedCategory = 'Todos';
  String _selectedSector = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _cleanStr(String str) {
    return str.toLowerCase().trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  bool _matchSector(String branchSector, String fallbackSector, String targetSector) {
    final target = _cleanStr(targetSector);
    if (target == 'todos' || target == 'all' || target.contains('todos') || target.contains('all')) return true;
    final bSec = _cleanStr(branchSector.trim().isNotEmpty ? branchSector : fallbackSector);
    return bSec == target || bSec.contains(target) || target.contains(bSec);
  }

  void _centerOnUser() {
    _mapController.move(_quitoCenter, 13.0);
  }

  void _fitAllMarkers(List<Hueca> huecas) {
    _mapController.move(_quitoCenter, 12.5);
  }

  void _zoomToSector(String sector, List<Hueca> huecas) {
    if (sector == 'Todos' || sector == 'All' || sector.contains('Todos') || sector.contains('All')) {
      _fitAllMarkers(huecas);
      return;
    }
    for (var h in huecas) {
      if (!h.isActive) continue;
      for (var b in h.allBranches) {
        if (_matchSector(b.sector, h.sector, sector)) {
          _mapController.move(LatLng(b.location.latitude, b.location.longitude), 15.0);
          return;
        }
      }
    }
  }

  void _zoomToSearchQuery(String query, List<Hueca> huecas) {
    if (query.isEmpty) return;
    final q = _cleanStr(query);
    for (var h in huecas) {
      if (!h.isActive) continue;
      if (h.matchesSearch(query)) {
        final b = h.allBranches.first;
        _mapController.move(LatLng(b.location.latitude, b.location.longitude), 15.0);
        return;
      }
      for (var b in h.allBranches) {
        final matchName = _cleanStr(b.name).contains(q);
        final bSec = _cleanStr(b.sector.trim().isNotEmpty ? b.sector : h.sector);
        final matchSector = bSec.contains(q);
        final matchAddress = _cleanStr(b.address).contains(q);
        if (matchName || matchSector || matchAddress) {
          _mapController.move(LatLng(b.location.latitude, b.location.longitude), 15.0);
          return;
        }
      }
    }
  }

  List<Marker> _getMarkers(List<Hueca> huecas) {
    List<Marker> markers = [];
    for (var hueca in huecas) {
      if (!hueca.isActive) continue;
      // Category filter
      if (_selectedCategory != 'Todos' && _selectedCategory != 'All') {
        if (!hueca.tags.contains(_selectedCategory) &&
            !hueca.searchTags.contains(_cleanStr(_selectedCategory)) &&
            !hueca.matchesSearch(_selectedCategory)) {
          continue;
        }
      }

      for (var branch in hueca.allBranches) {
        // Sector filter
        final secClean = _cleanStr(_selectedSector);
        final isAll = secClean == 'todos' || secClean == 'all' || secClean.contains('todos') || secClean.contains('all');
        if (!isAll) {
          if (!_matchSector(branch.sector, hueca.sector, _selectedSector)) continue;
        }

        // Search query filter
        if (_searchQuery.isNotEmpty) {
          final q = _cleanStr(_searchQuery);
          final matchBranch = _cleanStr(branch.name).contains(q) ||
              _cleanStr(branch.address).contains(q) ||
              _cleanStr(branch.sector).contains(q);
          if (!matchBranch && !hueca.matchesSearch(_searchQuery)) continue;
        }

        bool isSelected = _selectedHueca != null && 
                          _selectedHueca!.id == hueca.id && 
                          (_selectedBranch == null || _selectedBranch!.id == branch.id);
        markers.add(
          Marker(
            point: LatLng(branch.location.latitude, branch.location.longitude),
            width: isSelected ? 50 : 40,
            height: isSelected ? 50 : 40,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedHueca = hueca;
                  _selectedBranch = branch;
                });
                _mapController.move(
                  LatLng(branch.location.latitude - 0.002, branch.location.longitude),
                  16.0,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.secondary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary, width: isSelected ? 3 : 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: Text(
                    (hueca.mainDish is Map ? hueca.mainDish['emoji'] : null) ?? '🍲',
                    style: TextStyle(fontSize: isSelected ? 24 : 18),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  Widget _buildFilterChip(String label, String tag) {
    final isAll = tag == 'Todos' || tag == 'All';
    bool isSelected = isAll
        ? (_selectedCategory == 'Todos' || _selectedCategory == 'All')
        : _selectedCategory == tag;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedCategory = selected ? tag : 'Todos';
            _selectedHueca = null;
            _selectedBranch = null;
          });
        },
        selectedColor: AppTheme.primary.withOpacity(0.2),
        checkmarkColor: AppTheme.primary,
        backgroundColor: Theme.of(context).cardColor,
        side: BorderSide(color: isSelected ? AppTheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300])!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      body: huecasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (huecas) {
          if (_selectedHueca != null && !_selectedHueca!.isActive) {
            _selectedHueca = null;
            _selectedBranch = null;
          }
          final allSectorSet = <String>{};
          for (var h in huecas) {
            if (!h.isActive) continue;
            if (h.sector.trim().isNotEmpty) allSectorSet.add(h.sector.trim());
            for (var b in h.allBranches) {
              if (b.sector.trim().isNotEmpty) allSectorSet.add(b.sector.trim());
            }
          }
          final sortedSectors = allSectorSet.toList()..sort();
          final defaultAllSector = lang == 'es' ? 'Todos los sectores' : 'All sectors';
          final sectors = [defaultAllSector, ...sortedSectors];

          final isCurrentAll = _cleanStr(_selectedSector) == 'todos' ||
              _cleanStr(_selectedSector) == 'all' ||
              _cleanStr(_selectedSector).contains('todos') ||
              _cleanStr(_selectedSector).contains('all');

          if (isCurrentAll) {
            _selectedSector = defaultAllSector;
          } else {
            final matchingSector = sectors.firstWhere(
              (s) => _cleanStr(s) == _cleanStr(_selectedSector),
              orElse: () => defaultAllSector,
            );
            _selectedSector = matchingSector;
          }
          if (!sectors.contains(_selectedSector)) {
            _selectedSector = defaultAllSector;
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _quitoCenter,
                  initialZoom: 12.5,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selectedHueca = null;
                      _selectedBranch = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: Theme.of(context).brightness == Brightness.dark ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ec.huequito.app',
                    errorImage: const NetworkImage('https://tile.openstreetmap.org/0/0/0.png'),
                  ),
                  MarkerLayer(
                    markers: _getMarkers(huecas),
                  ),
                ],
              ),
              
              // Top Overlay (Search, Sector Dropdown & Filters)
              Positioned(
                top: 48, left: 16, right: 16,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Search & Location toggle
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() => _searchQuery = val);
                                if (val.trim().length >= 3) {
                                  _zoomToSearchQuery(val.trim(), huecas);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: lang == 'es' ? 'Buscar hueca, plato, sucursal o barrio...' : 'Search spot, dish, branch or sector...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _fitAllMarkers(huecas),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                              child: Tooltip(
                                message: lang == 'es' ? 'Ver todas' : 'View all',
                                child: const Icon(Icons.crop_free, color: AppTheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _centerOnUser,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                              child: Tooltip(
                                message: lang == 'es' ? 'Centrar' : 'Center',
                                child: const Icon(Icons.my_location, color: AppTheme.primary),
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Sector Dropdown & Category Chips
                      Row(
                        children: [
                          Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSector,
                                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                onChanged: (String? val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedSector = val;
                                      _selectedHueca = null;
                                      _selectedBranch = null;
                                    });
                                    _zoomToSector(val, huecas);
                                  }
                                },
                                items: sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(lang == 'es' ? 'Todos' : 'All', 'Todos'),
                                  _buildFilterChip(lang == 'es' ? 'Tradicional' : 'Traditional', 'Tradicional'),
                                  _buildFilterChip(lang == 'es' ? 'Mariscos' : 'Seafood', 'Mariscos'),
                                  _buildFilterChip(lang == 'es' ? 'Cerdo' : 'Pork', 'Cerdo'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Badges on map
              if (_selectedHueca == null)
                Positioned(
                  top: 155, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(lang == 'es' ? 'Mostrando' : 'Showing', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('${_getMarkers(huecas).length} ${lang == 'es' ? 'resultados' : 'results'}', style: const TextStyle(color: AppTheme.tertiary, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              
              // Bottom Sheet for selected Hueca & Branch
              if (_selectedHueca != null)
                Positioned(
                  bottom: 16, left: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]), borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _selectedHueca!.images.isNotEmpty ? _selectedHueca!.images[0] : 'https://via.placeholder.com/150', 
                                width: 80, height: 80, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 80, height: 80, color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
                                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedHueca!.name,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_selectedBranch != null && _selectedHueca!.allBranches.length > 1) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _selectedBranch!.name,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (_selectedHueca!.reviewCount > 0) ...[
                                        const Icon(Icons.star, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text('${_selectedHueca!.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(' (${_selectedHueca!.reviewCount} ${lang == 'es' ? 'reseñas' : 'reviews'})', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12)),
                                      ] else ...[
                                        const Icon(Icons.star_border, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text(lang == 'es' ? 'Nuevo' : 'New', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text(lang == 'es' ? ' (Sin reseñas)' : ' (No reviews)', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _selectedBranch != null
                                              ? '${_selectedBranch!.address} (${_selectedBranch!.sector})'
                                              : '${_selectedHueca!.address} (${_selectedHueca!.sector})',
                                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  if (_selectedBranch != null) {
                                    MapNavigationHelper.openMapsForBranch(
                                      context: context,
                                      hueca: _selectedHueca!,
                                      branch: _selectedBranch!,
                                      language: lang,
                                    );
                                  } else {
                                    MapNavigationHelper.openDirections(
                                      context: context,
                                      hueca: _selectedHueca!,
                                      language: lang,
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.directions, size: 16, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Text(lang == 'es' ? 'Cómo llegar' : 'Directions', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  context.push('/hueca_detail', extra: _selectedHueca);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(lang == 'es' ? 'Ver hueca' : 'View spot', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
            ],
          );
        }
      ),
    );
  }
}
