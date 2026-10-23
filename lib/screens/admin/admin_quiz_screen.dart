import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hue_quito/models/gastronomic_profile.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';

class AdminQuizScreen extends ConsumerStatefulWidget {
  const AdminQuizScreen({super.key});

  @override
  ConsumerState<AdminQuizScreen> createState() => _AdminQuizScreenState();
}

class _AdminQuizScreenState extends ConsumerState<AdminQuizScreen> {
  bool _isSaving = false;

  void _showQuestionFormModal({QuizQuestion? question, int nextOrder = 1}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuestionFormModal(
        question: question,
        nextOrder: nextOrder,
        onSave: (savedQuestion) async {
          setState(() => _isSaving = true);
          try {
            await ref.read(quizRepositoryProvider).saveQuestion(savedQuestion);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    question == null
                        ? 'Pregunta creada exitosamente'
                        : 'Pregunta actualizada exitosamente',
                  ),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al guardar: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        },
      ),
    );
  }

  void _confirmDelete(QuizQuestion question) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar pregunta?'),
        content: Text(
          'Se eliminará la pregunta #${question.order}: "${question.titleEs}". Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSaving = true);
              try {
                await ref.read(quizRepositoryProvider).deleteQuestion(question.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pregunta eliminada'),
                      backgroundColor: Colors.blueGrey,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmResetDefaults() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restablecer Quiz'),
          ],
        ),
        content: const Text(
          'Esto reemplazará todas las preguntas actuales en la base de datos por las 4 preguntas originales oficiales de HueQuito con sus imágenes y perfiles gastronómicos.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSaving = true);
              try {
                await ref.read(quizRepositoryProvider).resetToDefaults();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preguntas originales restablecidas con éxito'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al restablecer: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text('Restablecer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(quizQuestionsStreamProvider);

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
        elevation: 0,
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
        title: const Text(
          'Quiz Gastronómico',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.amber),
            tooltip: 'Restablecer preguntas originales',
            onPressed: _isSaving ? null : _confirmResetDefaults,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: const Color(0xFF0F172A),
              onRefresh: () async {
                ref.invalidate(quizQuestionsStreamProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.orange.shade400, width: 2),
                            ),
                            child: const Icon(Icons.quiz, color: Colors.orange, size: 34),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Configuración del Quiz',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Personaliza preguntas, fotos y mapeo de perfiles gastronómicos.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade200,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Educational Guía Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber.shade800, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¿Cómo funciona la asignación automática?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cada opción que configuras suma 1 punto al perfil culinario asignado (🥣 Sopero, 🍖 Carnívoro, 🍔 Callejero, 🍰 Dulcero, 🥟 Picador, 🤠 Aventurero). Al responder, el algoritmo suma los puntos y entrega automáticamente el perfil ganador. ¡Puedes cambiar preguntas e imágenes libremente!',
                                  style: TextStyle(
                                    color: Colors.amber.shade900.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Actions Bar: Add question button & count
                    questionsAsync.when(
                      data: (questions) {
                        final list = questions.isNotEmpty ? questions : defaultQuizQuestions;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Preguntas del Quiz (${list.length})',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showQuestionFormModal(nextOrder: list.length + 1);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.amber,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.add, size: 18, color: Colors.amber),
                                  label: const Text(
                                    'Nueva Pregunta',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // List of questions
                            ...list.map((q) => _buildQuestionCard(q, list.length)),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error cargando preguntas: $err',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion q, int totalCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with order and action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Pregunta #${q.order}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Color(0xFF0284C7)),
                  tooltip: 'Editar pregunta',
                  onPressed: () => _showQuestionFormModal(question: q),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Eliminar pregunta',
                  onPressed: () => _confirmDelete(q),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title ES
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🇪🇸 ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        q.titleEs,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Title EN
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🇺🇸 ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        q.titleEn,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Image Preview
                if (q.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: Image.network(
                        q.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey.shade400),
                              const SizedBox(width: 8),
                              Text('URL no válida', style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                Text(
                  'Opciones y asignación de perfil (${q.options.length}):',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),

                // Options with profile pills
                ...q.options.map((opt) {
                  final profile = hueQuitoProfiles.firstWhere(
                    (p) => p.id == opt.profileId,
                    orElse: () => hueQuitoProfiles.first,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Text(opt.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.textEs,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (opt.textEn.isNotEmpty)
                                Text(
                                  opt.textEn,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.blueGrey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Profile assignment pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(profile.emoji, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                profile.titleEs.replaceFirst('El ', ''),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionFormModal extends StatefulWidget {
  final QuizQuestion? question;
  final int nextOrder;
  final Future<void> Function(QuizQuestion) onSave;

  const _QuestionFormModal({
    this.question,
    required this.nextOrder,
    required this.onSave,
  });

  @override
  State<_QuestionFormModal> createState() => _QuestionFormModalState();
}

class _QuestionFormModalState extends State<_QuestionFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _orderCtrl;
  late TextEditingController _titleEsCtrl;
  late TextEditingController _titleEnCtrl;
  late TextEditingController _imageUrlCtrl;
  late List<_OptionFormData> _options;

  File? _localImageFile;
  bool _isUploadingImage = false;

  // Preset food images for rapid testing
  final List<Map<String, String>> _presetImages = [
    {
      'label': 'Sopa / Caldo',
      'url': 'https://images.unsplash.com/photo-1547592180-85f173990554?w=800&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Carne / Hornado',
      'url': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Ají / Picante',
      'url': 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=800&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Mercado Popular',
      'url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Postre / Helado',
      'url': 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _orderCtrl = TextEditingController(text: '${q?.order ?? widget.nextOrder}');
    _titleEsCtrl = TextEditingController(text: q?.titleEs ?? '');
    _titleEnCtrl = TextEditingController(text: q?.titleEn ?? '');
    _imageUrlCtrl = TextEditingController(text: q?.imageUrl ?? '');

    if (q != null && q.options.isNotEmpty) {
      _options = q.options
          .map(
            (o) => _OptionFormData(
              id: o.id,
              textEs: TextEditingController(text: o.textEs),
              textEn: TextEditingController(text: o.textEn),
              emoji: TextEditingController(text: o.emoji),
              profileId: o.profileId,
            ),
          )
          .toList();
    } else {
      _options = [
        _OptionFormData(
          id: 'opt_1',
          textEs: TextEditingController(),
          textEn: TextEditingController(),
          emoji: TextEditingController(text: '🥣'),
          profileId: 'sopero',
        ),
        _OptionFormData(
          id: 'opt_2',
          textEs: TextEditingController(),
          textEn: TextEditingController(),
          emoji: TextEditingController(text: '🍖'),
          profileId: 'carnivoro',
        ),
        _OptionFormData(
          id: 'opt_3',
          textEs: TextEditingController(),
          textEn: TextEditingController(),
          emoji: TextEditingController(text: '🍔'),
          profileId: 'callejero',
        ),
        _OptionFormData(
          id: 'opt_4',
          textEs: TextEditingController(),
          textEn: TextEditingController(),
          emoji: TextEditingController(text: '🍰'),
          profileId: 'dulcero',
        ),
      ];
    }
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _titleEsCtrl.dispose();
    _titleEnCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (var o in _options) {
      o.textEs.dispose();
      o.textEn.dispose();
      o.emoji.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 6) return;
    setState(() {
      _options.add(
        _OptionFormData(
          id: 'opt_${DateTime.now().millisecondsSinceEpoch}',
          textEs: TextEditingController(),
          textEn: TextEditingController(),
          emoji: TextEditingController(text: '🍽️'),
          profileId: 'aventurero',
        ),
      );
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requieren al menos 2 opciones por pregunta')),
      );
      return;
    }
    setState(() {
      final removed = _options.removeAt(index);
      removed.textEs.dispose();
      removed.textEn.dispose();
      removed.emoji.dispose();
    });
  }

  Future<void> _pickImage() async {
    final file = await ImagePickerHelper.showImageSourceDialog(
      context: context,
      title: 'Foto de la Pregunta',
      subtitle: 'Toma una foto o selecciona una imagen de tu celular',
      includeRemove: _localImageFile != null || _imageUrlCtrl.text.isNotEmpty,
      onRemove: () {
        setState(() {
          _localImageFile = null;
          _imageUrlCtrl.clear();
        });
      },
      imageQuality: 80,
      maxWidth: 1280,
    );

    if (file != null) {
      setState(() {
        _localImageFile = file;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String finalImageUrl = _imageUrlCtrl.text.trim();

    if (_localImageFile != null) {
      setState(() => _isUploadingImage = true);
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('quiz_images/quiz_question_$timestamp.jpg');
        final uploadTask = await storageRef.putFile(_localImageFile!);
        finalImageUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir imagen a Firebase Storage: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isUploadingImage = false);
        return;
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }

    final questionToSave = QuizQuestion(
      id: widget.question?.id ?? '',
      order: int.tryParse(_orderCtrl.text.trim()) ?? 1,
      titleEs: _titleEsCtrl.text.trim(),
      titleEn: _titleEnCtrl.text.trim(),
      imageUrl: finalImageUrl,
      options: _options.map((o) {
        return QuizOption(
          id: o.id,
          textEs: o.textEs.text.trim(),
          textEn: o.textEn.text.trim(),
          profileId: o.profileId,
          emoji: o.emoji.text.trim().isEmpty ? '🍽️' : o.emoji.text.trim(),
        );
      }).toList(),
    );

    Navigator.pop(context);
    await widget.onSave(questionToSave);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle and top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.question == null ? 'Nueva Pregunta' : 'Editar Pregunta',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable Form
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order
                    TextFormField(
                      controller: _orderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Número de Orden / Posición',
                        prefixIcon: Icon(Icons.format_list_numbered),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ingresa el orden';
                        if (int.tryParse(val.trim()) == null) return 'Debe ser un número entero';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Title ES
                    TextFormField(
                      controller: _titleEsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título de la Pregunta (Español) *',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Ingresa la pregunta en español' : null,
                    ),
                    const SizedBox(height: 16),

                    // Title EN
                    TextFormField(
                      controller: _titleEnCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título de la Pregunta (Inglés)',
                        prefixIcon: Icon(Icons.translate),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Fotografía de la Pregunta (Subida desde celular o URL)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.photo_library, size: 20, color: Color(0xFF0F172A)),
                              SizedBox(width: 8),
                              Text(
                                'Fotografía de la Pregunta',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Puedes tomar una foto o elegirla desde la galería de tu celular, o usar un enlace URL.',
                            style: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade600),
                          ),
                          const SizedBox(height: 14),

                          // Botón para subir desde el celular
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingImage ? null : _pickImage,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.add_a_photo, size: 20, color: AppTheme.primary),
                              label: Text(
                                _localImageFile != null
                                    ? 'Cambiar foto del celular'
                                    : 'Subir foto desde el celular (Cámara / Galería)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                          ),

                          // Vista previa de la foto (Local o URL)
                          if (_localImageFile != null) ...[
                            const SizedBox(height: 12),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    height: 150,
                                    width: double.infinity,
                                    child: Image.file(
                                      _localImageFile!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'Foto local lista para subirse a la nube',
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
                                  child: IconButton(
                                    onPressed: () => setState(() => _localImageFile = null),
                                    icon: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_imageUrlCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    height: 130,
                                    width: double.infinity,
                                    child: Image.network(
                                      _imageUrlCtrl.text,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child: const Text('URL inválida o sin conexión'),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    onPressed: () => setState(() => _imageUrlCtrl.clear()),
                                    icon: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Alternativa por URL
                          TextFormField(
                            controller: _imageUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'O ingresa enlace URL de la foto',
                              prefixIcon: Icon(Icons.link),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) {
                              if (_localImageFile != null) {
                                setState(() => _localImageFile = null);
                              } else {
                                setState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 8),

                          // Preset images chips
                          const Text(
                            'O escoge una foto sugerida:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _presetImages.map((preset) {
                              return ActionChip(
                                avatar: const Icon(Icons.photo_size_select_actual, size: 14),
                                label: Text(preset['label']!, style: const TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() {
                                    _localImageFile = null;
                                    _imageUrlCtrl.text = preset['url']!;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Options Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Opciones de Respuesta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_options.length < 6)
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Añadir Opción'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Options list
                    ..._options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final opt = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Emoji input
                                SizedBox(
                                  width: 65,
                                  child: TextFormField(
                                    controller: opt.emoji,
                                    decoration: const InputDecoration(
                                      labelText: 'Emoji',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Text ES
                                Expanded(
                                  child: TextFormField(
                                    controller: opt.textEs,
                                    decoration: const InputDecoration(
                                      labelText: 'Texto Opción (ES) *',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty
                                        ? 'Requerido'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (_options.length > 2)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    onPressed: () => _removeOption(idx),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Text EN
                            TextFormField(
                              controller: opt.textEn,
                              decoration: const InputDecoration(
                                labelText: 'Texto Opción (EN)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Profile Assignment Dropdown
                            Row(
                              children: [
                                const Text(
                                  'Asignar al Perfil:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: opt.profileId,
                                        isExpanded: true,
                                        onChanged: (newVal) {
                                          if (newVal != null) {
                                            setState(() {
                                              opt.profileId = newVal;
                                            });
                                          }
                                        },
                                        items: hueQuitoProfiles.map((p) {
                                          return DropdownMenuItem<String>(
                                            value: p.id,
                                            child: Row(
                                              children: [
                                                Text(p.emoji, style: const TextStyle(fontSize: 16)),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${p.titleEs} (${p.id})',
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingImage ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isUploadingImage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                              )
                            : const Icon(Icons.check, color: Colors.amber),
                        label: Text(
                          _isUploadingImage ? 'Subiendo foto a la nube...' : 'Guardar Pregunta',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionFormData {
  final String id;
  final TextEditingController textEs;
  final TextEditingController textEn;
  final TextEditingController emoji;
  String profileId;

  _OptionFormData({
    required this.id,
    required this.textEs,
    required this.textEn,
    required this.emoji,
    required this.profileId,
  });
}
