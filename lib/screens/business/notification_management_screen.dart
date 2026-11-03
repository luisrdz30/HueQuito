import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/models/notification_model.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/notification_repository.dart';
import 'package:hue_quito/repositories/subscription_repository.dart';
import 'package:hue_quito/services/ai_generation_service.dart';
import 'package:hue_quito/widgets/brand_logo.dart';

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
  final _sopaController = TextEditingController();
  final _segundoController = TextEditingController();

  String _selectedCategory = 'menu_del_dia';
  String? _selectedBranchId; // null means 'Todas'
  bool _isSubmitting = false;

  // Fecha y hora programada
  bool _isScheduled = false;
  DateTime? _scheduledDateTime;
  String _historyTimeFilter = 'recent'; // 'recent', 'month', 'older', 'all'

  final List<Map<String, String>> _categories = [
    {'id': 'menu_del_dia', 'label': 'Menú del Día', 'emoji': '🍛', 'desc': 'Avisa a tus clientes qué hay hoy de almuerzo'},
    {'id': 'promocion', 'label': 'Promoción', 'emoji': '🏷️', 'desc': 'Descuentos, 2x1 y combos'},
    {'id': 'noticia', 'label': 'Noticia', 'emoji': '📢', 'desc': 'Horarios, cierres o novedades'},
    {'id': 'nuevo_plato', 'label': 'Nuevo Plato', 'emoji': '🍲', 'desc': 'Un plato que estrenas'},
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
    _sopaController.dispose();
    _segundoController.dispose();
    super.dispose();
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


  // ---------------------------------------------------------------------------
  // Fecha y hora de un aviso programado
  // ---------------------------------------------------------------------------

  static const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Ej.: "jue 05/11"
  String _formatDay(DateTime d) => '${_weekdays[d.weekday - 1]} ${_two(d.day)}/${_two(d.month)}';

  String _formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  bool get _isMenu => _selectedCategory == 'menu_del_dia';

  /// Momento en que saldría el aviso (null = ahora)
  DateTime? get _publishAt => _isScheduled ? _scheduledDateTime : null;

  Future<void> _pickScheduleDay() async {
    final now = DateTime.now();
    final current = _scheduledDateTime ?? now.add(const Duration(hours: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      helpText: '¿QUÉ DÍA SALE EL AVISO?',
      confirmText: 'LISTO',
      cancelText: 'CANCELAR',
    );
    if (picked == null || !mounted) return;
    final time = _scheduledDateTime ?? DateTime(now.year, now.month, now.day, _isMenu ? 11 : now.hour + 1, _isMenu ? 30 : 0);
    _setSchedule(DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
  }

  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final base = _scheduledDateTime ?? now;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: '¿A QUÉ HORA SALE?',
      confirmText: 'LISTO',
      cancelText: 'CANCELAR',
    );
    if (picked == null || !mounted) return;
    var moment = DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
    // Sin día elegido: si esa hora ya pasó hoy, se entiende que es para mañana
    if (_scheduledDateTime == null && moment.isBefore(now)) moment = moment.add(const Duration(days: 1));
    _setSchedule(moment);
  }

  void _setSchedule(DateTime moment) {
    if (moment.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esa hora ya pasó. Elige una hora más adelante.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _scheduledDateTime = moment);
  }

  // ---------------------------------------------------------------------------
  // Envío
  // ---------------------------------------------------------------------------

  /// Título y mensaje finales (el menú del día se arma con la sopa y el segundo)
  (String, String) _composeNotice(Hueca hueca) {
    if (!_isMenu) return (_titleController.text.trim(), _messageController.text.trim());
    final sopa = _sopaController.text.trim();
    final segundo = _segundoController.text.trim();
    final buf = StringBuffer();
    if (sopa.isNotEmpty) buf.writeln('🍲 Sopa: $sopa');
    if (segundo.isNotEmpty) buf.writeln('🍛 Segundo: $segundo');
    buf.write('¡Almuerzo listo y calientito! Te esperamos.');
    return ('Menú del Día de ${hueca.name}', buf.toString().trim());
  }

  Future<void> _submitRequest(Hueca hueca, HuecaBranch? managedBranch) async {
    if (!_formKey.currentState!.validate()) return;

    if (_isScheduled && _scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige el día y la hora en que debe salir el aviso.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      String? branchId = _selectedBranchId;
      String? branchName;
      if (managedBranch != null) {
        branchId = managedBranch.id;
        branchName = managedBranch.name;
      } else if (branchId != null && hueca.branches.isNotEmpty) {
        branchName = hueca.branches.firstWhere((b) => b.id == branchId, orElse: () => hueca.branches.first).name;
      }

      final (title, message) = _composeNotice(hueca);
      final publishAt = _publishAt;
      await ref.read(notificationRepositoryProvider).submitNotificationRequest(
            huecaId: hueca.id,
            huecaName: hueca.name,
            branchId: branchId,
            branchName: branchName,
            category: _selectedCategory,
            title: title,
            message: message,
            discountTag: _tagController.text.trim().isNotEmpty ? _tagController.text.trim() : null,
            scheduledFor: publishAt,
            createdBy: user.uid,
          );

      if (!mounted) return;
      _titleController.clear();
      _messageController.clear();
      _tagController.clear();
      _sopaController.clear();
      _segundoController.clear();
      setState(() {
        _isSubmitting = false;
        _selectedBranchId = null;
        _isScheduled = false;
        _scheduledDateTime = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publishAt == null
              ? '¡Aviso publicado! Les llegará a los comensales que siguen tu hueca. 🚀'
              : '⏰ Aviso programado para el ${_formatDay(publishAt)} a las ${_formatTime(publishAt)}.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is DailyNoticeLimitException ? '$e' : 'Error al publicar el aviso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Formulario por pasos
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration(bool isDark, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _stepHeader(int number, String title, bool isDark, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (hint != null)
                  Text(hint, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : AppTheme.textMedium)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEDE7E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  /// Avisos que quedan hoy, con un punto por aviso
  Widget _buildQuotaCard(Map<String, int> used, bool isDark) {
    final max = NotificationRepository.maxNoticesPerDay;
    final left = NotificationRepository.remainingFor(used, null);
    final full = left == 0;
    final color = full ? Colors.red.shade600 : Colors.green.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(full ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  full ? 'Ya usaste tus avisos de hoy' : 'Te quedan $left de $max avisos hoy',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  full
                      ? 'Puedes programar uno para otro día.'
                      : 'Llegan al celular de quienes siguen tu hueca. Los programados cuentan para el día en que salen.',
                  style: TextStyle(fontSize: 12, height: 1.3, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(
              max,
              (i) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(i < left ? Icons.circle : Icons.circle_outlined, size: 14, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, String> cat, bool isDark, double width) {
    final selected = _selectedCategory == cat['id'];
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedCategory = cat['id']!),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withValues(alpha: 0.12) : (isDark ? Colors.grey[850] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppTheme.primary : (isDark ? Colors.white12 : Colors.grey.shade300), width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Text(cat['emoji']!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat['label']!,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: selected ? AppTheme.primary : null),
                    ),
                    Text(cat['desc']!, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : AppTheme.textMedium)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm(Hueca hueca, HuecaBranch? managedBranch, bool isDark) {
    final used = ref.watch(usedNoticesByDayProvider(hueca.id)).value ?? const <String, int>{};
    final publishAt = _publishAt;
    final leftThatDay = NotificationRepository.remainingFor(used, publishAt);
    final missingDate = _isScheduled && _scheduledDateTime == null;
    final dayFull = leftThatDay == 0;

    String buttonLabel;
    if (_isSubmitting) {
      buttonLabel = 'Publicando...';
    } else if (publishAt != null) {
      buttonLabel = 'Programar para el ${_formatDay(publishAt)} a las ${_formatTime(publishAt)}';
    } else if (_isScheduled) {
      buttonLabel = 'Elige el día y la hora';
    } else {
      buttonLabel = 'Publicar ahora';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuotaCard(used, isDark),

            // 1. Tipo de aviso
            _section(isDark, [
              _stepHeader(1, '¿Qué quieres avisar?', isDark),
              LayoutBuilder(builder: (context, c) {
                final half = (c.maxWidth - 10) / 2;
                final menu = _categories.first;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCategoryCard(menu, isDark, c.maxWidth),
                    ..._categories.skip(1).map((cat) => _buildCategoryCard(cat, isDark, c.maxWidth < 360 ? c.maxWidth : half)),
                  ],
                );
              }),
            ]),

            // 2. Contenido
            _section(isDark, [
              _stepHeader(2, 'Escribe tu aviso', isDark,
                  hint: _isMenu ? 'Con la sopa y el segundo armamos el aviso por ti.' : null),
              if (_isMenu) ...[
                TextFormField(
                  controller: _sopaController,
                  decoration: _inputDecoration(isDark, 'Ej. Locro de papa').copyWith(labelText: '🍲 Sopa'),
                  validator: (_) => _sopaController.text.trim().isEmpty && _segundoController.text.trim().isEmpty
                      ? 'Escribe al menos la sopa o el segundo'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _segundoController,
                  decoration: _inputDecoration(isDark, 'Ej. Seco de pollo con arroz').copyWith(labelText: '🍛 Segundo'),
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                TextFormField(
                  controller: _titleController,
                  maxLength: 60,
                  decoration: _inputDecoration(isDark, 'Ej. ¡2x1 en seco de chivo este viernes!').copyWith(labelText: 'Título'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Escribe un título';
                    if (v.trim().length < 5) return 'El título debe tener al menos 5 caracteres';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  maxLength: 160,
                  decoration: _inputDecoration(isDark, 'Ej. Ven con un amigo desde las 12h00 hasta agotar stock.')
                      .copyWith(labelText: 'Mensaje', alignLabelWithHint: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Escribe el mensaje';
                    if (v.trim().length < 10) return 'El mensaje debe ser un poco más largo';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _openAiAssistant(hueca, managedBranch),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Ayuda con IA ✨'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  title: Text(
                    'Más opciones',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppTheme.textMedium),
                  ),
                  subtitle: Text(
                    managedBranch != null ? 'Etiqueta · ${managedBranch.name}' : 'Etiqueta y sucursal',
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    TextFormField(
                      controller: _tagController,
                      maxLength: 25,
                      decoration: _inputDecoration(isDark, 'Ej. 2x1, 20% OFF, Solo hoy')
                          .copyWith(labelText: 'Etiqueta (opcional)', counterText: ''),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (managedBranch != null)
                      Row(
                        children: [
                          const Icon(Icons.store, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Aplica para: ${managedBranch.name}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      )
                    else if (hueca.branches.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedBranchId,
                        decoration: _inputDecoration(isDark, '').copyWith(labelText: 'Sucursal'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('📍 Todas las sucursales')),
                          ...hueca.branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text('📍 ${b.name} (${b.sector})'))),
                        ],
                        onChanged: (val) => setState(() => _selectedBranchId = val),
                      ),
                  ],
                ),
              ),
            ]),

            // 3. Cuándo
            _section(isDark, [
              _stepHeader(3, '¿Cuándo sale?', isDark),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.flash_on, size: 18), label: Text('Ahora')),
                    ButtonSegment(value: true, icon: Icon(Icons.schedule, size: 18), label: Text('Programar')),
                  ],
                  selected: {_isScheduled},
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppTheme.primary,
                    selectedForegroundColor: Colors.white,
                  ),
                  onSelectionChanged: (s) => setState(() => _isScheduled = s.first),
                ),
              ),
              if (_isScheduled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _scheduleTile(
                        isDark,
                        icon: Icons.calendar_today,
                        label: 'Día',
                        value: _scheduledDateTime != null ? _formatDay(_scheduledDateTime!) : 'Elegir',
                        onTap: _pickScheduleDay,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _scheduleTile(
                        isDark,
                        icon: Icons.access_time,
                        label: 'Hora',
                        value: _scheduledDateTime != null ? _formatTime(_scheduledDateTime!) : 'Elegir',
                        onTap: _pickScheduleTime,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              if (!missingDate)
                Row(
                  children: [
                    Icon(dayFull ? Icons.block : Icons.check_circle_outline,
                        size: 16, color: dayFull ? Colors.red.shade600 : Colors.green.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dayFull
                            ? (publishAt == null
                                ? 'Hoy ya no te quedan avisos. Prográmalo para otro día.'
                                : 'Ese día ya tiene ${NotificationRepository.maxNoticesPerDay} avisos. Elige otro día.')
                            : (publishAt == null
                                ? 'Sale en cuanto lo publiques.'
                                : 'Ese día te quedan $leftThatDay de ${NotificationRepository.maxNoticesPerDay} avisos.'),
                        style: TextStyle(fontSize: 12.5, color: dayFull ? Colors.red.shade600 : (isDark ? Colors.white70 : AppTheme.textMedium)),
                      ),
                    ),
                  ],
                ),
            ]),

            // 4. Vista previa
            _section(isDark, [
              _stepHeader(4, 'Así lo verán tus clientes', isDark),
              _buildNotificationPreview(hueca.name, isDark),
            ]),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isScheduled ? Icons.schedule_send : Icons.send),
                label: Text(buttonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting || missingDate || dayFull ? null : () => _submitRequest(hueca, managedBranch),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _scheduleTile(bool isDark,
      {required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final huecaAsync = ref.watch(myHuecaProvider);
    final managedBranchAsync = ref.watch(currentManagedBranchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HueQuitoLogo.symbol(height: 26),
            const SizedBox(width: 10),
            const Text(
              'Avisos',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Nuevo aviso', icon: Icon(Icons.add_alert, size: 20)),
            Tab(text: 'Mis avisos', icon: Icon(Icons.history, size: 20)),
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

          // Suscripción vencida sin pago: no puede enviar avisos (la hueca sigue visible en la app)
          final subSettings = ref.watch(subscriptionSettingsProvider).value ?? const SubscriptionSettings();
          final subInfo = ref.watch(subscriptionRepositoryProvider).evaluateHuecaSubscription(hueca: hueca, settings: subSettings);
          if (subInfo.isLocked) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 64, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Avisos pausados',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El periodo de gracia terminó. Tu hueca sigue visible para los comensales, pero no puedes enviar avisos hasta subir tu comprobante de pago desde el Panel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : AppTheme.textMedium),
                    ),
                  ],
                ),
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

  Widget _buildNotificationPreview(String huecaName, bool isDark) {
    final cat = _categories.firstWhere(
      (c) => c['id'] == _selectedCategory,
      orElse: () => _categories.first,
    );
    final emoji = cat['emoji'] ?? '📢';
    // Igual que el push real: título (con el nombre de la hueca) y mensaje
    final hueca = ref.read(myHuecaProvider).value;
    final (rawTitle, rawMessage) =
        hueca != null ? _composeNotice(hueca) : (_titleController.text.trim(), _messageController.text.trim());
    final title = rawTitle.isNotEmpty ? rawTitle : 'Título de tu aviso';
    final hasMenu = _sopaController.text.trim().isNotEmpty || _segundoController.text.trim().isNotEmpty;
    final message = (_isMenu ? hasMenu : rawMessage.isNotEmpty) ? rawMessage : 'Aquí aparecerá el mensaje que verán tus clientes.';
    final tag = _tagController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1410) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : AppTheme.chulpiCream,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de simulación Android Heads-up
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFFBF8F4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, size: 12, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'VISTA PREVIA EN DISPOSITIVO',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white54 : AppTheme.textMedium,
                  ),
                ),
                const Spacer(),
                const Text(
                  'ahora',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
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
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : AppTheme.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (tag.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3A82C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: const Color(0xFFE3A82C), width: 1),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title.contains(huecaName) ? '$emoji $title' : '$emoji $huecaName: $title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
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
                  'Aún no has publicado avisos.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Crear mi primer aviso'),
                ),
              ],
            ),
          );
        }

        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));

        final recentCount = notifications.where((i) {
          final d = i.approvedAt ?? i.createdAt;
          return !d.isBefore(sevenDaysAgo);
        }).length;

        final monthCount = notifications.where((i) {
          final d = i.approvedAt ?? i.createdAt;
          return !d.isBefore(thirtyDaysAgo);
        }).length;

        final olderCount = notifications.where((i) {
          final d = i.approvedAt ?? i.createdAt;
          return d.isBefore(thirtyDaysAgo);
        }).length;

        final filteredItems = notifications.where((item) {
          final d = item.approvedAt ?? item.createdAt;
          if (_historyTimeFilter == 'recent') {
            return !d.isBefore(sevenDaysAgo);
          } else if (_historyTimeFilter == 'month') {
            return !d.isBefore(thirtyDaysAgo);
          } else if (_historyTimeFilter == 'older') {
            return d.isBefore(thirtyDaysAgo);
          }
          return true; // 'all'
        }).toList();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildHistoryFilterChip(
                      label: '⚡ Esta Semana ($recentCount)',
                      isSelected: _historyTimeFilter == 'recent',
                      onTap: () => setState(() => _historyTimeFilter = 'recent'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildHistoryFilterChip(
                      label: '📅 Este Mes ($monthCount)',
                      isSelected: _historyTimeFilter == 'month',
                      onTap: () => setState(() => _historyTimeFilter = 'month'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildHistoryFilterChip(
                      label: '📜 Anteriores ($olderCount)',
                      isSelected: _historyTimeFilter == 'older',
                      onTap: () => setState(() => _historyTimeFilter = 'older'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildHistoryFilterChip(
                      label: '🌐 Todas (${notifications.length})',
                      isSelected: _historyTimeFilter == 'all',
                      onTap: () => setState(() => _historyTimeFilter = 'all'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No hay notificaciones en este período',
                            style: TextStyle(
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => setState(() => _historyTimeFilter = 'all'),
                            child: Text('Ver todas las notificaciones (${notifications.length})'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildHistoryCard(item, isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? Colors.grey.shade700 : const Color(0xFFE5E7EB)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
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
          statusText = 'Programado';
          statusIcon = Icons.schedule;
        } else {
          statusColor = Colors.green;
          statusText = 'Publicado';
          statusIcon = Icons.check_circle;
        }
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'No publicado';
        statusIcon = Icons.cancel;
        break;
      case 'system':
        statusColor = Colors.blue;
        statusText = 'Aviso de Hue-Quito';
        statusIcon = Icons.info_outline;
        break;
      case 'pending':
      default:
        statusColor = Colors.amber.shade800;
        statusText = 'Publicando...';
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
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _titleController.text = item.title;
                    _messageController.text = item.message;
                    _tagController.text = item.discountTag ?? '';
                    if (_categories.any((c) => c['id'] == item.category)) {
                      _selectedCategory = item.category;
                    }
                    // El menú del día se vuelve a separar en sopa y segundo
                    for (final line in item.message.split('\n')) {
                      if (line.startsWith('🍲 Sopa: ')) _sopaController.text = line.substring('🍲 Sopa: '.length);
                      if (line.startsWith('🍛 Segundo: ')) _segundoController.text = line.substring('🍛 Segundo: '.length);
                    }
                    _isScheduled = false;
                    _scheduledDateTime = null;
                  });
                  _tabController.animateTo(0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✨ ¡Datos cargados en el formulario para editar o reenviar!'),
                      backgroundColor: AppTheme.primary,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.replay_rounded, size: 16, color: AppTheme.primary),
                label: const Text(
                  'Usar como plantilla',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
