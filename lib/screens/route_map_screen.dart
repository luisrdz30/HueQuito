import 'package:flutter/material.dart';
import 'package:hue_quito/theme/map_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/utils/map_navigation_helper.dart';

class RouteMapScreen extends ConsumerStatefulWidget {
  final String? initialSector;
  const RouteMapScreen({super.key, this.initialSector});

  @override
  ConsumerState<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends ConsumerState<RouteMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Hueca? _selectedHueca;
  HuecaBranch? _selectedBranch;
  late String _selectedSector;
  String _searchQuery = '';

  final LatLng _quitoCenter = LatLng(-0.2186, -78.5097); // Basilica as center

  @override
  void initState() {
    super.initState();
    _selectedSector = widget.initialSector ?? 'Todos';
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return; 

    Position position = await Geolocator.getCurrentPosition();

    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
      if (_selectedSector == 'Todos' || _selectedSector == 'All') {
        try {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude), 15.0,
          ));
        } catch (_) {}
      }
    }
  }

  @override
  void didUpdateWidget(RouteMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSector != null && widget.initialSector != oldWidget.initialSector) {
      setState(() {
        _selectedSector = widget.initialSector!;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(huecasProvider).whenData((huecas) {
          _zoomToSector(_selectedSector, huecas);
        });
      });
    }
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

  Future<void> _fitPoints(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;
    if (points.length == 1) {
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15.0),
        );
      } catch (_) {}
      return;
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.008, minLng - 0.008),
            northeast: LatLng(maxLat + 0.008, maxLng + 0.008),
          ),
          50.0,
        ),
      );
    } catch (_) {
      try {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(center, 12.5),
        );
      } catch (_) {}
    }
  }

  void _fitAllMarkers(List<Hueca> huecas) {
    if (_mapController == null) return;
    final points = <LatLng>[];
    for (var h in huecas) {
      for (var b in h.allBranches) {
        if (_searchQuery.isNotEmpty) {
          final q = _cleanStr(_searchQuery);
          final matchName = _cleanStr(h.name).contains(q) || _cleanStr(b.name).contains(q);
          final bSec = _cleanStr(b.sector.trim().isNotEmpty ? b.sector : h.sector);
          final matchSector = bSec.contains(q);
          final matchAddress = _cleanStr(b.address).contains(q);
          if (!matchName && !matchSector && !matchAddress) continue;
        }
        points.add(LatLng(b.location.latitude, b.location.longitude));
      }
    }
    if (points.isNotEmpty) {
      _fitPoints(points);
    } else {
      try {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_quitoCenter, 13.0));
      } catch (_) {}
    }
  }

  void _zoomToSector(String sector, List<Hueca> huecas) {
    if (_mapController == null) return;
    final s = _cleanStr(sector);
    if (s == 'todos' || s == 'all' || s.contains('todos') || s.contains('all')) {
      _fitAllMarkers(huecas);
      return;
    }
    final matchingPoints = <LatLng>[];
    for (var h in huecas) {
      for (var b in h.allBranches) {
        if (_matchSector(b.sector, h.sector, sector)) {
          matchingPoints.add(LatLng(b.location.latitude, b.location.longitude));
        }
      }
    }
    if (matchingPoints.isNotEmpty) {
      _fitPoints(matchingPoints);
    } else {
      _fitAllMarkers(huecas);
    }
  }

  void _zoomToSearchQuery(String query, List<Hueca> huecas) {
    if (_mapController == null || query.isEmpty) return;
    final q = _cleanStr(query);
    final matchingPoints = <LatLng>[];
    for (var h in huecas) {
      for (var b in h.allBranches) {
        final matchName = _cleanStr(h.name).contains(q) || _cleanStr(b.name).contains(q);
        final bSec = _cleanStr(b.sector.trim().isNotEmpty ? b.sector : h.sector);
        final matchSector = bSec.contains(q);
        final matchAddress = _cleanStr(b.address).contains(q);
        final dishEs = (h.mainDish['name'] is Map
            ? (h.mainDish['name']['es'] ?? '')
            : h.mainDish['name']?.toString() ?? '');
        final matchDish = _cleanStr(dishEs).contains(q);
        if (matchName || matchSector || matchAddress || matchDish) {
          matchingPoints.add(LatLng(b.location.latitude, b.location.longitude));
        }
      }
    }
    if (matchingPoints.isNotEmpty) {
      _fitPoints(matchingPoints);
    }
  }

  Set<Marker> _buildMarkers(List<Hueca> huecas, String lang) {
    Set<Marker> markers = {};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(title: lang == 'es' ? 'Tú' : 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    
    final currentSecClean = _cleanStr(_selectedSector);
    final isAll = currentSecClean == 'todos' ||
        currentSecClean == 'all' ||
        currentSecClean.contains('todos') ||
        currentSecClean.contains('all');

    for (var hueca in huecas) {
      for (var branch in hueca.allBranches) {
        // Filter by sector:
        if (!isAll) {
          if (!_matchSector(branch.sector, hueca.sector, _selectedSector)) continue;
        }
        
        // Filter by search query across hueca name, branch name, dish, address or sector
        if (_searchQuery.isNotEmpty) {
          final q = _cleanStr(_searchQuery);
          final matchName = _cleanStr(hueca.name).contains(q) ||
              _cleanStr(branch.name).contains(q);
          final dishEs = (hueca.mainDish['name'] is Map
              ? (hueca.mainDish['name']['es'] ?? hueca.mainDish['name']['en'] ?? '')
              : hueca.mainDish['name']?.toString() ?? '');
          final matchDish = _cleanStr(dishEs.toString()).contains(q);
          final bSec = _cleanStr(branch.sector.trim().isNotEmpty ? branch.sector : hueca.sector);
          final matchSector = bSec.contains(q);
          final matchAddress = _cleanStr(branch.address).contains(q);
          if (!matchName && !matchDish && !matchSector && !matchAddress) continue;
        }
        
        final bool isSelected = _selectedHueca != null &&
            _selectedHueca!.id == hueca.id &&
            (_selectedBranch == null || _selectedBranch!.id == branch.id);
        
        final isMatriz = branch.id == 'matriz' || branch.name.toLowerCase().contains('matriz');
        final branchTitle = hueca.allBranches.length > 1
            ? '${hueca.name} (${branch.name})'
            : hueca.name;

        markers.add(
          Marker(
            markerId: MarkerId('${hueca.id}_${branch.id}'),
            position: LatLng(branch.location.latitude, branch.location.longitude),
            infoWindow: InfoWindow(
              title: branchTitle,
              snippet: '${branch.address} • ${branch.sector}',
            ),
            icon: isSelected 
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
                : (isMatriz
                    ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                    : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose)),
            onTap: () {
              setState(() {
                _selectedHueca = hueca;
                _selectedBranch = branch;
              });
              try {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(branch.location.latitude - 0.002, branch.location.longitude),
                  ),
                );
              } catch (_) {}
            },
          ),
        );
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;
    final defaultAll = lang == 'es' ? 'Todos' : 'All';
    final isCurrentAll = _cleanStr(_selectedSector) == 'todos' ||
        _cleanStr(_selectedSector) == 'all' ||
        _cleanStr(_selectedSector).contains('todos') ||
        _cleanStr(_selectedSector).contains('all');
    if (isCurrentAll) {
      _selectedSector = defaultAll;
    }
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      body: Stack(
        children: [
          // The Map
          huecasAsync.when(
            data: (huecas) {
              return GoogleMap(
                style: Theme.of(context).brightness == Brightness.dark ? darkMapStyle : null, 
                onMapCreated: (c) {
                  _mapController = c;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final s = _cleanStr(_selectedSector);
                    if (s != 'todos' && s != 'all' && !s.contains('todos') && !s.contains('all')) {
                      _zoomToSector(_selectedSector, huecas);
                    } else {
                      _fitAllMarkers(huecas);
                    }
                  });
                },
                initialCameraPosition: const CameraPosition(target: LatLng(-0.2100, -78.4800), zoom: 12.5),
                markers: _buildMarkers(huecas, lang),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() {
                  _selectedHueca = null;
                  _selectedBranch = null;
                }),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text(lang == 'es' ? 'Error al cargar mapa' : 'Error loading map')),
          ),
          
          // Top Overlays
          Positioned(
            top: 16, left: 16, right: 16,
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: TextField(
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      huecasAsync.whenData((h) {
                        if (val.trim().length >= 3) {
                          _zoomToSearchQuery(val.trim(), h);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: lang == 'es' ? 'Buscar hueca, sucursal, barrio o plato...' : 'Search place, branch, area...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          if (_currentPosition != null && _mapController != null) {
                            try {
                              _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude)));
                            } catch (_) {}
                          }
                        },
                        child: const Icon(Icons.my_location, color: AppTheme.primary)
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Sector Filter Dropdown including all branches' sectors
                huecasAsync.when(
                  data: (huecasList) {
                    final allSectorSet = <String>{};
                    for (var h in huecasList) {
                      if (h.sector.trim().isNotEmpty) allSectorSet.add(h.sector.trim());
                      for (var b in h.allBranches) {
                        if (b.sector.trim().isNotEmpty) allSectorSet.add(b.sector.trim());
                      }
                    }
                    final sortedSectors = allSectorSet.toList()..sort();
                    final sectors = [defaultAll, ...sortedSectors];

                    if (isCurrentAll) {
                      _selectedSector = defaultAll;
                    } else {
                      final matchingSector = sectors.firstWhere(
                        (s) => _cleanStr(s) == _cleanStr(_selectedSector),
                        orElse: () => defaultAll,
                      );
                      _selectedSector = matchingSector;
                    }
                    if (!sectors.contains(_selectedSector)) {
                      _selectedSector = defaultAll;
                    }

                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSector,
                            icon: Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).colorScheme.onSurface),
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedSector = newValue;
                                  _selectedHueca = null;
                                  _selectedBranch = null;
                                });
                                _zoomToSector(newValue, huecasList);
                              }
                            },
                            items: sectors.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_,__) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          // Badge indicator
          Positioned(
            top: 140, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    isCurrentAll
                        ? (lang == 'es' ? 'Mostrando todo' : 'Showing all')
                        : _selectedSector,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  huecasAsync.when(
                    data: (h) {
                      final count = _buildMarkers(h, lang).length - (_currentPosition != null ? 1 : 0);
                      return Text('$count ${lang == 'es' ? 'puntos' : 'spots'}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                    },
                    loading: () => const Text('...', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    error: (e,s) => Text(lang == 'es' ? '0 puntos' : '0 spots', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
          
          // Action Buttons (Fit All & My Location)
          Positioned(
            top: 140, right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    huecasAsync.whenData((h) => _fitAllMarkers(h));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: Tooltip(
                      message: lang == 'es' ? 'Ver todas' : 'View all',
                      child: const Icon(Icons.crop_free, color: AppTheme.primary, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_currentPosition != null && _mapController != null) {
                      try {
                        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0,
                        ));
                      } catch (_) {}
                    } else {
                      _determinePosition();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: Tooltip(
                      message: lang == 'es' ? 'Mi ubicación' : 'My location',
                      child: const Icon(Icons.my_location, color: AppTheme.primary, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Floating Bottom Card (Selected Hueca & Branch)
          if (_selectedHueca != null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle for swipe down indicator
                    Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]), borderRadius: BorderRadius.circular(2))),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.network(_selectedHueca!.images.isNotEmpty ? _selectedHueca!.images.first : 'https://via.placeholder.com/60', width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text(lang == 'es' ? 'Abierto' : 'Open', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                                  const Spacer(),
                                  const Icon(Icons.star, color: Colors.orange, size: 14),
                                  const SizedBox(width: 2),
                                  Text(_selectedHueca!.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedHueca!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                              const SizedBox(height: 2),
                              Text(
                                _selectedBranch != null
                                    ? '${_selectedBranch!.address} (${_selectedBranch!.sector})'
                                    : '${_selectedHueca!.address} (${_selectedHueca!.sector})',
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Info Row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant_menu, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
                                children: [
                                  TextSpan(text: lang == 'es' ? 'Plato insignia: ' : 'Signature dish: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(
                                    text: () {
                                      if (_selectedHueca!.mainDish['name'] is Map) {
                                        final m = _selectedHueca!.mainDish['name'] as Map;
                                        return (m[lang] ?? m['es'] ?? m['en'] ?? m.values.firstOrNull ?? '').toString();
                                      }
                                      return _selectedHueca!.mainDish['name']?.toString() ?? '';
                                    }(),
                                  ),
                                ]
                              )
                            )
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 0)
                            ),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(lang == 'es' ? 'Cómo llegar' : 'Directions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 0)
                            ),
                            onPressed: () => context.push('/hueca_detail', extra: _selectedHueca),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(lang == 'es' ? 'Ver Hueca' : 'View Spot', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontSize: 11)),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: Theme.of(context).colorScheme.onSurface),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), shape: BoxShape.circle),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              (user?.favoriteHuecas.contains(_selectedHueca!.id) ?? false) ? Icons.favorite : Icons.favorite_border, 
                              color: (user?.favoriteHuecas.contains(_selectedHueca!.id) ?? false) ? Colors.red : Theme.of(context).colorScheme.onSurface, 
                              size: 18
                            ),
                            onPressed: () async {
                              if (user == null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'es' ? 'Inicia sesión para guardar favoritos' : 'Log in to save favorites')));
                                return;
                              }
                              await ref.read(userRepositoryProvider).toggleFavorite(_selectedHueca!.id);
                              ref.invalidate(currentUserProvider);
                            },
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
