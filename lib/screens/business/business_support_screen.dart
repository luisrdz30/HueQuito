import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/support_repository.dart';

class BusinessSupportScreen extends ConsumerStatefulWidget {
  const BusinessSupportScreen({super.key});

  @override
  ConsumerState<BusinessSupportScreen> createState() => _BusinessSupportScreenState();
}

class _BusinessSupportScreenState extends ConsumerState<BusinessSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _selectedSubject = 'Consulta General';
  bool _isSending = false;

  final List<String> _subjects = [
    'Consulta General',
    'Problema Técnico en la App',
    'Actualización de Menú o Precios',
    'Dudas sobre Cromos y Pasaporte QR',
    'Solicitud de Nueva Sucursal',
    'Otro Asunto',
  ];

  @override
  void dispose() {
    _messageController.dispose();
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

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).value;
    final hueca = ref.read(myHuecaProvider).value;
    final branch = ref.read(currentManagedBranchProvider).value;

    if (user == null || hueca == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró la información de tu negocio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref.read(supportRepositoryProvider).submitMessage(
            huecaId: hueca.id,
            huecaName: hueca.name,
            branchId: branch?.id,
            branchName: branch?.name,
            senderUid: user.uid,
            senderName: user.name,
            senderEmail: user.email,
            subject: _selectedSubject,
            message: _messageController.text.trim(),
          );

      ref.invalidate(myHuecaSupportMessagesProvider(hueca.id));
      ref.invalidate(newSupportMessagesProvider);
      ref.invalidate(allSupportMessagesProvider);

      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Mensaje enviado al Superadmin! Te responderemos pronto.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hueca = ref.watch(myHuecaProvider).value;
    final branch = ref.watch(currentManagedBranchProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final huecaId = hueca?.id ?? '';

    final messagesAsync = ref.watch(myHuecaSupportMessagesProvider(huecaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactar al Superadmin', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner explicativo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                    ),
                    child: const Icon(Icons.support_agent, color: Color(0xFFFBBF24), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mesa de Ayuda Directa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hueca != null
                              ? 'Negocio: ${hueca.name}${branch != null ? " (${branch.name})" : ""}'
                              : 'Envía un mensaje o consulta a la administración.',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Formulario para redactar mensaje
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_note, color: AppTheme.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Nuevo Mensaje',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Asunto o Motivo *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.primary, size: 20),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedSubject = v);
                      },
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Mensaje o Consulta *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe tu inquietud, consulta o problema con el mayor detalle posible...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? 'Por favor escribe un mensaje más detallado'
                          : null,
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, size: 18),
                        label: Text(
                          _isSending ? 'Enviando mensaje...' : 'Enviar al Administrador',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Historial de mensajes enviados
            const Row(
              children: [
                Icon(Icons.history, color: Colors.blueGrey, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Historial de Mensajes Enviados',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            messagesAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, s) => Text('Error al cargar historial: $e'),
              data: (list) {
                if (list.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          'No has enviado mensajes todavía.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: list.map((msg) => _buildMessageCard(msg, isDark)).toList(),
                );
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(SupportMessage msg, bool isDark) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (msg.status) {
      case 'responded':
        statusColor = Colors.green;
        statusLabel = 'Respondido';
        statusIcon = Icons.mark_chat_read;
        break;
      case 'read':
        statusColor = Colors.blue;
        statusLabel = 'Leído';
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pendiente';
        statusIcon = Icons.schedule;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: msg.status == 'responded' ? Colors.green.shade300 : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  msg.subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(msg.createdAt),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            msg.message,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
          ),

          // Respuesta del Administrador
          if (msg.adminResponse != null && msg.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user, size: 16, color: Colors.green.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'Respuesta del Superadmin:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.green.shade900,
                        ),
                      ),
                      if (msg.respondedAt != null) ...[
                        const Spacer(),
                        Text(
                          _formatDate(msg.respondedAt!),
                          style: TextStyle(fontSize: 10, color: Colors.green.shade700),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    msg.adminResponse!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF14532D)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
