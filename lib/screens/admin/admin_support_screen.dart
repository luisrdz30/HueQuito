import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/support_repository.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

  Future<void> _respondToMessage(SupportMessage msg) async {
    final responseController = TextEditingController(text: msg.adminResponse ?? '');
    final formKey = GlobalKey<FormState>();
    bool isProcessing = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.reply, color: Color(0xFF0F172A), size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Responder Mensaje',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'La hueca verá tu respuesta en su pantalla de soporte',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 16, color: Color(0xFF0F172A)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    msg.huecaName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Asunto: ${msg.subject}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blueGrey)),
                            Text('De: ${msg.senderName} (${msg.senderEmail})', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                            const SizedBox(height: 6),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            Text(
                              msg.message,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('Tu Respuesta Oficial *:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: responseController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Escribe aquí la solución, respuesta o indicaciones para la hueca...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la respuesta para el negocio' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, size: 16),
                label: Text(isProcessing ? 'Enviando...' : 'Enviar Respuesta'),
                onPressed: isProcessing
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isProcessing = true);
                        try {
                          final currentUser = ref.read(currentUserProvider).value;
                          final adminUid = currentUser?.uid ?? 'admin';

                          await ref.read(supportRepositoryProvider).respondToMessage(
                                messageId: msg.id,
                                adminUid: adminUid,
                                response: responseController.text.trim(),
                              );

                          ref.invalidate(allSupportMessagesProvider);
                          ref.invalidate(newSupportMessagesProvider);
                          ref.invalidate(myHuecaSupportMessagesProvider(msg.huecaId));

                          if (mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Respuesta enviada a la hueca exitosamente!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al responder: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(SupportMessage msg) async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      final adminUid = currentUser?.uid ?? 'admin';

      await ref.read(supportRepositoryProvider).markAsRead(msg.id, adminUid);
      ref.invalidate(allSupportMessagesProvider);
      ref.invalidate(newSupportMessagesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensaje marcado como leído.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMessagesAsync = ref.watch(allSupportMessagesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver al Dashboard',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Bandeja de Soporte a Huecas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFFFBBF24),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFBBF24),
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            Tab(
              child: allMessagesAsync.when(
                data: (list) {
                  final newCount = list.where((m) => m.status == 'new').length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Nuevos'),
                      if (newCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: Text('$newCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Text('Nuevos'),
                error: (_, __) => const Text('Nuevos'),
              ),
            ),
            const Tab(text: 'Leídos'),
            const Tab(text: 'Respondidos'),
            const Tab(text: 'Todos'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por hueca, remitente, asunto o texto...',
                hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Vistas de tabs
          Expanded(
            child: allMessagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              error: (e, s) => Center(child: Text('Error al cargar mensajes: $e')),
              data: (messages) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMessagesList(messages.where((m) => m.status == 'new').toList(), 'No hay mensajes nuevos pendientes.'),
                    _buildMessagesList(messages.where((m) => m.status == 'read').toList(), 'No hay mensajes marcados como leídos sin responder.'),
                    _buildMessagesList(messages.where((m) => m.status == 'responded').toList(), 'No hay mensajes respondidos todavía.'),
                    _buildMessagesList(messages, 'No hay mensajes en la bandeja.'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<SupportMessage> list, String emptyMessage) {
    var filtered = list;
    if (_searchQuery.isNotEmpty) {
      filtered = list.where((m) {
        return m.huecaName.toLowerCase().contains(_searchQuery) ||
            m.senderName.toLowerCase().contains(_searchQuery) ||
            m.senderEmail.toLowerCase().contains(_searchQuery) ||
            m.subject.toLowerCase().contains(_searchQuery) ||
            m.message.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.blueGrey.shade300),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0F172A),
      onRefresh: () async {
        ref.invalidate(allSupportMessagesProvider);
        ref.invalidate(newSupportMessagesProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) => _buildMessageCard(filtered[i]),
      ),
    );
  }

  Widget _buildMessageCard(SupportMessage msg) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (msg.status) {
      case 'responded':
        statusColor = Colors.green;
        statusText = 'Respondido';
        statusIcon = Icons.mark_chat_read;
        break;
      case 'read':
        statusColor = Colors.blue;
        statusText = 'Leído';
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.orange.shade800;
        statusText = 'Nuevo';
        statusIcon = Icons.fiber_new;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Hueca + Badge de Estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront, size: 18, color: Color(0xFF0F172A)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              msg.huecaName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (msg.branchName != null && msg.branchName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sucursal: ${msg.branchName}',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(msg.createdAt),
                        style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Asunto
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    msg.subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Remitente
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text(
                  msg.senderName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.email_outlined, size: 14, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    msg.senderEmail,
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Mensaje
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Text(
                msg.message,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
              ),
            ),

            // Respuesta existente si ya fue respondido
            if (msg.adminResponse != null && msg.adminResponse!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Respuesta enviada:',
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
                    const SizedBox(height: 4),
                    Text(
                      msg.adminResponse!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF14532D)),
                    ),
                  ],
                ),
              ),
            ],

            // Botones de acción
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (msg.status == 'new') ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: BorderSide(color: Colors.blueGrey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.done, size: 16),
                    label: const Text('Marcar Leído', style: TextStyle(fontSize: 12)),
                    onPressed: () => _markAsRead(msg),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.reply, size: 16),
                  label: Text(
                    msg.status == 'responded' ? 'Modificar Respuesta' : 'Responder',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _respondToMessage(msg),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
