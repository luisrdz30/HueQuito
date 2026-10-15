import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

class AdminHuecaEditScreen extends ConsumerStatefulWidget {
  final Hueca? hueca;

  const AdminHuecaEditScreen({super.key, this.hueca});

  @override
  ConsumerState<AdminHuecaEditScreen> createState() => _AdminHuecaEditScreenState();
}

class _AdminHuecaEditScreenState extends ConsumerState<AdminHuecaEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _descEsController;
  late TextEditingController _descEnController;
  late TextEditingController _mainDishNameController;
  late TextEditingController _mainDishDescController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _imageUrlController;

  String _selectedSector = 'Centro Histórico';
  String _priceLevel = '\$';
  bool _isActive = true;
  bool _isSaving = false;
  String? _selectedOwnerId;

  final List<String> _sectors = [
    'Centro Histórico',
    'La Floresta',
    'La Mariscal',
    'Iñaquito',
    'La Carolina',
    'Cumbayá',
    'Tumbaco',
    'Chimbacalle',
    'Villaflora',
    'San Roque',
    'Cotocollao',
    'Carcelén',
    'Norte',
    'Sur',
    'Valles',
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.hueca;
    _selectedOwnerId = h?.ownerId;

    _nameController = TextEditingController(text: h?.name ?? '');
    _addressController = TextEditingController(text: h?.address ?? '');
    _phoneController = TextEditingController(text: h?.phone ?? '');

    String descEs = '';
    String descEn = '';
    if (h != null) {
      if (h.description is Map) {
        descEs = h.description['es']?.toString() ?? '';
        descEn = h.description['en']?.toString() ?? '';
      } else if (h.description is String) {
        descEs = h.description.toString();
        descEn = descEs;
      }
    }
    _descEsController = TextEditingController(text: descEs);
    _descEnController = TextEditingController(text: descEn);

    final dish = h?.mainDish ?? {};
    _mainDishNameController = TextEditingController(text: dish['name']?.toString() ?? '');
    _mainDishDescController = TextEditingController(text: dish['description']?.toString() ?? '');

    _latController = TextEditingController(text: h != null ? h.location.latitude.toString() : '-0.2200');
    _lngController = TextEditingController(text: h != null ? h.location.longitude.toString() : '-78.5120');

    _imageUrlController = TextEditingController(text: (h != null && h.images.isNotEmpty) ? h.images.first : '');

    if (h != null && _sectors.contains(h.sector)) {
      _selectedSector = h.sector;
    } else if (h != null && h.sector.isNotEmpty) {
      _sectors.insert(0, h.sector);
      _selectedSector = h.sector;
    }

    _priceLevel = h?.priceLevel.isNotEmpty == true ? h!.priceLevel : '\$';
    _isActive = h?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descEsController.dispose();
    _descEnController.dispose();
    _mainDishNameController.dispose();
    _mainDishDescController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveHueca() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final double lat = double.tryParse(_latController.text.trim()) ?? -0.2200;
      final double lng = double.tryParse(_lngController.text.trim()) ?? -78.5120;
      final isNew = widget.hueca == null;

      final existing = widget.hueca;
      final targetId = isNew ? FirebaseFirestore.instance.collection('huecas').doc().id : existing!.id;

      final List<String> images = [];
      if (_imageUrlController.text.trim().isNotEmpty) {
        images.add(_imageUrlController.text.trim());
      }
      if (existing != null && existing.images.length > 1) {
        images.addAll(existing.images.skip(1));
      }

      final data = {
        'id': targetId,
        'name': _nameController.text.trim(),
        'sector': _selectedSector,
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'priceLevel': _priceLevel,
        'isActive': _isActive,
        'ownerId': _selectedOwnerId ?? '',
        'location': GeoPoint(lat, lng),
        'description': {
          'es': _descEsController.text.trim().isNotEmpty
              ? _descEsController.text.trim()
              : 'Tradición y sabor en ${_selectedSector}. Muy pronto más detalles.',
          'en': _descEnController.text.trim().isNotEmpty
              ? _descEnController.text.trim()
              : (_descEsController.text.trim().isNotEmpty
                  ? _descEsController.text.trim()
                  : 'Traditional flavors in ${_selectedSector}. More details coming soon.'),
        },
        'mainDish': {
          'name': _mainDishNameController.text.trim().isNotEmpty
              ? _mainDishNameController.text.trim()
              : 'Especialidad Tradicional',
          'description': _mainDishDescController.text.trim(),
        },
        'images': images,
        if (isNew) ...{
          'rating': 5.0,
          'reviewCount': 0,
          'tags': [_selectedSector, 'Tradicional'],
          'schedule': {
            'lunes_a_viernes': '08:00 - 18:00',
            'sabado_domingo': '08:00 - 16:00',
          },
          'loyaltyCard': {
            'targetStamps': 5,
            'reward': 'Porción de cortesía',
          },
          'secretSticker': {
            'code': 'STICKER_${DateTime.now().millisecondsSinceEpoch}',
            'name': 'Cromo Tradicional',
          },
          'menuItems': [],
          'metrics': {
            'viewCount': 0,
            'favoriteCount': 0,
            'routeAdditions': 0,
            'stampsGiven': 0,
          },
        },
      };

      await ref.read(huecaRepositoryProvider).saveHueca(data);

      if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty) {
        await ref.read(huecaRepositoryProvider).assignHuecaOwner(targetId, _selectedOwnerId!);
      } else if (!isNew && (existing?.ownerId.isNotEmpty ?? false) && (_selectedOwnerId == null || _selectedOwnerId!.isEmpty)) {
        await ref.read(huecaRepositoryProvider).assignHuecaOwner(targetId, '');
      }

      ref.invalidate(allHuecasStreamProvider);
      ref.invalidate(allUsersStreamProvider);
      ref.invalidate(huecasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNew ? '✅ Hueca creada exitosamente' : '✅ Hueca actualizada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.hueca == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isNew ? 'Nueva Hueca' : 'Editar Hueca',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.amber),
            tooltip: 'Guardar',
            onPressed: _isSaving ? null : _saveHueca,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado activo / pausado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Estado de la Hueca', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                Text('Visible en la app para los clientes', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            activeColor: Colors.green.shade600,
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (isNew) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Creación Rápida de Hueca',
                                    style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Solo ingresa los datos esenciales (nombre, sector, dirección y cuenta). El dueño completará su menú con IA, fotos reales, horarios y descripciones desde su propio panel.',
                                    style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Información Básica
                    _buildSectionTitle('Información General'),
                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre de la Hueca *',
                      icon: Icons.store,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
                    ),

                    const SizedBox(height: 12),

                    // Sector y Rango de Precios
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedSector,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: _inputDecoration('Sector', Icons.map),
                            items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSector = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _priceLevel,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: _inputDecoration('Precio', Icons.attach_money),
                            items: const [
                              DropdownMenuItem(value: '\$', child: Text('\$')),
                              DropdownMenuItem(value: '\$\$', child: Text('\$\$')),
                              DropdownMenuItem(value: '\$\$\$', child: Text('\$\$\$')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _priceLevel = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _addressController,
                      label: 'Dirección física *',
                      icon: Icons.location_on,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa la dirección' : null,
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Teléfono o Celular (Opcional)',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 20),

                    // Asignación de Dueño / Cuenta de Negocio
                    _buildSectionTitle('Cuenta de Negocio / Dueño Asignado'),
                    const SizedBox(height: 8),

                    Consumer(
                      builder: (context, cRef, child) {
                        final allUsers = cRef.watch(allUsersStreamProvider).value ?? [];
                        final eligibleUsers = allUsers.where((u) => u.role == 'business' || u.role == 'admin').toList();
                        final allHuecas = cRef.watch(allHuecasStreamProvider).value ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String?>(
                              isExpanded: true,
                              value: _selectedOwnerId != null && _selectedOwnerId!.isNotEmpty ? _selectedOwnerId : null,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                                prefixIcon: const Icon(Icons.person_pin, color: Color(0xFF0F172A), size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              hint: const Text('Sin dueño asignado (Opcional)', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Sin dueño asignado (Desvincular)')),
                                ...eligibleUsers.map((u) {
                                  final isCurrent = u.uid == widget.hueca?.ownerId;
                                  final otherOwned = allHuecas.where((x) => x.ownerId == u.uid && x.id != widget.hueca?.id).firstOrNull;

                                  String label = u.name;
                                  if (isCurrent) {
                                    label += ' (Dueño Actual)';
                                  } else if (otherOwned != null) {
                                    label += ' (Dueño de: ${otherOwned.name} - Se transferirá)';
                                  } else if (u.role == 'business') {
                                    label += ' (Negocio disponible)';
                                  } else {
                                    label += ' (${u.email})';
                                  }

                                  return DropdownMenuItem(
                                    value: u.uid,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isCurrent
                                            ? Colors.green.shade800
                                            : (otherOwned != null ? Colors.orange.shade800 : const Color(0xFF0F172A)),
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) => setState(() => _selectedOwnerId = val),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'Regla: Cada cuenta de negocio solo puede estar asignada a 1 hueca.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Opciones avanzadas (opcionales al crear)
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: !isNew,
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          'Campos Opcionales (GPS, Fotos, Menú)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          isNew ? 'El dueño puede llenarlos luego desde su panel' : 'Fotos, coordenadas y platos',
                          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
                        ),
                        children: [
                          const SizedBox(height: 8),

                          _buildTextField(
                            controller: _imageUrlController,
                            label: 'URL de Imagen Principal (opcional)',
                            icon: Icons.image,
                            hint: 'https://...',
                          ),

                          const SizedBox(height: 16),

                          // Coordenadas GPS
                          _buildSectionTitle('Ubicación Geográfica (GPS - Por defecto Quito)'),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _latController,
                                  label: 'Latitud (Opcional)',
                                  icon: Icons.gps_fixed,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  validator: (val) => (val != null && val.trim().isNotEmpty && double.tryParse(val.trim()) == null)
                                      ? 'Latitud inválida'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: _lngController,
                                  label: 'Longitud (Opcional)',
                                  icon: Icons.gps_fixed,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  validator: (val) => (val != null && val.trim().isNotEmpty && double.tryParse(val.trim()) == null)
                                      ? 'Longitud inválida'
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Descripciones
                          _buildSectionTitle('Descripciones (Opcional)'),
                          const SizedBox(height: 8),

                          _buildTextField(
                            controller: _descEsController,
                            label: 'Descripción en Español (Opcional)',
                            icon: Icons.description,
                            maxLines: 3,
                          ),

                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _descEnController,
                            label: 'Descripción en Inglés',
                            icon: Icons.translate,
                            maxLines: 3,
                          ),

                          const SizedBox(height: 16),

                          // Plato Estrella
                          _buildSectionTitle('Plato Insignia (Opcional)'),
                          const SizedBox(height: 8),

                          _buildTextField(
                            controller: _mainDishNameController,
                            label: 'Nombre del Plato Principal',
                            icon: Icons.restaurant_menu,
                          ),

                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _mainDishDescController,
                            label: 'Descripción del Plato',
                            icon: Icons.notes,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Botón de guardar (Botón oscuro)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A), // Botón oscuro
                          foregroundColor: Colors.amber,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _saveHueca,
                        child: Text(
                          isNew ? 'Registrar Hueca' : 'Guardar Cambios',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
      hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
      prefixIcon: Icon(icon, color: const Color(0xFF0F172A), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF0F172A)),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(label, icon, hint: hint),
    );
  }
}
