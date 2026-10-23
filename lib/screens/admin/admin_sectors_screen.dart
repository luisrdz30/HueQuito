import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/services/geocoding_service.dart';
import 'package:hue_quito/screens/business/qr_secret_sticker_screen.dart';

class AdminSectorsScreen extends ConsumerStatefulWidget {
  const AdminSectorsScreen({super.key});

  @override
  ConsumerState<AdminSectorsScreen> createState() => _AdminSectorsScreenState();
}

class _AdminSectorsScreenState extends ConsumerState<AdminSectorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all'; // 'all', 'pending_confirm', 'missing_sticker'
  bool _isProcessingBatch = false;

  static const List<String> quitoSectors = [
    'Centro Histórico',
    'La Mariscal',
    'La Floresta',
    'Guápulo',
    'Cumbayá',
    'Tumbaco',
    'Villaflora',
    'Chimbacalle',
    'San Antonio / Mitad del Mundo',
    'Calderón',
    'Cotocollao',
    'El Pintado',
    'La Magdalena',
    'Solanda',
    'Chillogallo',
    'Conocoto',
    'Valle de los Chillos',
    'Iñaquito / La Carolina',
    'Carcelén',
    'Norte',
    'Sur',
    'Valles',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Infiere o sugiere automáticamente el sector a partir de la dirección y coordenadas
  String _suggestSector(Hueca hueca) {
    if (hueca.sector.trim().isNotEmpty && hueca.sector.trim() != 'Todo Quito') {
      return hueca.sector.trim();
    }
    final detected = GeocodingService.detectSector(
      addressComponents: {'address': hueca.address},
      lat: hueca.location.latitude,
      lng: hueca.location.longitude,
    );
    if (detected != null && detected.isNotEmpty) {
      return detected;
    }
    // Heurística básica por latitud si no se detectó por texto
    final lat = hueca.location.latitude;
    if (lat < -0.23) return 'Sur';
    if (lat > -0.19) return 'Norte';
    return 'Centro Histórico';
  }

  bool _hasSecretSticker(Hueca hueca) {
    final s = hueca.secretSticker;
    final name = s['name']?.toString() ?? '';
    final img = (s['image'] ?? s['imageUrl'])?.toString() ?? '';
    final qr = s['qrSecret']?.toString() ?? '';
    if (name.isNotEmpty || img.isNotEmpty || qr.isNotEmpty) return true;
    for (final b in hueca.branches) {
      final bs = b.secretSticker;
      if (bs != null && bs.isNotEmpty) {
        final bName = bs['name']?.toString() ?? '';
        final bImg = (bs['image'] ?? bs['imageUrl'])?.toString() ?? '';
        final bQr = bs['qrSecret']?.toString() ?? '';
        if (bName.isNotEmpty || bImg.isNotEmpty || bQr.isNotEmpty) return true;
      }
    }
    return false;
  }

  String _getStickerName(Hueca hueca) {
    final s = hueca.secretSticker;
    if (s['name'] is Map) {
      final n = s['name']['es']?.toString() ?? s['name']['en']?.toString();
      if (n != null && n.trim().isNotEmpty) return n.trim();
    } else if (s['name'] != null && s['name'].toString().trim().isNotEmpty) {
      return s['name'].toString().trim();
    }
    for (final b in hueca.branches) {
      final bs = b.secretSticker;
      if (bs != null && bs['name'] != null && bs['name'].toString().trim().isNotEmpty) {
        return bs['name'].toString().trim();
      }
    }
    return 'Cromo de ${hueca.name}';
  }

  String _getStickerImageUrl(Hueca hueca) {
    final s = hueca.secretSticker;
    final img = (s['image'] ?? s['imageUrl'])?.toString().trim() ?? '';
    if (img.isNotEmpty) return img;
    for (final b in hueca.branches) {
      final bs = b.secretSticker;
      if (bs != null) {
        final bImg = (bs['image'] ?? bs['imageUrl'])?.toString().trim() ?? '';
        if (bImg.isNotEmpty) return bImg;
      }
    }
    return '';
  }

  Future<void> _confirmSector(Hueca hueca, String sector) async {
    try {
      await ref.read(huecaRepositoryProvider).updateHuecaSector(
        hueca.id,
        sector,
        isConfirmed: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Sector "$sector" confirmado para "${hueca.name}"'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al confirmar sector: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showChangeSectorDialog(Hueca hueca) async {
    String selectedSector = _suggestSector(hueca);
    String filterText = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final allSectors = {...quitoSectors, hueca.sector}.where((s) => s.trim().isNotEmpty).toList();
          allSectors.sort();

          final filtered = allSectors.where((s) {
            if (filterText.isEmpty) return true;
            return s.toLowerCase().contains(filterText.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_location_alt, color: Color(0xFF0F172A), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asignar Sector',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            hueca.name,
                            style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Buscar sector de Quito...',
                    hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      filterText = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final sectorItem = filtered[index];
                      final isCurrent = sectorItem.toLowerCase() == selectedSector.toLowerCase();
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: Icon(
                          isCurrent ? Icons.check_circle : Icons.location_on_outlined,
                          color: isCurrent ? Colors.green.shade700 : Colors.blueGrey.shade400,
                        ),
                        title: Text(
                          sectorItem,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? const Color(0xFF0F172A) : Colors.blueGrey.shade800,
                          ),
                        ),
                        trailing: isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Actual',
                                  style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _confirmSector(hueca, sectorItem);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditSecretStickerDialog(Hueca hueca) async {
    final existingSticker = hueca.secretSticker;
    final nameCtrl = TextEditingController(text: existingSticker['name']?.toString() ?? 'Cromo ${hueca.name}');
    final imageCtrl = TextEditingController(text: _getStickerImageUrl(hueca));
    final secretCtrl = TextEditingController(
      text: existingSticker['qrSecret']?.toString() ??
          'SEC_${hueca.id.toUpperCase().replaceAll('-', '_')}_${Random().nextInt(9000) + 1000}',
    );

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cromo Secreto',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Text(
                      hueca.name,
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nombre del Cromo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ej. Fritada Dorada del Centro',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('URL Imagen del Cromo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                TextField(
                  controller: imageCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Código Secreto QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        secretCtrl.text = 'SEC_${hueca.id.toUpperCase().replaceAll('-', '_')}_${Random().nextInt(9000) + 1000}';
                      },
                      child: const Text('Regenerar', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                TextField(
                  controller: secretCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Código único para el QR',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.blueGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final stickerMap = {
                  'id': existingSticker['id'] ?? 'sticker_${hueca.id}',
                  'name': nameCtrl.text.trim(),
                  'image': imageCtrl.text.trim(),
                  'imageUrl': imageCtrl.text.trim(),
                  'qrSecret': secretCtrl.text.trim(),
                };
                Navigator.pop(dialogCtx);
                try {
                  await ref.read(huecaRepositoryProvider).updateHuecaSecretSticker(hueca.id, stickerMap);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⭐ Cromo de "${hueca.name}" guardado exitosamente'),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar cromo: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Guardar Cromo'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _batchConfirmAll(List<Hueca> huecas) async {
    final unconfirmed = huecas.where((h) => !h.isSectorConfirmed).toList();
    if (unconfirmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos los sectores ya están confirmados.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar todos los sectores', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Deseas confirmar automáticamente los sectores sugeridos para las ${unconfirmed.length} huecas pendientes?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Todos'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingBatch = true);
    try {
      final mapToConfirm = <String, String>{};
      for (final h in unconfirmed) {
        mapToConfirm[h.id] = _suggestSector(h);
      }
      await ref.read(huecaRepositoryProvider).batchConfirmHuecaSectors(mapToConfirm);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${unconfirmed.length} sectores confirmados exitosamente'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al confirmar masivamente: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final huecasAsync = ref.watch(allHuecasStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        title: const Row(
          children: [
            Icon(Icons.collections_bookmark, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text(
              'Sectores y Cromos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(allHuecasStreamProvider),
          ),
        ],
      ),
      body: huecasAsync.when(
        data: (allHuecas) {
          if (allHuecas.isEmpty) {
            return const Center(child: Text('No hay huecas registradas'));
          }

          // Métricas globales
          final totalHuecas = allHuecas.length;
          final confirmedHuecas = allHuecas.where((h) => h.isSectorConfirmed).length;
          final withStickerHuecas = allHuecas.where(_hasSecretSticker).length;

          // Filtrar según query y chip de filtro
          final filteredHuecas = allHuecas.where((h) {
            final suggested = _suggestSector(h);
            final matchesQuery = _searchQuery.isEmpty ||
                h.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                h.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                suggested.toLowerCase().contains(_searchQuery.toLowerCase());

            if (!matchesQuery) return false;

            if (_filter == 'pending_confirm') return !h.isSectorConfirmed;
            if (_filter == 'missing_sticker') return !_hasSecretSticker(h);

            return true;
          }).toList();

          // Agrupar por sector
          final Map<String, List<Hueca>> groupedBySector = {};
          for (final h in filteredHuecas) {
            final sectorName = _suggestSector(h);
            groupedBySector.putIfAbsent(sectorName, () => []).add(h);
          }

          // Ordenar sectores alfabéticamente
          final sortedSectors = groupedBySector.keys.toList()..sort();

          return RefreshIndicator(
            color: const Color(0xFF0F172A),
            onRefresh: () async {
              ref.invalidate(allHuecasStreamProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Explicativo Ejecutivo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.map, color: Colors.amber, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Organizador de Álbum por Sector',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrupa automáticamente las huecas por sector en Quito para el álbum coleccionable de los clientes. Valida que cada hueca esté en el sector correcto y que tenga su cromo secreto configurado.',
                          style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // KPIs resumen
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Sectores',
                          value: '${groupedBySector.length}',
                          icon: Icons.share_location,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Confirmados',
                          value: '$confirmedHuecas / $totalHuecas',
                          icon: Icons.check_circle_outline,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Con Cromo',
                          value: '$withStickerHuecas / $totalHuecas',
                          icon: Icons.star_border,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Acciones y Filtros
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Buscar por hueca, sector o dirección...',
                            hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12.5),
                            prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0F172A)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isProcessingBatch ? null : () => _batchConfirmAll(allHuecas),
                        icon: _isProcessingBatch
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.done_all, size: 18, color: Colors.amber),
                        label: const Text('Confirmar Todo', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Todos (${allHuecas.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('pending_confirm', 'Por Confirmar (${allHuecas.where((h) => !h.isSectorConfirmed).length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('missing_sticker', 'Sin Cromo Secreto (${allHuecas.where((h) => !_hasSecretSticker(h)).length})'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (sortedSectors.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 12),
                          const Text('No se encontraron huecas con los filtros seleccionados', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    ...sortedSectors.map((sectorName) {
                      final huecasInSector = groupedBySector[sectorName]!;
                      final sectorStickersCount = huecasInSector.where(_hasSecretSticker).length;
                      final allConfirmed = huecasInSector.every((h) => h.isSectorConfirmed);

                      return _buildSectorCard(
                        sectorName: sectorName,
                        huecas: huecasInSector,
                        stickersCount: sectorStickersCount,
                        allConfirmed: allConfirmed,
                      );
                    }),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
        error: (err, _) => Center(child: Text('Error cargando huecas: $err')),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _filter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = filterKey);
      },
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.blueGrey.shade700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildSectorCard({
    required String sectorName,
    required List<Hueca> huecas,
    required int stickersCount,
    required bool allConfirmed,
  }) {
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.place, color: Color(0xFF0F172A), size: 24),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  sectorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
              ),
              if (allConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 12, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text('Validado', style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, size: 12, color: Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Text('Revisar', style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${huecas.length} huecas • $stickersCount cromos listos para álbum',
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: huecas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final hueca = huecas[index];
                return _buildHuecaSectorItem(hueca, sectorName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHuecaSectorItem(Hueca hueca, String currentGroupSector) {
    final hasSticker = _hasSecretSticker(hueca);
    final isConfirmed = hueca.isSectorConfirmed;
    final suggested = _suggestSector(hueca);
    final stickerName = _getStickerName(hueca);
    final stickerImage = _getStickerImageUrl(hueca);
    final qrSecret = hueca.secretSticker['qrSecret']?.toString() ??
        hueca.secretSticker['code']?.toString() ??
        'STICKER_${hueca.id}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !isConfirmed ? Colors.amber.shade300 : const Color(0xFFE2E8F0),
          width: !isConfirmed ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Imagen, Nombre y Dirección
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: hueca.images.isNotEmpty
                    ? Image.network(
                        hueca.images.first,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.restaurant, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.restaurant, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hueca.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isConfirmed)
                          const Tooltip(
                            message: 'Sector confirmado por administrador',
                            child: Icon(Icons.check_circle, size: 16, color: Colors.green),
                          )
                        else
                          Tooltip(
                            message: 'Sector detectado automáticamente (pendiente de confirmación)',
                            child: Icon(Icons.help_outline, size: 16, color: Colors.amber.shade800),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hueca.address.isNotEmpty ? hueca.address : 'Sin dirección registrada',
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Chip de estado de sector
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isConfirmed ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isConfirmed ? Colors.green.shade200 : Colors.amber.shade300),
                          ),
                          child: Text(
                            isConfirmed ? 'Sector: $currentGroupSector (OK)' : 'Detectado: $suggested',
                            style: TextStyle(
                              color: isConfirmed ? Colors.green.shade800 : Colors.amber.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isConfirmed)
                          InkWell(
                            onTap: () => _confirmSector(hueca, suggested),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 12, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Confirmar',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        InkWell(
                          onTap: () => _showChangeSectorDialog(hueca),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 12, color: Color(0xFF0F172A)),
                                SizedBox(width: 3),
                                Text(
                                  'Cambiar',
                                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // Fila 2: Información del Cromo Secreto
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasSticker ? Colors.amber.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: hasSticker && stickerImage.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          stickerImage,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.star, color: Colors.amber, size: 18),
                        ),
                      )
                    : Icon(hasSticker ? Icons.star : Icons.star_border, color: hasSticker ? Colors.amber.shade800 : Colors.grey, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSticker ? stickerName : 'Sin cromo secreto asignado',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: hasSticker ? const Color(0xFF0F172A) : Colors.red.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      hasSticker
                          ? (qrSecret.isNotEmpty ? 'QR listo para escanear' : 'Falta código secreto QR')
                          : 'Los clientes no podrán ganar cromo en este sector',
                      style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasSticker)
                IconButton(
                  tooltip: 'Ver QR del Cromo',
                  icon: const Icon(Icons.qr_code, size: 20, color: Color(0xFF0F172A)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QrSecretStickerScreen(
                          qrSecret: qrSecret,
                          huecaId: hueca.id,
                          stickerName: stickerName,
                          stickerImage: stickerImage,
                        ),
                      ),
                    );
                  },
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: hasSticker ? Colors.transparent : Colors.amber.shade50,
                  side: hasSticker ? null : BorderSide(color: Colors.amber.shade300),
                ),
                onPressed: () => _showEditSecretStickerDialog(hueca),
                icon: Icon(hasSticker ? Icons.edit : Icons.add_circle_outline, size: 14, color: const Color(0xFF0F172A)),
                label: Text(
                  hasSticker ? 'Editar Cromo' : 'Asignar Cromo',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
