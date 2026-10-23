import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/auth_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/services/menu_ocr_service.dart';
import 'package:hue_quito/screens/business/dish_form_screen.dart';
import 'package:hue_quito/screens/business/menu_review_screen.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';

class BusinessMenuScreen extends ConsumerStatefulWidget {
  const BusinessMenuScreen({super.key});

  @override
  ConsumerState<BusinessMenuScreen> createState() => _BusinessMenuScreenState();
}

class _BusinessMenuScreenState extends ConsumerState<BusinessMenuScreen> {
  Hueca? _currentHueca;
  bool _isLoading = true;
  bool _isAiProcessing = false;
  List<dynamic> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _loadHueca();
  }

  Future<void> _loadHueca() async {
    setState(() => _isLoading = true);
    final hueca = await ref.read(myHuecaProvider.future);
    if (hueca != null) {
      if (mounted) {
        setState(() {
          _currentHueca = hueca;
          _menuItems = List.from(hueca.menuItems);
          _isLoading = false;
        });
      }
    } else {
      final user = await ref.read(userRepositoryProvider).getCurrentUser();
      if (user != null) {
        final snap = await FirebaseFirestore.instance.collection('huecas').get();
        final match = snap.docs.where((d) {
          final data = d.data();
          if (data['ownerId'] == user.uid) return true;
          final branches = data['branches'] as List<dynamic>? ?? [];
          return branches.any((b) =>
              b is Map &&
              b['managerEmail'] != null &&
              b['managerEmail'].toString().trim().toLowerCase() == user.email.trim().toLowerCase());
        }).firstOrNull;

        if (match != null && mounted) {
          final h = Hueca.fromFirestore(match);
          setState(() {
            _currentHueca = h;
            _menuItems = List.from(h.menuItems);
            _isLoading = false;
          });
          return;
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveMenu() async {
    if (_currentHueca == null) return;

    setState(() => _isLoading = true);

    final huecaMap = _currentHueca!.toMap();
    huecaMap['menuItems'] = _menuItems;
    final newSearchTags = Hueca.extractSearchKeywords(huecaMap);

    await FirebaseFirestore.instance.collection('huecas').doc(_currentHueca!.id).update({
      'menuItems': _menuItems,
      'searchTags': newSearchTags,
    });
    ref.invalidate(myHuecaProvider);
    ref.invalidate(huecasProvider);

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menú actualizado correctamente')),
      );
    }
  }

  void _showAddDishModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.grey[400] : AppTheme.textMedium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Añadir al Menú',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elige cómo prefieres registrar los platos de tu hueca:',
                  style: TextStyle(color: subtextColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // 1. Opción Escanear Carta Completa (IA)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  tileColor: isDark ? AppTheme.primary.withOpacity(0.12) : AppTheme.primary.withOpacity(0.06),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
                  ),
                  title: Text(
                    'Escanear Carta Completa (IA)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Para cartas físicas o afiches. La IA extraerá todos los platos y precios.',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startAiMenuScan();
                  },
                ),
                const SizedBox(height: 10),

                // 2. Opción Escanear 1 Plato por Foto (IA)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.amber.withOpacity(0.4)),
                  ),
                  tileColor: isDark ? Colors.amber.withOpacity(0.12) : Colors.amber.withOpacity(0.06),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_enhance, color: Colors.amber, size: 22),
                  ),
                  title: Text(
                    'Escanear 1 Plato por Foto (IA)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Toma o sube foto de 1 plato. La IA detecta datos y adjunta la foto.',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startSingleDishScan();
                  },
                ),
                const SizedBox(height: 10),

                // 3. Opción Subir Múltiples Fotos de Platos
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.green.withOpacity(0.4)),
                  ),
                  tileColor: isDark ? Colors.green.withOpacity(0.12) : Colors.green.withOpacity(0.06),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Colors.green, size: 22),
                  ),
                  title: Text(
                    'Subir Múltiples Fotos de Platos',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Selecciona fotos de la galería (1 por plato). Se crearán en lote.',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startMultiDishUpload();
                  },
                ),
                const SizedBox(height: 10),

                // 4. Opción Manual
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isDark ? (Colors.grey[750] ?? Colors.grey[700]!) : Colors.grey[300]!),
                  ),
                  tileColor: isDark ? const Color(0xFF282828) : const Color(0xFFF7F8F9),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_note, color: textColor, size: 22),
                  ),
                  title: Text(
                    'Añadir Plato Manualmente',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Formulario detallado para ingresar foto, nombre y precio paso a paso.',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openManualDishForm();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startAiMenuScan() async {
    if (_currentHueca == null) return;

    final file = await ImagePickerHelper.showImageSourceDialog(
      context: context,
      title: 'Escanear Menú con IA',
      subtitle: '¿De dónde deseas cargar la foto de tu carta física o afiche?',
      imageQuality: 90,
      maxWidth: 1920,
    );

    if (file == null) return;

    setState(() => _isAiProcessing = true);

    try {
      final ocrResult = await MenuOcrService.extractDishesFromImage(file.path);

      if (!mounted) return;
      setState(() => _isAiProcessing = false);

      if (ocrResult.dishes.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 8),
                Text('Sin platos detectados'),
              ],
            ),
            content: Text(
              ocrResult.rawText.trim().isEmpty
                  ? 'No se detectó ningún texto en la fotografía. Intenta tomar una foto más nítida y con mejor iluminación.'
                  : 'Se detectó texto pero no se reconocieron precios claros (\$X.XX). ¿Deseas ingresar a la pantalla de revisión para cargar platos manualmente o revisar el texto?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Reintentar Foto'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MenuReviewScreen(
                        huecaId: _currentHueca!.id,
                        initialDishes: const [],
                        rawOcrText: ocrResult.rawText,
                      ),
                    ),
                  ).then((val) {
                    if (val == true) _loadHueca();
                  });
                },
                child: const Text('Revisar Texto'),
              ),
            ],
          ),
        );
        return;
      }

      // Platos detectados exitosamente -> Navegar a pantalla de revisión
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MenuReviewScreen(
            huecaId: _currentHueca!.id,
            initialDishes: ocrResult.dishes,
            rawOcrText: ocrResult.rawText,
          ),
        ),
      );

      if (result == true) {
        _loadHueca();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAiProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la imagen con IA: $e')),
        );
      }
    }
  }

  /// Escanea un solo plato a partir de una foto y prellena el formulario con la imagen vinculada
  Future<void> _startSingleDishScan() async {
    if (_currentHueca == null) return;

    final file = await ImagePickerHelper.showImageSourceDialog(
      context: context,
      title: 'Escanear Plato Individual (IA)',
      subtitle: 'Toma una foto o elígela de tu galería o Google Fotos',
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (file == null) return;

    setState(() => _isAiProcessing = true);

    try {
      final ocrResult = await MenuOcrService.extractDishesFromImage(file.path);

      if (!mounted) return;
      setState(() => _isAiProcessing = false);

      Map<String, dynamic>? initialDishData;
      if (ocrResult.dishes.isNotEmpty) {
        initialDishData = ocrResult.dishes.first;
      }

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DishFormScreen(
            huecaId: _currentHueca!.id,
            initialDish: initialDishData,
            initialImageFile: File(file.path),
          ),
        ),
      );

      if (result == true) {
        _loadHueca();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar el plato: $e')),
      );
    }
  }

  /// Permite subir múltiples fotos de platos a la vez, asignando cada foto a un plato individual
  Future<void> _startMultiDishUpload() async {
    if (_currentHueca == null) return;

    final picker = ImagePicker();
    final List<XFile> pickedImages = await picker.pickMultiImage(imageQuality: 85);
    if (pickedImages.isEmpty) return;

    setState(() => _isAiProcessing = true);

    try {
      final List<Map<String, dynamic>> extractedDishes = [];

      for (int i = 0; i < pickedImages.length; i++) {
        final img = pickedImages[i];
        final ocr = await MenuOcrService.extractDishesFromImage(img.path);

        Map<String, dynamic> dish;
        if (ocr.dishes.isNotEmpty) {
          dish = Map<String, dynamic>.from(ocr.dishes.first);
        } else {
          dish = {
            'id': 'dish_${DateTime.now().millisecondsSinceEpoch}_$i',
            'name': {'es': '', 'en': ''},
            'description': {'es': '', 'en': ''},
            'price': 0.0,
            'category': 'Platos Fuertes',
          };
        }
        dish['_localImagePath'] = img.path;
        dish['imageUrl'] = '';
        dish['isAvailable'] = true;
        extractedDishes.add(dish);
      }

      if (!mounted) return;
      setState(() => _isAiProcessing = false);

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MenuReviewScreen(
            huecaId: _currentHueca!.id,
            initialDishes: extractedDishes,
            rawOcrText: 'Fotos individuales de platos (${extractedDishes.length} fotos seleccionadas)',
          ),
        ),
      );

      if (result == true) {
        _loadHueca();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar las fotos: $e')),
      );
    }
  }

  Future<void> _openManualDishForm({Map<String, dynamic>? dish, int? index}) async {
    if (_currentHueca == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DishFormScreen(
          huecaId: _currentHueca!.id,
          initialDish: dish,
          dishIndex: index,
        ),
      ),
    );

    if (result == true) {
      _loadHueca();
    }
  }

  void _confirmDeleteDish(int index) {
    final dish = _menuItems[index];
    final nameObj = dish['name'];
    final nameText = nameObj is Map ? (nameObj['es'] ?? '') : (nameObj?.toString() ?? 'Plato');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Plato'),
        content: Text('¿Estás seguro de que deseas eliminar "$nameText" del menú?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _menuItems.removeAt(index);
              });
              _saveMenu();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _viewDishDetails(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.grey[400] : AppTheme.textMedium;

    final dish = _menuItems[index];
    final nameObj = dish['name'];
    final nameText = nameObj is Map ? (nameObj['es'] ?? '') : (nameObj?.toString() ?? '');
    final nameEnText = nameObj is Map ? (nameObj['en'] ?? '') : '';
    final descObj = dish['description'];
    final descText = descObj is Map ? (descObj['es'] ?? '') : (descObj?.toString() ?? '');
    final descEnText = descObj is Map ? (descObj['en'] ?? '') : '';
    final price = dish['price']?.toString() ?? '0.00';
    final imageUrl = dish['imageUrl']?.toString() ?? dish['image']?.toString() ?? '';
    final category = dish['category']?.toString() ?? 'Platos Fuertes';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nameText, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            if (nameEnText.isNotEmpty && nameEnText != nameText)
              Text(nameEnText, style: TextStyle(color: subtextColor, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Precio: \$$price',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(category, style: TextStyle(fontSize: 11, color: textColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                descText.isNotEmpty ? descText : 'Sin descripción',
                style: TextStyle(color: textColor),
              ),
              if (descEnText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  descEnText,
                  style: TextStyle(color: subtextColor, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final huecaAsync = ref.watch(myHuecaProvider);
    final isOwnerState = ref.watch(isOwnerProvider).value;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_currentHueca == null && huecaAsync.value != null) {
      _currentHueca = huecaAsync.value;
      _menuItems = List.from(_currentHueca!.menuItems);
      _isLoading = false;
    }

    final bool isOwner = isOwnerState ??
        (currentUser != null && _currentHueca != null && _currentHueca!.ownerId == currentUser.uid);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.grey[400] : AppTheme.textMedium;
    final cardBorder = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final thumbBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6);

    if (_isLoading && _currentHueca == null) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_currentHueca == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Menú Digital', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('No se encontró información de la hueca'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: () {
                  ref.invalidate(huecasProvider);
                  ref.invalidate(myHuecaProvider);
                  _loadHueca();
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Menú Digital', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: Icon(Icons.add, color: AppTheme.primary),
              tooltip: 'Añadir plato',
              onPressed: _showAddDishModal,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        'Solo Matriz',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(huecasProvider);
          ref.invalidate(myHuecaProvider);
          await _loadHueca();
        },
        child: Column(
          children: [
            if (!isOwner)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade700.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El menú digital es administrado exclusivamente por la matriz principal. Modo solo lectura.',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isAiProcessing
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 64),
                            ),
                            const SizedBox(height: 24),
                            CircularProgressIndicator(color: AppTheme.primary),
                            const SizedBox(height: 24),
                            const Text(
                              'Analizando carta con Inteligencia Artificial...',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Extrayendo platos, precios y generando traducciones al inglés',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _menuItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book, size: 80, color: Colors.grey[600]),
                                const SizedBox(height: 24),
                                Text(
                                  isOwner ? 'Tu menú digital está vacío' : 'No hay platos registrados',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isOwner
                                      ? 'Puedes escanear una foto de tu carta física con nuestra IA o ingresar tus platos manualmente uno a uno.'
                                      : 'La matriz principal aún no ha añadido platos al menú digital.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                if (isOwner) ...[
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _startAiMenuScan,
                                      icon: const Icon(Icons.auto_awesome),
                                      label: const Text('Escanear Carta con IA'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        backgroundColor: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _openManualDishForm(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Añadir Plato Manualmente'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _menuItems.length,
                          itemBuilder: (context, index) {
                            final dish = _menuItems[index];
                            final imageUrl = dish['imageUrl']?.toString() ?? dish['image']?.toString() ?? '';
                            final hasImage = imageUrl.isNotEmpty;

                            final nameObj = dish['name'];
                            final nameEs = nameObj is Map ? (nameObj['es'] ?? '') : (nameObj?.toString() ?? '');
                            final nameEn = nameObj is Map ? (nameObj['en'] ?? '') : '';

                            final descObj = dish['description'];
                            final descEs = descObj is Map ? (descObj['es'] ?? '') : (descObj?.toString() ?? '');
                            final descEn = descObj is Map ? (descObj['en'] ?? '') : '';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: isDark ? 0 : 2,
                              shadowColor: Colors.black.withOpacity(0.04),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: hasImage ? cardBorder : (isDark ? Colors.amber.withOpacity(0.4) : Colors.amber.shade300),
                                  width: 1,
                                ),
                              ),
                              color: cardBg,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                onTap: isOwner
                                    ? () => _openManualDishForm(dish: Map<String, dynamic>.from(dish), index: index)
                                    : () => _viewDishDetails(index),
                                leading: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: thumbBg,
                                    borderRadius: BorderRadius.circular(10),
                                    image: hasImage
                                        ? DecorationImage(
                                            image: NetworkImage(imageUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: !hasImage
                                      ? Icon(Icons.restaurant, color: isDark ? Colors.grey[500] : Colors.grey[400])
                                      : null,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nameEs,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (nameEn.isNotEmpty && nameEn.toLowerCase() != nameEs.toLowerCase())
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'EN',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (nameEn.isNotEmpty && nameEn.toLowerCase() != nameEs.toLowerCase())
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Text(
                                          nameEn,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isDark ? Colors.lightBlueAccent.withOpacity(0.9) : Colors.blue.shade700,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '\$${dish['price']}',
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (dish['category'] != null) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '•  ${dish['category']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(color: subtextColor, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (descEs.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          descEs,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: subtextColor, fontSize: 11),
                                        ),
                                      ),
                                    if (descEn.isNotEmpty && descEn.toLowerCase() != descEs.toLowerCase())
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          '🇬🇧 $descEn',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: (subtextColor ?? Colors.grey).withOpacity(0.85),
                                            fontSize: 10.5,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    if (!hasImage && isOwner)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Sin foto asignada',
                                          style: TextStyle(
                                            color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: isOwner
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            icon: Icon(Icons.edit_outlined, size: 20, color: subtextColor),
                                            tooltip: 'Editar plato',
                                            onPressed: () => _openManualDishForm(
                                              dish: Map<String, dynamic>.from(dish),
                                              index: index,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
                                            tooltip: 'Eliminar plato',
                                            onPressed: () => _confirmDeleteDish(index),
                                          ),
                                        ],
                                      )
                                    : IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: Icon(Icons.visibility_outlined, size: 20, color: subtextColor),
                                        onPressed: () => _viewDishDetails(index),
                                      ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: isOwner && _menuItems.isNotEmpty && !_isAiProcessing
          ? FloatingActionButton.extended(
              onPressed: _showAddDishModal,
              icon: const Icon(Icons.add),
              label: const Text('Añadir Plato'),
              backgroundColor: AppTheme.primary,
            )
          : null,
    );
  }
}
