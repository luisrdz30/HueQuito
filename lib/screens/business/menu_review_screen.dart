import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/services/translation_service.dart';
import 'package:hue_quito/services/menu_ocr_service.dart';
import 'package:hue_quito/providers/data_provider.dart';

class MenuReviewScreen extends ConsumerStatefulWidget {
  final String huecaId;
  final List<Map<String, dynamic>> initialDishes;
  final String rawOcrText;

  const MenuReviewScreen({
    super.key,
    required this.huecaId,
    required this.initialDishes,
    this.rawOcrText = '',
  });

  @override
  ConsumerState<MenuReviewScreen> createState() => _MenuReviewScreenState();
}

class _MenuReviewScreenState extends ConsumerState<MenuReviewScreen> {
  late List<Map<String, dynamic>> _dishes;
  bool _isSaving = false;
  final List<String> _categories = [
    'Platos Fuertes',
    'Platos Típicos',
    'Entradas y Guarniciones',
    'Sopas y Caldos',
    'Bebidas',
    'Postres',
    'Especialidades',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _dishes = widget.initialDishes.map((d) => Map<String, dynamic>.from(d)).toList();
  }

  void _addNewDish() {
    setState(() {
      _dishes.add({
        'id': 'dish_${DateTime.now().millisecondsSinceEpoch}_${_dishes.length}',
        'name': {'es': '', 'en': ''},
        'description': {'es': '', 'en': ''},
        'price': 0.0,
        'category': 'Platos Típicos',
        'imageUrl': '',
        'image': '',
        'isAvailable': true,
      });
    });
  }

