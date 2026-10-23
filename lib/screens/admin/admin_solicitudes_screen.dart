import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_request_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

class AdminSolicitudesScreen extends ConsumerStatefulWidget {
  const AdminSolicitudesScreen({super.key});

  @override
  ConsumerState<AdminSolicitudesScreen> createState() => _AdminSolicitudesScreenState();
}

class _AdminSolicitudesScreenState extends ConsumerState<AdminSolicitudesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  Future<void> _approveRequest(HuecaRequest req) async {
    final currentUser = ref.read(currentUserProvider).value;
    final adminUid = currentUser?.uid ?? 'admin';
    String priceLevel = '\$';
    final List<String> selectedTags = [req.sector, 'Tradicional'];
    final notesController = TextEditingController();
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aprobar Solicitud',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Creará la Hueca y la Cuenta de Negocio',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.huecaName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Text('Sector: ${req.sector}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          Text('Dueño: ${req.ownerName}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          Text('Correo: ${req.ownerEmail}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Nivel de Precio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Row(
                      children: ['\$', '\$\$', '\$\$\$'].map((p) {
                        final isSel = priceLevel == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(p, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0F172A),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (val) {
                              if (val) setDialogState(() => priceLevel = p);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    const Text('Notas internas del Administrador (opcional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Ej. Verificado por teléfono, local tradicional muy recomendado.',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.mark_email_read, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Se enviará un correo a ${req.ownerEmail} para definir/acceder a su panel. Si este correo ya estaba en uso por una cuenta de cliente/Google, se convertirá a cuenta de Negocio y sus datos antiguos de explorador se limpiarán para gestionar su hueca.',
                              style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 18),
                label: Text(isProcessing ? 'Procesando...' : 'Confirmar Aprobación'),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        try {
                          final targetHuecaId = FirebaseFirestore.instance.collection('huecas').doc().id;

                          final List<String> images = [];
                          if (req.photoUrl != null && req.photoUrl!.isNotEmpty) {
                            images.add(req.photoUrl!);
                          }

                          // 1. Crear documento de la Hueca
                          final huecaData = {
                            'id': targetHuecaId,
                            'name': req.huecaName,
                            'sector': req.sector,
                            'address': req.address,
                            'phone': req.phone,
                            'priceLevel': priceLevel,
                            'isActive': true,
                            'ownerId': '', // se asignará con el usuario
                            'location': const GeoPoint(-0.2200, -78.5120),
                            'schedule': {
                              'Lunes': '08:00 - 17:00',
                              'Martes': '08:00 - 17:00',
                              'Miércoles': '08:00 - 17:00',
                              'Jueves': '08:00 - 17:00',
                              'Viernes': '08:00 - 17:00',
                              'Sábado': '08:00 - 15:00',
                              'Domingo': 'Cerrado',
                            },
                            'tags': selectedTags,
                            'description': {
                              'es': req.description,
                              'en': req.description,
                            },
                            'mainDish': {
                              'name': req.mainDish,
                              'nameEn': req.mainDish,
                              'description': req.description,
                              'descriptionEn': req.description,
                            },
                            'images': images,
                            'rating': 5.0,
                            'reviewCount': 0,
                            'loyaltyCard': {
                              'targetStamps': 5,
                              'reward': 'Porción tradicional de cortesía',
                            },
                            'secretSticker': {
                              'code': 'STICKER_${DateTime.now().millisecondsSinceEpoch}',
                              'name': 'Cromo ${req.huecaName}',
                            },
                            'menuItems': [],
                            'metrics': {
                              'viewCount': 0,
                              'favoriteCount': 0,
                              'routeAdditions': 0,
                              'stampsGiven': 0,
                            },
                          };

                          await ref.read(huecaRepositoryProvider).saveHueca(huecaData);

                          // 2. Crear o actualizar cuenta de negocio y asignar la hueca
                          final createdUser = await ref.read(userRepositoryProvider).createBusinessAccount(
                                name: req.ownerName,
                                email: req.ownerEmail,
                                preferredUid: (req.requestedBy.isNotEmpty && !req.requestedBy.startsWith('anon_'))
                                    ? req.requestedBy
                                    : null,
                                assignedHuecaId: targetHuecaId,
                              );

                          // 3. Asignar ownerId en la hueca
                          await ref.read(huecaRepositoryProvider).assignHuecaOwner(targetHuecaId, createdUser.uid);

                          // 4. Marcar solicitud como aprobada
                          await ref.read(huecaRequestRepositoryProvider).markApproved(
                                requestId: req.id,
                                adminUid: adminUid,
                                createdHuecaId: targetHuecaId,
                                adminNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                              );

                          ref.invalidate(allHuecaRequestsProvider);
                          ref.invalidate(pendingHuecaRequestsProvider);
                          ref.invalidate(allHuecasStreamProvider);
                          ref.invalidate(allUsersStreamProvider);
                          ref.invalidate(huecasProvider);

                          if (mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('¡Hueca "${req.huecaName}" aprobada y cuenta creada exitosamente!'),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al aprobar: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _rejectRequest(HuecaRequest req) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isProcessing = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rechazar Solicitud',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Deseas rechazar la solicitud de "${req.huecaName}"?',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Motivo de rechazo *:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ej. No se pudo verificar la existencia del local, o la dirección proporcionada no es válida.',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el motivo de rechazo' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.close, size: 18),
                label: Text(isProcessing ? 'Rechazando...' : 'Confirmar Rechazo'),
                onPressed: isProcessing
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isProcessing = true);
                        try {
                          final currentUser = ref.read(currentUserProvider).value;
                          final adminUid = currentUser?.uid ?? 'admin';

                          await ref.read(huecaRequestRepositoryProvider).rejectRequest(
                                requestId: req.id,
                                adminUid: adminUid,
                                reason: reasonController.text.trim(),
                              );

                          ref.invalidate(allHuecaRequestsProvider);
                          ref.invalidate(pendingHuecaRequestsProvider);

                          if (mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Solicitud rechazada.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPhotoDialog(String url, String name) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (c, w, p) => p == null ? w : const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                errorBuilder: (c, e, s) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No se pudo cargar la imagen')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allRequestsAsync = ref.watch(allHuecaRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header y TabBar integrado
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Solicitudes de Huecas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar lista',
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  onPressed: () {
                    ref.invalidate(allHuecaRequestsProvider);
                    ref.invalidate(pendingHuecaRequestsProvider);
                  },
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF0F172A),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFFFBBF24),
              indicatorWeight: 3,
              labelColor: const Color(0xFFFBBF24),
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: [
                Tab(
                  child: allRequestsAsync.when(
                    data: (list) {
                      final pending = list.where((r) => r.status == 'pending').length;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Pendientes'),
                          if (pending > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                              child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Text('Pendientes'),
                    error: (_, __) => const Text('Pendientes'),
                  ),
                ),
                const Tab(text: 'Aprobadas'),
                const Tab(text: 'Rechazadas'),
                const Tab(text: 'Todas'),
              ],
            ),
          ),
          // Barra de búsqueda rápida
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, sector o dueño...',
                hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Contenido de Tabs
          Expanded(
            child: allRequestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              error: (e, s) => Center(child: Text('Error al cargar solicitudes: $e')),
              data: (requests) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(requests.where((r) => r.status == 'pending').toList(), 'No hay solicitudes pendientes por revisar.'),
                    _buildRequestsList(requests.where((r) => r.status == 'approved').toList(), 'No hay solicitudes aprobadas todavía.'),
                    _buildRequestsList(requests.where((r) => r.status == 'rejected').toList(), 'No hay solicitudes rechazadas.'),
                    _buildRequestsList(requests, 'No hay ninguna solicitud registrada.'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<HuecaRequest> list, String emptyMessage) {
    var filtered = list;
    if (_searchQuery.isNotEmpty) {
      filtered = list.where((r) {
        return r.huecaName.toLowerCase().contains(_searchQuery) ||
            r.sector.toLowerCase().contains(_searchQuery) ||
            r.ownerName.toLowerCase().contains(_searchQuery) ||
            r.ownerEmail.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.blueGrey.shade300),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0F172A),
      onRefresh: () async {
        ref.invalidate(allHuecaRequestsProvider);
        ref.invalidate(pendingHuecaRequestsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) => _buildRequestCard(filtered[i]),
      ),
    );
  }

  Widget _buildRequestCard(HuecaRequest req) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (req.status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Aprobada';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rechazada';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.amber.shade800;
        statusText = 'Pendiente';
        statusIcon = Icons.hourglass_top;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nombre y Estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.huecaName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.sector,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Text(
                            _formatDate(req.createdAt),
                            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Datos del Propietario
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Dueño: ${req.ownerName}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.ownerEmail,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.phone,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Dirección
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.address,
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Plato Estrella
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.restaurant_menu, size: 16, color: Color(0xFFF47B20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Plato Estrella: ${req.mainDish}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF47B20)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Descripción
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Text(
                req.description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
              ),
            ),

            // Foto si existe
            if (req.photoUrl != null && req.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showPhotoDialog(req.photoUrl!, req.huecaName),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        req.photoUrl!,
                        width: 70,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 70,
                          height: 50,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Foto adjunta por el usuario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Toca para ampliar', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Color(0xFF0F172A), size: 20),
                  ],
                ),
              ),
            ],

            // Si está rechazada, mostrar motivo
            if (req.status == 'rejected' && req.rejectionReason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Motivo: ${req.rejectionReason}',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Si está aprobada y tiene huecaId vinculada
            if (req.status == 'approved' && req.createdHuecaId != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hueca registrada en la plataforma (ID: ${req.createdHuecaId})',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Botones de acción si es pendiente
            if (req.status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _rejectRequest(req),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aprobar', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _approveRequest(req),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
