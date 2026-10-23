import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/services/translation_service.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';

class DishFormScreen extends ConsumerStatefulWidget {
  final String huecaId;
  final Map<String, dynamic>? initialDish;
  final int? dishIndex;
  final File? initialImageFile;

  const DishFormScreen({
    super.key,
    required this.huecaId,
    this.initialDish,
    this.dishIndex,
    this.initialImageFile,
  });

  @override
  ConsumerState<DishFormScreen> createState() => _DishFormScreenState();
}

class _DishFormScreenState extends ConsumerState<DishFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameEsCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _descEsCtrl;
  late TextEditingController _descEnCtrl;
  late TextEditingController _priceCtrl;

  String _selectedCategory = 'Platos Fuertes';
  bool _isAvailable = true;
  String _imageUrl = '';
  File? _localImageFile;

  bool _isTranslatingName = false;
  bool _isTranslatingDesc = false;
  bool _isTranslatingAll = false;
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
    final dish = widget.initialDish;

    String nameEs = '';
    String nameEn = '';
    if (dish != null && dish['name'] != null) {
      if (dish['name'] is Map) {
        nameEs = dish['name']['es']?.toString() ?? '';
        nameEn = dish['name']['en']?.toString() ?? '';
      } else {
        nameEs = dish['name'].toString();
      }
    }

    String descEs = '';
    String descEn = '';
    if (dish != null && dish['description'] != null) {
      if (dish['description'] is Map) {
        descEs = dish['description']['es']?.toString() ?? '';
        descEn = dish['description']['en']?.toString() ?? '';
      } else {
        descEs = dish['description'].toString();
      }
    }

    _nameEsCtrl = TextEditingController(text: nameEs);
    _nameEnCtrl = TextEditingController(text: nameEn);
    _descEsCtrl = TextEditingController(text: descEs);
    _descEnCtrl = TextEditingController(text: descEn);

    final rawPrice = dish?['price'];
    _priceCtrl = TextEditingController(
      text: rawPrice != null ? rawPrice.toString() : '',
    );

    _imageUrl = dish?['imageUrl']?.toString() ?? dish?['image']?.toString() ?? '';
    _isAvailable = dish?['isAvailable'] as bool? ?? true;
    if (widget.initialImageFile != null) {
      _localImageFile = widget.initialImageFile;
    }

    final cat = dish?['category']?.toString();
    if (cat != null && _categories.contains(cat)) {
      _selectedCategory = cat;
    } else if (cat != null && cat.isNotEmpty) {
      _categories.insert(0, cat);
      _selectedCategory = cat;
    }
  }

  @override
  void dispose() {
    _nameEsCtrl.dispose();
    _nameEnCtrl.dispose();
    _descEsCtrl.dispose();
    _descEnCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceModal() async {
    final file = await ImagePickerHelper.showImageSourceDialog(
      context: context,
      title: 'Foto del Plato',
      subtitle: 'Elige de dónde prefieres cargar la foto de este plato',
      includeRemove: _imageUrl.isNotEmpty || _localImageFile != null,
      onRemove: () {
        setState(() {
          _imageUrl = '';
          _localImageFile = null;
        });
      },
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (file != null) {
      setState(() {
        _localImageFile = file;
      });
    }
  }

  Future<void> _translateName() async {
    final text = _nameEsCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre en español primero')),
      );
      return;
    }

    setState(() => _isTranslatingName = true);
    final translated = await TranslationService.translateEsToEn(text);
    if (mounted) {
      setState(() {
        _nameEnCtrl.text = translated;
        _isTranslatingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre traducido al inglés')),
      );
    }
  }

  Future<void> _translateDesc() async {
    final text = _descEsCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe la descripción en español primero')),
      );
      return;
    }

    setState(() => _isTranslatingDesc = true);
    final translated = await TranslationService.translateEsToEn(text);
    if (mounted) {
      setState(() {
        _descEnCtrl.text = translated;
        _isTranslatingDesc = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descripción traducida al inglés')),
      );
    }
  }

  Future<void> _translateAll() async {
    final name = _nameEsCtrl.text.trim();
    final desc = _descEsCtrl.text.trim();

    if (name.isEmpty && desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre o la descripción en español')),
      );
      return;
    }

    setState(() => _isTranslatingAll = true);

    String translatedName = _nameEnCtrl.text;
    String translatedDesc = _descEnCtrl.text;

    if (name.isNotEmpty) {
      translatedName = await TranslationService.translateEsToEn(name);
    }
    if (desc.isNotEmpty) {
      translatedDesc = await TranslationService.translateEsToEn(desc);
    }

    if (mounted) {
      setState(() {
        _nameEnCtrl.text = translatedName;
        _descEnCtrl.text = translatedDesc;
        _isTranslatingAll = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text('¡Traducción automática al inglés completada!'),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _saveDish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String finalImageUrl = _imageUrl;

      // Subir imagen a Firebase Storage si se seleccionó una nueva
      if (_localImageFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('dish_images/${widget.huecaId}_dish_$timestamp.jpg');
        final uploadTask = await storageRef.putFile(_localImageFile!);
        finalImageUrl = await uploadTask.ref.getDownloadURL();
      }

      // Si el campo inglés está vacío pero el español lleno, autotraducir antes de guardar
      String finalNameEn = _nameEnCtrl.text.trim();
      if (finalNameEn.isEmpty && _nameEsCtrl.text.trim().isNotEmpty) {
        finalNameEn = await TranslationService.translateEsToEn(_nameEsCtrl.text.trim());
      }

      String finalDescEn = _descEnCtrl.text.trim();
      if (finalDescEn.isEmpty && _descEsCtrl.text.trim().isNotEmpty) {
        finalDescEn = await TranslationService.translateEsToEn(_descEsCtrl.text.trim());
      }

      final double price = double.tryParse(_priceCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
      final dishId = widget.initialDish?['id']?.toString() ??
          'dish_${DateTime.now().millisecondsSinceEpoch}';

      final dishData = {
        'id': dishId,
        'name': {
          'es': _nameEsCtrl.text.trim(),
          'en': finalNameEn.isNotEmpty ? finalNameEn : _nameEsCtrl.text.trim(),
        },
        'description': {
          'es': _descEsCtrl.text.trim(),
          'en': finalDescEn,
        },
        'price': price,
        'category': _selectedCategory,
        'imageUrl': finalImageUrl,
        'image': finalImageUrl, // Compatibilidad con vistas de turista
        'isAvailable': _isAvailable,
      };

      // Cargar platos existentes de Firestore
      final huecaDoc = await FirebaseFirestore.instance
          .collection('huecas')
          .doc(widget.huecaId)
          .get();

      final existingMenu = List<dynamic>.from(huecaDoc.data()?['menuItems'] ?? []);

      if (widget.dishIndex != null &&
          widget.dishIndex! >= 0 &&
          widget.dishIndex! < existingMenu.length) {
        existingMenu[widget.dishIndex!] = dishData;
      } else {
        existingMenu.add(dishData);
      }

      final docData = Map<String, dynamic>.from(huecaDoc.data() ?? {});
      docData['menuItems'] = existingMenu;
      final newSearchTags = Hueca.extractSearchKeywords(docData);

      await FirebaseFirestore.instance
          .collection('huecas')
          .doc(widget.huecaId)
          .update({
            'menuItems': existingMenu,
            'searchTags': newSearchTags,
          });

      ref.invalidate(myHuecaProvider);
      ref.invalidate(huecasProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.dishIndex != null
                  ? 'Plato actualizado correctamente'
                  : 'Plato añadido al menú exitosamente',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar plato: $e')),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    String? prefixText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF282828) : const Color(0xFFF7F8F9);
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFD6D8DB);
    final labelColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final hintColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: labelColor, fontSize: 13),
      hintText: hintText,
      hintStyle: TextStyle(color: hintColor, fontSize: 13),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.grey[400] : AppTheme.textMedium;
    final cardBorder = isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);
    final bannerBg = isDark ? AppTheme.primary.withOpacity(0.15) : AppTheme.primary.withOpacity(0.08);
    final bannerBorder = isDark ? AppTheme.primary.withOpacity(0.35) : AppTheme.primary.withOpacity(0.25);
    final photoBoxBg = isDark ? const Color(0xFF282828) : const Color(0xFFF3F4F6);
    final switchTileBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final isEditing = widget.initialDish != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Plato' : 'Nuevo Plato Manual',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveDish,
              icon: const Icon(Icons.check, color: AppTheme.primary),
              label: const Text(
                'Guardar',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text('Guardando plato en el menú...', style: TextStyle(fontSize: 16, color: textColor)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // --- FOTO DEL PLATO ---
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceModal,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: photoBoxBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _localImageFile != null
                                  ? Image.file(_localImageFile!, fit: BoxFit.cover)
                                  : _imageUrl.isNotEmpty
                                      ? Image.network(
                                          _imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.image_not_supported,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo_outlined,
                                              size: 44,
                                              color: AppTheme.primary.withOpacity(0.85),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Subir foto',
                                              style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: _showImageSourceModal,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Toca para tomar foto o elegir de galería',
                      style: TextStyle(color: subtextColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- BANNER DE AUTO-TRADUCCIÓN IA ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bannerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: bannerBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Traducción Bilingüe Automática',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Traduce al inglés para turistas internacionales con un toque.',
                                style: TextStyle(color: subtextColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isTranslatingAll ? null : _translateAll,
                          icon: _isTranslatingAll
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                )
                              : const Icon(Icons.g_translate, size: 16),
                          label: const Text('Traducir', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- NOMBRE EN ESPAÑOL ---
                  TextFormField(
                    controller: _nameEsCtrl,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Nombre del Plato (Español) *',
                      hintText: 'Ej. Fritada con Mote y Llapingachos',
                      prefixIcon: const Icon(Icons.restaurant_menu, color: AppTheme.primary),
                      suffixIcon: IconButton(
                        icon: _isTranslatingName
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              )
                            : const Icon(Icons.g_translate, color: AppTheme.primary),
                        tooltip: 'Traducir nombre al inglés',
                        onPressed: _isTranslatingName ? null : _translateName,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresa el nombre del plato';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- NOMBRE EN INGLÉS ---
                  TextFormField(
                    controller: _nameEnCtrl,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Nombre en Inglés (English)',
                      hintText: 'Ej. Fried Pork with Hominy and Potato Cakes',
                      prefixIcon: const Icon(Icons.language, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- PRECIO Y CATEGORÍA ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Precio
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: _buildInputDecoration(
                            context: context,
                            labelText: 'Precio *',
                            prefixText: '\$ ',
                            hintText: '4.50',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Ingresa precio';
                            }
                            final p = double.tryParse(val.replaceAll(',', '.'));
                            if (p == null || p < 0) {
                              return 'Inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Categoría
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          dropdownColor: isDark ? const Color(0xFF282828) : Colors.white,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: _buildInputDecoration(
                            context: context,
                            labelText: 'Categoría',
                          ),
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: TextStyle(color: textColor, fontSize: 13)),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- DESCRIPCIÓN EN ESPAÑOL ---
                  TextFormField(
                    controller: _descEsCtrl,
                    maxLines: 3,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Descripción (Español)',
                      hintText: 'Describe los ingredientes, guarniciones y preparación...',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.description_outlined, color: AppTheme.primary),
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: IconButton(
                          icon: _isTranslatingDesc
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                )
                              : const Icon(Icons.g_translate, color: AppTheme.primary),
                          tooltip: 'Traducir descripción al inglés',
                          onPressed: _isTranslatingDesc ? null : _translateDesc,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- DESCRIPCIÓN EN INGLÉS ---
                  TextFormField(
                    controller: _descEnCtrl,
                    maxLines: 3,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Descripción en Inglés (English)',
                      hintText: 'Description of ingredients and side dishes for tourists...',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.translate, color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- DISPONIBILIDAD ---
                  Container(
                    decoration: BoxDecoration(
                      color: switchTileBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SwitchListTile(
                      activeColor: AppTheme.primary,
                      title: Text(
                        'Disponible en la Carta',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: Text(
                        _isAvailable ? 'Visible para clientes y turistas' : 'Marcado como agotado temporalmente',
                        style: TextStyle(color: subtextColor, fontSize: 12),
                      ),
                      value: _isAvailable,
                      onChanged: (val) => setState(() => _isAvailable = val),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- BOTÓN PRINCIPAL DE GUARDAR ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveDish,
                      icon: const Icon(Icons.save_outlined, color: Colors.white),
                      label: Text(
                        isEditing ? 'Guardar Cambios' : 'Añadir Plato al Menú',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
