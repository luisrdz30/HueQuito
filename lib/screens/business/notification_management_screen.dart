import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/models/notification_model.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/services/ai_generation_service.dart';

class BusinessNotificationScreen extends ConsumerStatefulWidget {
  const BusinessNotificationScreen({super.key});

  @override
  ConsumerState<BusinessNotificationScreen> createState() => _BusinessNotificationScreenState();
}

class _BusinessNotificationScreenState extends ConsumerState<BusinessNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _tagController = TextEditingController();

  String _selectedCategory = 'promocion';
  String? _selectedBranchId; // null means 'Todas'
  bool _isSubmitting = false;

  // Fecha y hora programada
  bool _isScheduled = false;
  DateTime? _scheduledDateTime;

  final List<Map<String, String>> _categories = [
    {'id': 'promocion', 'label': 'Promoción', 'emoji': '🏷️', 'desc': 'Descuentos, 2x1 y combos'},
    {'id': 'noticia', 'label': 'Noticia', 'emoji': '📢', 'desc': 'Novedades y avisos'},
    {'id': 'nuevo_plato', 'label': 'Nuevo Plato', 'emoji': '🍲', 'desc': 'Lanzamiento de platillos'},
    {'id': 'evento', 'label': 'Evento', 'emoji': '📅', 'desc': 'Música o fechas especiales'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final initialDate = _scheduledDateTime ?? now.add(const Duration(hours: 2));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? initialDate : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'SELECCIONA EL DÍA DE PUBLICACIÓN',
      confirmText: 'SIGUIENTE: HORA',
      cancelText: 'CANCELAR',
    );

    if (pickedDate == null || !mounted) return;

    final initialTime = _scheduledDateTime != null
        ? TimeOfDay.fromDateTime(_scheduledDateTime!)
        : TimeOfDay(hour: (now.hour + 2) % 24, minute: 0);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'SELECCIONA LA HORA DE PUBLICACIÓN',
      confirmText: 'ESTABLECER',
      cancelText: 'CANCELAR',
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ La fecha y hora programada debe ser en el futuro.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _scheduledDateTime = combined;
      _isScheduled = true;
    });
  }

  void _openAiAssistant(Hueca hueca, HuecaBranch? managedBranch) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Escribe primero el título de tu promo o anuncio para que la IA sepa qué redactar.'),
          backgroundColor: AppTheme.primary,
        ),
      );
      return;
    }

    final branchName = managedBranch?.name ??
        (_selectedBranchId != null
            ? hueca.branches
                .firstWhere(
                  (b) => b.id == _selectedBranchId,
                  orElse: () => hueca.branches.first,
                )
                .name
            : null);

    final options = AiGenerationService.generateCopyOptions(
      title: title,
      huecaName: hueca.name,
      category: _selectedCategory,
      discountTag: _tagController.text.trim().isNotEmpty ? _tagController.text.trim() : null,
      branchName: branchName,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Asistente Generativo IA',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              'Elige la mejor descripción para "$title"',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Toca la opción que más te guste para usarla en tu anuncio:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  ...options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final text = entry.value;
                    final labels = ['🎯 Antojo & Sabor', '👥 Plan Amigos & Familia', '⚡ Oferta & Urgencia'];
                    final label = idx < labels.length ? labels[idx] : '✨ Opción ${idx + 1}';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            _messageController.text = text;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✨ ¡Descripción generada con IA aplicada!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primary),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                text,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Generar más opciones'),
                      onPressed: () {
                        setModalState(() {
                          options.shuffle();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitRequest(Hueca hueca, HuecaBranch? managedBranch) async {
    if (!_formKey.currentState!.validate()) return;

    if (_isScheduled && _scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Por favor selecciona la fecha y hora programada o elige envío inmediato.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(notificationRepositoryProvider);

      String? branchId = _selectedBranchId;
      String? branchName;

      if (managedBranch != null) {
        branchId = managedBranch.id;
        branchName = managedBranch.name;
      } else if (branchId != null && branchId.isNotEmpty) {
        final b = hueca.branches.firstWhere(
          (item) => item.id == branchId,
          orElse: () => hueca.branches.first,
        );
        branchName = b.name;
      }

      await repo.submitNotificationRequest(
        huecaId: hueca.id,
        huecaName: hueca.name,
        branchId: branchId,
        branchName: branchName,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        discountTag: _tagController.text.trim().isNotEmpty ? _tagController.text.trim() : null,
        scheduledFor: _isScheduled ? _scheduledDateTime : null,
        createdBy: user.uid,
      );

      if (mounted) {
        _titleController.clear();
        _messageController.clear();
        _tagController.clear();
        setState(() {
          _isSubmitting = false;
          _selectedBranchId = null;
          _isScheduled = false;
          _scheduledDateTime = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solicitud enviada al administrador para autorización! 🚀'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Switch to history tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar la solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final huecaAsync = ref.watch(myHuecaProvider);
    final managedBranchAsync = ref.watch(currentManagedBranchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign, color: Colors.white, size: 26),
            SizedBox(width: 10),
            Text('Notificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Solicitar Notificación', icon: Icon(Icons.add_alert, size: 20)),
            Tab(text: 'Historial y Estados', icon: Icon(Icons.history, size: 20)),
          ],
        ),
      ),
      body: huecaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (hueca) {
          if (hueca == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No tienes una Hueca asignada a esta cuenta para enviar notificaciones.'),
              ),
            );
          }

          final managedBranch = managedBranchAsync.value;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildRequestForm(hueca, managedBranch, isDark),
              _buildHistoryList(hueca.id, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestForm(Hueca hueca, HuecaBranch? managedBranch, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tus notificaciones llegarán directo a la barra de Android de los usuarios suscritos a ${hueca.name} tras ser aprobadas por el administrador.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tarjeta de Advertencia de Tiempos de Aprobación
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiempo de Aprobación: 2 horas a 1 día',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Cada notificación es revisada y autorizada por la administración antes de salir. Te recomendamos solicitar tus promociones y eventos con tiempo de anticipación.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Categoría
            const Text(
              'Categoría del Anuncio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  label: Text('${cat['emoji']} ${cat['label']}'),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat['id']!);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Sucursal (si aplica y no es branch manager bloqueado)
            if (managedBranch != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aplica para: ${managedBranch.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else if (hueca.branches.isNotEmpty) ...[
              const Text(
                'Sucursal Destino',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _selectedBranchId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('📍 Todas las sucursales'),
                  ),
                  ...hueca.branches.map((b) => DropdownMenuItem<String?>(
                        value: b.id,
                        child: Text('📍 ${b.name} (${b.sector})'),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
              const SizedBox(height: 18),
            ],

            // Título
            const Text(
              'Título de la Notificación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: 'Ej. ¡2x1 en Seco de Chivo este Viernes!',
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: '',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Por favor escribe un título';
                if (v.trim().length < 5) return 'El título debe tener al menos 5 caracteres';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Mensaje / Detalles con botón generativo de IA
            Row(
              children: [
                const Text(
                  'Mensaje / Detalles *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _openAiAssistant(hueca, managedBranch),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.15),
                          Colors.deepPurpleAccent.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
                        SizedBox(width: 5),
                        Text(
                          'Ayuda con IA ✨',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 160,
              decoration: InputDecoration(
                hintText: 'Ej. Ven a disfrutar con un amigo desde las 12h00 hasta agotar stock. Válido en locales físicos.',
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Por favor escribe el mensaje';
                if (v.trim().length < 10) return 'El mensaje debe ser más descriptivo';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Etiqueta Opcional
            const Text(
              'Etiqueta / Descuento (Opcional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tagController,
              maxLength: 25,
              decoration: InputDecoration(
                hintText: 'Ej. 2x1, 20% OFF, Novedad, Solo Hoy',
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // ¿Cuándo quieres que salga la notificación? (Programación)
            const Text(
              '¿Cuándo quieres que salga la notificación?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flash_on, size: 16),
                        SizedBox(width: 6),
                        Text('Inmediata'),
                      ],
                    ),
                    selected: !_isScheduled,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: !_isScheduled ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: !_isScheduled ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isScheduled = false;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month, size: 16),
                        SizedBox(width: 6),
                        Text('Programada'),
                      ],
                    ),
                    selected: _isScheduled,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: _isScheduled ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: _isScheduled ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isScheduled = true;
                        });
                        if (_scheduledDateTime == null) {
                          _pickScheduleDateTime();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_isScheduled) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fecha y hora de salida:',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            _scheduledDateTime != null
                                ? '${_scheduledDateTime!.day.toString().padLeft(2, '0')}/${_scheduledDateTime!.month.toString().padLeft(2, '0')}/${_scheduledDateTime!.year} a las ${_scheduledDateTime!.hour.toString().padLeft(2, '0')}:${_scheduledDateTime!.minute.toString().padLeft(2, '0')}'
                                : 'No seleccionada aún (Toca elegir)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_calendar, size: 16),
                      label: Text(_scheduledDateTime == null ? 'Elegir' : 'Cambiar'),
                      onPressed: _pickScheduleDateTime,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Vista Previa de Notificación Nativa
            const Text(
              'Vista Previa en el Celular',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            _buildNotificationPreview(hueca.name, isDark),
            const SizedBox(height: 28),

            // Botón de Envío
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSubmitting ? 'Enviando Solicitud...' : 'Solicitar Autorización de Notificación',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : () => _submitRequest(hueca, managedBranch),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPreview(String huecaName, bool isDark) {
    final emoji = _categories.firstWhere((c) => c['id'] == _selectedCategory)['emoji'] ?? '📢';
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Título de tu anuncio aquí';
    final message = _messageController.text.trim().isNotEmpty
        ? _messageController.text.trim()
        : 'Aquí aparecerá la descripción de la promoción o noticia que verán tus clientes.';
    final tag = _tagController.text.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'Hue-Quito • ahora',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const Spacer(),
              if (tag.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$emoji $huecaName: $title',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(String huecaId, bool isDark) {
    final listAsync = ref.watch(myHuecaNotificationsProvider(huecaId));

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar historial: $e')),
      data: (notifications) {
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Aún no has solicitado notificaciones.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Crear Primera Notificación'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = notifications[index];
            return _buildHistoryCard(item, isDark);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(NotificationModel item, bool isDark) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (item.status) {
      case 'approved':
        if (item.isScheduled) {
          statusColor = Colors.teal;
          statusText = 'Aprobada (Programada)';
          statusIcon = Icons.schedule;
        } else {
          statusColor = Colors.green;
          statusText = 'Aprobada y Emitida';
          statusIcon = Icons.check_circle;
        }
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rechazada';
        statusIcon = Icons.cancel;
        break;
      case 'pending':
      default:
        statusColor = Colors.amber.shade800;
        statusText = 'Pendiente de Aprobación';
        statusIcon = Icons.hourglass_top;
        break;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (item.formattedScheduledDate != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 13, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Programada para: ${item.formattedScheduledDate}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(item.categoryEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.message,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (item.branchName != null) ...[
              const SizedBox(height: 8),
              Text(
                '📍 Sucursal: ${item.branchName}',
                style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
              ),
            ],
            if (item.status == 'rejected' && item.rejectionReason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motivo del administrador: ${item.rejectionReason}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
