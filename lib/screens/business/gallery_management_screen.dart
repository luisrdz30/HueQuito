import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GalleryManagementScreen extends ConsumerStatefulWidget {
  final String huecaId;
  const GalleryManagementScreen({super.key, required this.huecaId});

  @override
  ConsumerState<GalleryManagementScreen> createState() => _GalleryManagementScreenState();
}

class _GalleryManagementScreenState extends ConsumerState<GalleryManagementScreen> {
  bool _isProcessing = false;
  String _processingMessage = '';

  String get _effectiveHuecaId {
    if (widget.huecaId.isNotEmpty) return widget.huecaId;
    final myHueca = ref.read(myHuecaProvider).value;
    return myHueca?.id ?? '';
  }

  Future<void> _uploadImage(List<String> currentImages) async {
    if (currentImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya alcanzaste el límite de 5 fotos')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null || !mounted) return;

    final targetId = _effectiveHuecaId;
    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el ID de la hueca')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Subiendo imagen a la nube...';
    });

    try {
      File file = File(pickedFile.path);
      String fileName = '${targetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child('hueca_images/$fileName');

      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      final docRef = FirebaseFirestore.instance.collection('huecas').doc(targetId);
      
      // Update the array directly
      await docRef.update({
        'images': FieldValue.arrayUnion([downloadUrl])
      });

      ref.invalidate(huecasProvider);
      ref.invalidate(myHuecaProvider);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Imagen agregada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(String imageUrl, List<String> currentImages, int index) async {
    if (currentImages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe haber al menos 1 imagen principal')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: Text(
          index == 0
              ? 'Esta es la foto de portada. Si la eliminas, la siguiente imagen pasará a ser la nueva portada. ¿Continuar?'
              : '¿Seguro que deseas eliminar esta foto de la galería?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final targetId = _effectiveHuecaId;
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Eliminando imagen...';
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('huecas').doc(targetId);
      
      await docRef.update({
        'images': FieldValue.arrayRemove([imageUrl])
      });

      ref.invalidate(huecasProvider);
      ref.invalidate(myHuecaProvider);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetId = _effectiveHuecaId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos de la Hueca'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: (targetId.isNotEmpty && Firebase.apps.isNotEmpty)
            ? FirebaseFirestore.instance.collection('huecas').doc(targetId).snapshots()
            : null,
        builder: (context, snapshot) {
          List<String> images = [];

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            images = List<String>.from(data['images'] ?? []);
          } else {
            // Fallback to myHuecaProvider
            final myHueca = ref.watch(myHuecaProvider).value;
            if (myHueca != null) {
              images = List<String>.from(myHueca.images);
            }
          }

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Puedes tener hasta 5 fotos. La primera foto es la portada principal de tu hueca.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: images.isEmpty
                          ? const Center(
                              child: Text('Aún no tienes fotos agregadas'),
                            )
                          : GridView.builder(
                              itemCount: images.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemBuilder: (context, index) {
                                final imgUrl = images[index];
                                final isCover = index == 0;

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: isCover
                                        ? Border.all(color: AppTheme.primary, width: 2.5)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imgUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      if (isCover)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star, color: Colors.white, size: 12),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Portada',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Material(
                                          color: Colors.black54,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: _isProcessing
                                                ? null
                                                : () => _deleteImage(imgUrl, images, index),
                                            child: const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(Icons.delete, color: Colors.white, size: 18),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate),
                        label: Text(
                          _isProcessing
                              ? _processingMessage
                              : 'Subir Foto (${images.length}/5)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: images.length >= 5 ? Colors.grey : AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: (_isProcessing || images.length >= 5)
                            ? null
                            : () => _uploadImage(images),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: Center(
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppTheme.primary),
                              const SizedBox(height: 16),
                              Text(
                                _processingMessage,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
