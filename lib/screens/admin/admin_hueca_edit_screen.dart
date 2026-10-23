import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/services/translation_service.dart';
import 'package:hue_quito/screens/business/location_picker_screen.dart';
import 'package:hue_quito/services/geocoding_service.dart';

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
  late TextEditingController _mainDishNameEnController;
  late TextEditingController _mainDishDescController;
  late TextEditingController _mainDishDescEnController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _imageUrlController;

  String _selectedSector = 'Centro Histórico';
  String _priceLevel = '\$';
  bool _isActive = true;
  bool _isSaving = false;
  bool _isTranslatingAll = false;
  bool _isTranslatingDesc = false;
  bool _isTranslatingDish = false;
  String? _selectedOwnerId;

  Map<String, String> _schedule = {};
  List<String> _tags = [];

  final List<String> _days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

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
    String mainDishName = '';
    String mainDishNameEn = '';
    if (dish['name'] is Map) {
      mainDishName = dish['name']['es']?.toString() ?? '';
      mainDishNameEn = dish['name']['en']?.toString() ?? '';
    } else {
      mainDishName = dish['name']?.toString() ?? '';
      mainDishNameEn = dish['nameEn']?.toString() ?? '';
    }

    String mainDishDesc = '';
    String mainDishDescEn = '';
    if (dish['description'] is Map) {
      mainDishDesc = dish['description']['es']?.toString() ?? '';
      mainDishDescEn = dish['description']['en']?.toString() ?? '';
    } else {
      mainDishDesc = dish['description']?.toString() ?? '';
      mainDishDescEn = dish['descriptionEn']?.toString() ?? '';
    }

    _mainDishNameController = TextEditingController(text: mainDishName);
    _mainDishNameEnController = TextEditingController(text: mainDishNameEn);
    _mainDishDescController = TextEditingController(text: mainDishDesc);
    _mainDishDescEnController = TextEditingController(text: mainDishDescEn);

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

    _tags = (h != null && h.tags.isNotEmpty) ? List<String>.from(h.tags) : ['Tradicional'];

    _initSchedule(h);
  }

  void _initSchedule(Hueca? h) {
    if (h != null && h.schedule.isNotEmpty) {
      for (final day in _days) {
        if (h.schedule.containsKey(day)) {
          _schedule[day] = h.schedule[day].toString();
        } else if (h.schedule.containsKey(day.toLowerCase())) {
          _schedule[day] = h.schedule[day.toLowerCase()].toString();
        }
      }
      if (_schedule.isEmpty) {
        final lv = h.schedule['lunes_a_viernes']?.toString() ?? '08:00 - 18:00';
        final sd = h.schedule['sabado_domingo']?.toString() ?? '08:00 - 16:00';
        for (int i = 0; i < 5; i++) {
          _schedule[_days[i]] = lv;
        }
        _schedule[_days[5]] = sd;
        _schedule[_days[6]] = sd;
      }
    } else {
      for (int i = 0; i < 5; i++) {
        _schedule[_days[i]] = '08:00 - 18:00';
      }
      _schedule[_days[5]] = '08:00 - 16:00';
      _schedule[_days[6]] = '08:00 - 16:00';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descEsController.dispose();
    _descEnController.dispose();
    _mainDishNameController.dispose();
    _mainDishNameEnController.dispose();
    _mainDishDescController.dispose();
    _mainDishDescEnController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final double lat = double.tryParse(_latController.text.trim()) ?? -0.2200;
    final double lng = double.tryParse(_lngController.text.trim()) ?? -78.5120;

    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: LatLng(lat, lng),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latController.text = result.location.latitude.toStringAsFixed(6);
        _lngController.text = result.location.longitude.toStringAsFixed(6);
        if (result.address.isNotEmpty) {
          _addressController.text = result.address;
        }
        if (result.sector != null && _sectors.contains(result.sector)) {
          _selectedSector = result.sector!;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ubicación seleccionada: ${result.address.isNotEmpty ? result.address : "${_latController.text}, ${_lngController.text}"}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _translateDescription() async {
    final text = _descEsController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Escribe la descripción en español primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTranslatingDesc = true);
    final translated = await TranslationService.translateEsToEn(text);
    if (mounted) {
      setState(() {
        _descEnController.text = translated;
        _isTranslatingDesc = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Descripción traducida al inglés con éxito'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _translateMainDish() async {
    final name = _mainDishNameController.text.trim();
    final desc = _mainDishDescController.text.trim();
    if (name.isEmpty && desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Escribe el nombre o descripción del plato en español'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTranslatingDish = true);
    try {
      if (name.isNotEmpty) {
        final tName = await TranslationService.translateEsToEn(name);
        if (mounted) _mainDishNameEnController.text = tName;
      }
      if (desc.isNotEmpty) {
        final tDesc = await TranslationService.translateEsToEn(desc);
        if (mounted) _mainDishDescEnController.text = tDesc;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Plato insignia traducido al inglés'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al traducir plato: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslatingDish = false);
    }
  }

  Future<void> _translateAll() async {
    final descEs = _descEsController.text.trim();
    final dishName = _mainDishNameController.text.trim();
    final dishDesc = _mainDishDescController.text.trim();

    if (descEs.isEmpty && dishName.isEmpty && dishDesc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Ingresa al menos la descripción o plato en español para traducir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTranslatingAll = true);

    try {
      if (descEs.isNotEmpty) {
        final translatedDesc = await TranslationService.translateEsToEn(descEs);
        if (mounted) _descEnController.text = translatedDesc;
      }
      if (dishName.isNotEmpty) {
        final translatedDishName = await TranslationService.translateEsToEn(dishName);
        if (mounted) _mainDishNameEnController.text = translatedDishName;
      }
      if (dishDesc.isNotEmpty) {
        final translatedDishDesc = await TranslationService.translateEsToEn(dishDesc);
        if (mounted) _mainDishDescEnController.text = translatedDishDesc;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ ¡Campos traducidos al inglés con IA exitosamente!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en la traducción: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslatingAll = false);
    }
  }

  void _showOwnerSearchModal(List<UserModel> allUsers, List<Hueca> allHuecas) {
    final eligibleUsers = allUsers.where((u) => u.role == 'business' || u.role == 'admin').toList();
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final matches = query.isEmpty
                ? <UserModel>[]
                : eligibleUsers.where((u) {
                    final nameMatch = u.name.toLowerCase().contains(query);
                    final emailMatch = u.email.toLowerCase().contains(query);
                    return nameMatch || emailMatch;
                  }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_search_rounded, color: Color(0xFF0F172A), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Asignar Cuenta de Negocio',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Busca el dueño por nombre o correo',
                                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.blueGrey),
                          onPressed: () => Navigator.pop(bCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Barra de búsqueda con Lupita
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Escribe nombre o correo para buscar...',
                        hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A), size: 22),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.blueGrey),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                        ),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Lista de resultados
                    Expanded(
                      child: query.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.search_rounded, size: 44, color: Colors.blueGrey.shade300),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Escribe para buscar una cuenta',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      'Filtra rápidamente por nombre o correo entre las cuentas de negocio registradas.',
                                      style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.person_off_outlined, color: Colors.redAccent, size: 18),
                                      label: const Text('Dejar sin dueño asignado', style: TextStyle(color: Colors.redAccent)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFFECACA)),
                                        backgroundColor: const Color(0xFFFEF2F2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        setState(() => _selectedOwnerId = null);
                                        Navigator.pop(bCtx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Hueca desvinculada (sin dueño)'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : matches.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 44, color: Colors.blueGrey.shade300),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No se encontraron cuentas con "$query"',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Verifica la ortografía o crea la cuenta en la sección Usuarios.',
                                        style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: matches.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) {
                                    final u = matches[idx];
                                    final isCurrent = u.uid == _selectedOwnerId;
                                    final otherOwned = allHuecas.where((x) => x.ownerId == u.uid && x.id != widget.hueca?.id).firstOrNull;

                                    return InkWell(
                                      onTap: () {
                                        setState(() => _selectedOwnerId = u.uid);
                                        Navigator.pop(bCtx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('✅ Dueño asignado: ${u.name} (${u.email})'),
                                            backgroundColor: Colors.teal,
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isCurrent ? Colors.teal.shade50 : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCurrent
                                                ? Colors.teal.shade300
                                                : (otherOwned != null ? Colors.orange.shade200 : const Color(0xFFE2E8F0)),
                                            width: isCurrent ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
                                              child: Text(
                                                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                                                          u.name,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: Color(0xFF0F172A),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: u.role == 'admin' ? Colors.purple.shade50 : Colors.amber.shade50,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(
                                                            color: u.role == 'admin' ? Colors.purple.shade200 : Colors.amber.shade200,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          u.role.toUpperCase(),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w900,
                                                            color: u.role == 'admin' ? Colors.purple.shade800 : Colors.amber.shade900,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    u.email,
                                                    style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (otherOwned != null) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '⚠️ Dueño de: ${otherOwned.name} (Se transferirá)',
                                                      style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (isCurrent)
                                              const Icon(Icons.check_circle, color: Colors.teal, size: 22)
                                            else
                                              const Icon(Icons.arrow_forward_ios, color: Colors.blueGrey, size: 14),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openScheduleModal() async {
    final Map<String, String> tempSchedule = Map<String, String>.from(_schedule);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.access_time_filled, color: Colors.amber.shade900, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Horario de Atención',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Selecciona las horas con el reloj interactivo',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Atajos rápidos
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '⚡ Atajos Rápidos:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setStateModal(() {
                                      final base = tempSchedule['Lunes'] != 'Cerrado'
                                          ? tempSchedule['Lunes']!
                                          : '08:00 - 18:00';
                                      for (int i = 0; i < 5; i++) {
                                        tempSchedule[_days[i]] = base;
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Copiar a Lun-Vie',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    setStateModal(() {
                                      final base = tempSchedule['Lunes'] != 'Cerrado'
                                          ? tempSchedule['Lunes']!
                                          : '08:00 - 18:00';
                                      for (var d in _days) {
                                        tempSchedule[d] = base;
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Copiar a Todos',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickTemplateChip('☀️ 08:00 - 17:00', '08:00 - 17:00', tempSchedule, setStateModal),
                              const SizedBox(width: 6),
                              _buildQuickTemplateChip('🍲 09:00 - 18:00', '09:00 - 18:00', tempSchedule, setStateModal),
                              const SizedBox(width: 6),
                              _buildQuickTemplateChip('🌆 10:00 - 20:00', '10:00 - 20:00', tempSchedule, setStateModal),
                              const SizedBox(width: 6),
                              _buildQuickTemplateChip('🌙 12:00 - 22:00', '12:00 - 22:00', tempSchedule, setStateModal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lista de 7 días
                  Expanded(
                    child: ListView.separated(
                      itemCount: _days.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final day = _days[index];
                        final raw = tempSchedule[day] ?? '08:00 - 18:00';
                        final isClosed = raw.trim().toLowerCase() == 'cerrado';

                        String startStr = '08:00';
                        String endStr = '18:00';
                        if (!isClosed) {
                          final parts = raw.split('-');
                          if (parts.length >= 2) {
                            startStr = parts[0].trim();
                            endStr = parts[1].trim();
                          }
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isClosed ? Colors.red.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 85,
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isClosed ? Colors.red.shade700 : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isClosed)
                                const Expanded(
                                  child: Text(
                                    'Cerrado todo el día',
                                    style: TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildTimeDialButton(context, startStr, (newTime) {
                                        setStateModal(() {
                                          tempSchedule[day] = '$newTime - $endStr';
                                        });
                                      }),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6),
                                        child: Text('a', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                                      ),
                                      _buildTimeDialButton(context, endStr, (newTime) {
                                        setStateModal(() {
                                          tempSchedule[day] = '$startStr - $newTime';
                                        });
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  setStateModal(() {
                                    if (isClosed) {
                                      tempSchedule[day] = '08:00 - 18:00';
                                    } else {
                                      tempSchedule[day] = 'Cerrado';
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isClosed ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isClosed ? Colors.green.shade200 : Colors.red.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    isClosed ? 'Abrir' : 'Cerrar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isClosed ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _schedule = Map<String, String>.from(tempSchedule);
                        });
                        Navigator.pop(bCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Horarios actualizados'),
                            backgroundColor: Colors.teal,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text('Guardar Horario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeDialButton(BuildContext context, String timeStr, Function(String) onPicked) {
    return InkWell(
      onTap: () async {
        int initialHour = 8;
        int initialMinute = 0;
        final clean = timeStr.trim();
        final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clean);
        if (match != null) {
          initialHour = int.tryParse(match.group(1)!) ?? 8;
          initialMinute = int.tryParse(match.group(2)!) ?? 0;
        }

        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
          builder: (ctx, child) {
            return MediaQuery(
              data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
        );

        if (picked != null) {
          final h = picked.hour.toString().padLeft(2, '0');
          final m = picked.minute.toString().padLeft(2, '0');
          onPicked('$h:$m');
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 14, color: Color(0xFF0F172A)),
            const SizedBox(width: 4),
            Text(
              timeStr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTemplateChip(String label, String timeRange, Map<String, String> currentSchedule, StateSetter setStateModal) {
    return InkWell(
      onTap: () {
        setStateModal(() {
          for (var d in _days) {
            currentSchedule[d] = timeRange;
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
      ),
    );
  }

  String _getScheduleSummary() {
    if (_schedule.isEmpty) return '08:00 - 18:00 (Todos los días)';
    final lun = _schedule['Lunes'] ?? '08:00 - 18:00';
    final sab = _schedule['Sábado'] ?? '08:00 - 16:00';
    return 'Lun-Vie: $lun | Sáb-Dom: $sab';
  }

  Widget _buildImagePreview() {
    final url = _imageUrlController.text.trim();
    final hasUrl = url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));

    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: hasUrl
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.blueGrey.shade400, size: 36),
                          const SizedBox(height: 6),
                          Text('No se pudo cargar la imagen', style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.remove_red_eye, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Vista previa', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: Colors.blueGrey.shade400, size: 36),
                    const SizedBox(height: 6),
                    Text('Ingresa una URL de imagen válida para ver la vista previa', style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTagsSelector() {
    final availableTags = [
      'Tradicional',
      'Hornado',
      'Mariscos',
      'Cafetería',
      'Dulces',
      'Secos',
      'Almuerzos',
      'Desayunos',
      'Comida Típica',
      'Fritada',
      'Ceviches',
      'Empanadas',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableTags.map((tag) {
        final isSelected = _tags.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _tags.add(tag);
              } else {
                _tags.remove(tag);
              }
            });
          },
          selectedColor: Colors.amber.shade100,
          checkmarkColor: const Color(0xFF0F172A),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : Colors.blueGrey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? Colors.amber.shade400 : const Color(0xFFCBD5E1),
            ),
          ),
        );
      }).toList(),
    );
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
        'isSectorConfirmed': true,
        'ownerId': _selectedOwnerId ?? '',
        'location': GeoPoint(lat, lng),
        'schedule': _schedule,
        'tags': _tags.isNotEmpty ? _tags : [_selectedSector, 'Tradicional'],
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
          'nameEn': _mainDishNameEnController.text.trim().isNotEmpty
              ? _mainDishNameEnController.text.trim()
              : (_mainDishNameController.text.trim().isNotEmpty
                  ? _mainDishNameController.text.trim()
                  : 'Traditional Specialty'),
          'description': _mainDishDescController.text.trim(),
          'descriptionEn': _mainDishDescEnController.text.trim(),
        },
        'images': images,
        if (isNew) ...{
          'rating': 5.0,
          'reviewCount': 0,
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
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isNew ? 'Nueva Hueca' : 'Editar Hueca',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                    )
                  : const Icon(Icons.check, size: 16, color: Color(0xFF0F172A)),
              label: Text(
                _isSaving ? 'Guardando...' : 'Guardar',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              onPressed: _isSaving ? null : _saveHueca,
            ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                                Text('Estado de la Hueca', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15)),
                                SizedBox(height: 2),
                                Text('Visible en la app para los clientes y turistas', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
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
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade800, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Creación Rápida de Hueca',
                                    style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ingresa los datos esenciales. Puedes asignar el dueño ahora buscando con la lupa, o completarlo más tarde.',
                                    style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Información General
                    _buildSectionTitle('Información General'),
                    const SizedBox(height: 8),

                    _buildCardSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Nombre de la Hueca *',
                            icon: Icons.store,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
                          ),
                          const SizedBox(height: 14),
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
                                    DropdownMenuItem(value: '\$', child: Text('\$ (Económico)')),
                                    DropdownMenuItem(value: '\$\$', child: Text('\$\$ (Medio)')),
                                    DropdownMenuItem(value: '\$\$\$', child: Text('\$\$\$ (Premium)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _priceLevel = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Teléfono o Celular (Opcional)',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Ubicación & Dirección
                    _buildSectionTitle('Ubicación & Dirección'),
                    const SizedBox(height: 8),

                    _buildCardSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _addressController,
                            label: 'Dirección física *',
                            icon: Icons.location_on,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa la dirección' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.map_outlined, color: Colors.teal, size: 18),
                                  label: const Text(
                                    'Seleccionar en Mapa',
                                    style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.teal),
                                    backgroundColor: const Color(0xFFF0FDFA),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: _openMapPicker,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _latController,
                                  label: 'Latitud',
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
                                  label: 'Longitud',
                                  icon: Icons.gps_fixed,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  validator: (val) => (val != null && val.trim().isNotEmpty && double.tryParse(val.trim()) == null)
                                      ? 'Longitud inválida'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Asignación de Dueño / Cuenta de Negocio con BÚSQUEDA Y LUPITA
                    _buildSectionTitle('Cuenta de Negocio / Dueño Asignado'),
                    const SizedBox(height: 8),

                    Consumer(
                      builder: (context, cRef, child) {
                        final allUsers = cRef.watch(allUsersStreamProvider).value ?? [];
                        final allHuecas = cRef.watch(allHuecasStreamProvider).value ?? [];

                        UserModel? assignedUser;
                        if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty) {
                          assignedUser = allUsers.where((u) => u.uid == _selectedOwnerId).firstOrNull;
                        }

                        final otherOwned = (assignedUser != null)
                            ? allHuecas.where((x) => x.ownerId == assignedUser!.uid && x.id != widget.hueca?.id).firstOrNull
                            : null;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (assignedUser != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.teal.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.teal.shade50,
                                          child: Icon(Icons.storefront, color: Colors.teal.shade800, size: 22),
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
                                                      assignedUser.name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.teal.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Colors.teal.shade200),
                                                    ),
                                                    child: Text(
                                                      'VINCULADO',
                                                      style: TextStyle(color: Colors.teal.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                assignedUser.email,
                                                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (otherOwned != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 14),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Dueño actual de "${otherOwned.name}" (se transferirá a esta hueca).',
                                                style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.search, size: 16, color: Color(0xFF0F172A)),
                                            label: const Text('Cambiar dueño con lupa', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                            ),
                                            onPressed: () => _showOwnerSearchModal(allUsers, allHuecas),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                          label: const Text('Quitar', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFFFECACA)),
                                            backgroundColor: const Color(0xFFFEF2F2),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                          ),
                                          onPressed: () {
                                            setState(() => _selectedOwnerId = null);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: () => _showOwnerSearchModal(allUsers, allHuecas),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person_search_rounded, color: Color(0xFF0F172A), size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Sin dueño asignado (Opcional)',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Toca la lupa para buscar y vincular una cuenta',
                                              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.search, color: Colors.amber, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              'Buscar',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
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

                    // Horario de Atención interactivo
                    _buildSectionTitle('Horario de Atención'),
                    const SizedBox(height: 8),

                    _buildCardSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.access_time_filled, color: Colors.amber.shade900, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Horarios Semanales',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      _getScheduleSummary(),
                                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 16, color: Color(0xFF0F172A)),
                              label: const Text(
                                'Configurar Horarios con Reloj Interactivo',
                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                backgroundColor: const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: _openScheduleModal,
                            ),
                          ),
                        ],
                      ),
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
                          isNew ? 'El dueño puede llenarlos luego desde su panel' : 'Fotos, descripciones y platos',
                          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
                        ),
                        children: [
                          const SizedBox(height: 8),

                          // Foto Principal & Vista Previa
                          _buildSectionTitle('Imagen Principal de la Hueca'),
                          const SizedBox(height: 8),

                          _buildCardSection(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _imageUrlController,
                                  label: 'URL de Imagen Principal (opcional)',
                                  icon: Icons.image,
                                  hint: 'https://...',
                                ),
                                const SizedBox(height: 12),
                                _buildImagePreview(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Descripciones Bilingües y Traducción IA
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('Descripciones Bilingües'),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF0FDFA),
                                  foregroundColor: const Color(0xFF0F766E),
                                  elevation: 0,
                                  side: const BorderSide(color: Color(0xFF99F6E4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: _isTranslatingAll ? null : _translateAll,
                                icon: _isTranslatingAll
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0F766E)),
                                label: Text(
                                  _isTranslatingAll ? 'Traduciendo...' : 'Auto-traducir todo con IA',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          _buildCardSection(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🇪🇨 Español (Original)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _isTranslatingDesc ? null : _translateDescription,
                                      icon: _isTranslatingDesc
                                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
                                          : const Icon(Icons.g_translate, size: 14, color: Colors.teal),
                                      label: const Text('Traducir descripción', style: TextStyle(color: Colors.teal, fontSize: 11)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildTextField(
                                  controller: _descEsController,
                                  label: 'Descripción en Español (Opcional)',
                                  icon: Icons.description,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 14),
                                const Text('🇺🇸 Inglés (Para Turistas)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                const SizedBox(height: 6),
                                _buildTextField(
                                  controller: _descEnController,
                                  label: 'Descripción en Inglés',
                                  icon: Icons.translate,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Plato Insignia
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('Plato Insignia / Especialidad (Opcional)'),
                              TextButton.icon(
                                onPressed: _isTranslatingDish ? null : _translateMainDish,
                                icon: _isTranslatingDish
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
                                    : const Icon(Icons.g_translate, size: 14, color: Colors.teal),
                                label: const Text('Traducir plato', style: TextStyle(color: Colors.teal, fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          _buildCardSection(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _mainDishNameController,
                                  label: 'Nombre del Plato (Español)',
                                  icon: Icons.restaurant_menu,
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _mainDishNameEnController,
                                  label: 'Nombre del Plato (Inglés)',
                                  icon: Icons.translate,
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _mainDishDescController,
                                  label: 'Descripción del Plato (Español)',
                                  icon: Icons.notes,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _mainDishDescEnController,
                                  label: 'Descripción del Plato (Inglés)',
                                  icon: Icons.translate,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Categorías / Etiquetas (Tags)
                          _buildSectionTitle('Etiquetas y Categorías'),
                          const SizedBox(height: 8),

                          _buildCardSection(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selecciona los tipos de comida que ofrece la hueca:',
                                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                                ),
                                const SizedBox(height: 10),
                                _buildTagsSelector(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Botón de guardar inferior
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(
                          isNew ? Icons.add_business : Icons.check_circle_outline,
                          color: Colors.amber,
                          size: 20,
                        ),
                        label: Text(
                          isNew ? 'Registrar Hueca' : 'Guardar Cambios de la Hueca',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: _isSaving ? null : _saveHueca,
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

  Widget _buildCardSection({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
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
      onChanged: (_) => setState(() {}),
    );
  }
}