  void _removeDish(int index) {
    setState(() {
      _dishes.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plato eliminado de la lista de revisión')),
    );
  }

  Future<void> _pickDishImage(int index, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 75);
      if (picked != null) {
        setState(() {
          _dishes[index]['_localImagePath'] = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  void _showImagePickerModal(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                'Foto del Plato',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
                title: Text('Tomar foto con la cámara', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDishImage(index, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primary),
                title: Text('Elegir de la galería', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDishImage(index, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _translateDish(int index) async {
    final dish = _dishes[index];
    final nameEs = dish['name'] is Map ? (dish['name']['es'] ?? '') : dish['name'].toString();
    final descEs = dish['description'] is Map ? (dish['description']['es'] ?? '') : '';

    if (nameEs.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre en español para traducir')),
      );
      return;
    }

    final transName = await TranslationService.translateEsToEn(nameEs.toString().trim());
    String transDesc = '';
    if (descEs.toString().trim().isNotEmpty) {
      transDesc = await TranslationService.translateEsToEn(descEs.toString().trim());
    }

    setState(() {
      _dishes[index]['name'] = {
        'es': nameEs,
        'en': transName,
      };
      _dishes[index]['description'] = {
        'es': descEs,
        'en': transDesc,
      };
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Traducción actualizada con éxito')),
      );
    }
  }

  Future<void> _saveAllDishes() async {
    if (_dishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay platos para agregar')),
      );
      return;
    }

    // Filtrar platos que tengan al menos nombre
    final validDishes = _dishes.where((d) {
      final n = d['name'];
      final nameEs = n is Map ? (n['es'] ?? '') : (n?.toString() ?? '');
      return nameEs.toString().trim().isNotEmpty;
    }).toList();

    if (validDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena el nombre de al menos un plato')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> finalDishesToSave = [];

      for (int i = 0; i < validDishes.length; i++) {
        final d = validDishes[i];
        String imageUrl = d['imageUrl']?.toString() ?? '';

        // Subir imagen local si fue seleccionada
        final localPath = d['_localImagePath'] as String?;
        if (localPath != null && localPath.isNotEmpty) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('dish_images/${widget.huecaId}_dish_${timestamp}_$i.jpg');
          final uploadTask = await storageRef.putFile(File(localPath));
          imageUrl = await uploadTask.ref.getDownloadURL();
        }

        final nameObj = d['name'];
        final String nameEs = nameObj is Map ? (nameObj['es'] ?? '') : (nameObj?.toString() ?? '');
        String nameEn = nameObj is Map ? (nameObj['en'] ?? '') : '';
        if (nameEn.isEmpty && nameEs.isNotEmpty) {
          nameEn = await TranslationService.translateEsToEn(nameEs);
        }

        final descObj = d['description'];
        final String descEs = descObj is Map ? (descObj['es'] ?? '') : (descObj?.toString() ?? '');
        String descEn = descObj is Map ? (descObj['en'] ?? '') : '';
        if (descEn.isEmpty && descEs.isNotEmpty) {
          descEn = await TranslationService.translateEsToEn(descEs);
        }

        final price = d['price'] is num
            ? (d['price'] as num).toDouble()
            : (double.tryParse(d['price']?.toString() ?? '0') ?? 0.0);

        final category = d['category']?.toString() ?? 'Platos Fuertes';

        finalDishesToSave.add({
          'id': d['id'] ?? 'dish_${DateTime.now().millisecondsSinceEpoch}_$i',
          'name': {
            'es': nameEs.trim(),
            'en': nameEn.trim().isNotEmpty ? nameEn.trim() : nameEs.trim(),
          },
          'description': {
            'es': descEs.trim(),
            'en': descEn.trim(),
          },
          'price': price,
          'category': category,
          'imageUrl': imageUrl,
          'image': imageUrl,
          'isAvailable': true,
        });
      }

      // Obtener platos existentes y agregar los nuevos
      final docRef = FirebaseFirestore.instance.collection('huecas').doc(widget.huecaId);
      final snap = await docRef.get();
      final existing = List<dynamic>.from(snap.data()?['menuItems'] ?? []);

      existing.addAll(finalDishesToSave);

      await docRef.update({'menuItems': existing});

      ref.invalidate(myHuecaProvider);
      ref.invalidate(huecasProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡${finalDishesToSave.length} platos guardados en tu menú!',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar platos: $e')),
        );
      }
    }
  }

  void _showRawTextModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.grey[400] : AppTheme.textMedium;
    final boxBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F8F9);
    final boxBorder = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_snippet_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Texto Reconocido por la IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Este es el texto en bruto que ML Kit reconoció en la imagen tomada:',
              style: TextStyle(color: subtextColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: boxBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.rawOcrText.isNotEmpty ? widget.rawOcrText : '(No se detectó texto en la imagen)',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: textColor),
                  ),
                ),
              ),
            ),
            if (widget.rawOcrText.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Re-analizar Texto con IA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isSaving = true);
                    final reDishes = await MenuOcrService.parseRawTextToDishes(widget.rawOcrText);
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                        if (reDishes.isNotEmpty) {
                          _dishes = reDishes;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Se re-analizó el texto: ${reDishes.length} platos detectados')),
                      );
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String labelText,
    String? prefixText,
    Widget? suffixIcon,
    bool isDense = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF282828) : const Color(0xFFF7F8F9);
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFD6D8DB);
    final labelColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: labelColor, fontSize: 13),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
      suffixIcon: suffixIcon,
      isDense: isDense,
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.grey[400] : AppTheme.textMedium;
    final bannerBg = isDark ? AppTheme.primary.withOpacity(0.15) : AppTheme.primary.withOpacity(0.08);
    final bannerBorder = isDark ? AppTheme.primary.withOpacity(0.35) : AppTheme.primary.withOpacity(0.25);
    final bottomBarBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bottomBarBorder = isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Revisar Platos (IA)',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.rawOcrText.isNotEmpty)
            IconButton(
              icon: Icon(Icons.description_outlined, color: textColor),
              tooltip: 'Ver texto en bruto OCR',
              onPressed: _showRawTextModal,
            ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Guardando platos en el menú...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Text('Subiendo fotos y traduciendo textos', style: TextStyle(color: subtextColor)),
                ],
              ),
            )
          : Column(
              children: [
                // Info banner con colores armoniosos
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bannerBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: bannerBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Detectamos ${_dishes.length} platos en tu menú. Revisa o corrige los precios y nombres antes de agregarlos.',
                          style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de platos detectados
                Expanded(
                  child: _dishes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fastfood_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No quedan platos en la lista de revisión', style: TextStyle(fontSize: 16, color: textColor)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _addNewDish,
                                icon: const Icon(Icons.add),
                                label: const Text('Añadir un plato manualmente'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _dishes.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _dishes.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: OutlinedButton.icon(
                                  onPressed: _addNewDish,
                                  icon: const Icon(Icons.add, color: AppTheme.primary),
                                  label: const Text(
                                    '+ Añadir otro plato a esta lista',
                                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isDark ? AppTheme.primary.withOpacity(0.08) : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: AppTheme.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              );
                            }

                            final dish = _dishes[index];
                            final nameObj = dish['name'];
                            final nameEs = nameObj is Map ? (nameObj['es'] ?? '') : (nameObj?.toString() ?? '');
                            final nameEn = nameObj is Map ? (nameObj['en'] ?? '') : '';
                            final descObj = dish['description'];
                            final descEs = descObj is Map ? (descObj['es'] ?? '') : '';
                            final descEn = descObj is Map ? (descObj['en'] ?? '') : '';
                            final price = dish['price']?.toString() ?? '0.00';
                            final category = dish['category']?.toString() ?? 'Platos Fuertes';
                            final localPath = dish['_localImagePath'] as String?;
                            final imageUrl = dish['imageUrl']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Plato # + Delete
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppTheme.primary,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Plato detectado',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.g_translate, color: AppTheme.primary, size: 20),
                                          tooltip: 'Traducir al inglés con IA',
                                          onPressed: () => _translateDish(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          tooltip: 'Descartar plato',
                                          onPressed: () => _removeDish(index),
                                        ),
                                      ],
                                    ),
                                    Divider(height: 16, color: cardBorder),

                                    // Imagen miniatura + Nombre ES & Precio
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Miniatura de foto
                                        GestureDetector(
                                          onTap: () => _showImagePickerModal(index),
                                          child: Container(
                                            width: 76,
                                            height: 76,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: cardBorder),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(11),
                                              child: localPath != null
                                                  ? Image.file(File(localPath), fit: BoxFit.cover)
                                                  : imageUrl.isNotEmpty
                                                      ? Image.network(imageUrl, fit: BoxFit.cover)
                                                      : Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(Icons.add_a_photo, size: 22, color: AppTheme.primary.withOpacity(0.8)),
                                                            const SizedBox(height: 4),
                                                            Text('Foto', style: TextStyle(fontSize: 10, color: subtextColor)),
                                                          ],
                                                        ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Nombre Español y Precio
                                        Expanded(
                                          child: Column(
                                            children: [
                                              TextFormField(
                                                initialValue: nameEs,
                                                style: TextStyle(color: textColor, fontSize: 14),
                                                decoration: _buildInputDecoration(
                                                  context: context,
                                                  labelText: 'Nombre (Español) *',
                                                ),
                                                onChanged: (val) {
                                                  _dishes[index]['name']['es'] = val;
                                                },
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                initialValue: price,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                decoration: _buildInputDecoration(
                                                  context: context,
                                                  labelText: 'Precio (\$)',
                                                  prefixText: '\$ ',
                                                ),
                                                onChanged: (val) {
                                                  _dishes[index]['price'] = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Nombre en Inglés
                                    TextFormField(
                                      initialValue: nameEn,
                                      style: TextStyle(color: textColor, fontSize: 14),
                                      decoration: _buildInputDecoration(
                                        context: context,
                                        labelText: 'Nombre en Inglés (English)',
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.g_translate, size: 16, color: AppTheme.primary),
                                          tooltip: 'Traducir nombre al inglés',
                                          onPressed: () => _translateDish(index),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        _dishes[index]['name']['en'] = val;
                                      },
                                    ),
                                    const SizedBox(height: 10),

                                    // Categoría
                                    DropdownButtonFormField<String>(
                                      value: _categories.contains(category) ? category : 'Platos Fuertes',
                                      dropdownColor: isDark ? const Color(0xFF282828) : Colors.white,
                                      style: TextStyle(color: textColor, fontSize: 14),
                                      decoration: _buildInputDecoration(
                                        context: context,
                                        labelText: 'Categoría',
                                      ),
                                      items: _categories
                                          .map((c) => DropdownMenuItem(
                                                value: c,
                                                child: Text(c, style: TextStyle(color: textColor, fontSize: 13)),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _dishes[index]['category'] = val);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 10),

                                    // Descripción (Español)
                                    TextFormField(
                                      initialValue: descEs,
                                      maxLines: 2,
                                      style: TextStyle(color: textColor, fontSize: 13),
                                      decoration: _buildInputDecoration(
                                        context: context,
                                        labelText: 'Descripción (Español)',
                                      ),
                                      onChanged: (val) {
                                        _dishes[index]['description']['es'] = val;
                                      },
                                    ),
                                    const SizedBox(height: 10),

                                    // Descripción en Inglés (English)
                                    TextFormField(
                                      initialValue: descEn,
                                      maxLines: 2,
                                      style: TextStyle(color: textColor, fontSize: 13),
                                      decoration: _buildInputDecoration(
                                        context: context,
                                        labelText: 'Descripción en Inglés (English)',
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.g_translate, size: 16, color: AppTheme.primary),
                                          tooltip: 'Traducir al inglés con IA',
                                          onPressed: () => _translateDish(index),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        _dishes[index]['description']['en'] = val;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _dishes.isEmpty || _isSaving
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bottomBarBg,
                border: Border(top: BorderSide(color: bottomBarBorder)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saveAllDishes,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: Text(
                      'Confirmar y Guardar ${_dishes.length} Platos en Menú',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
