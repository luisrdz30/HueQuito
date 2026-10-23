import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/subscription_repository.dart';
import 'package:hue_quito/theme/theme.dart';

class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends ConsumerState<AdminSubscriptionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers para configuración
  final _priceController = TextEditingController();
  final _freeStampsController = TextEditingController();
  final _graceDaysController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountTypeController = TextEditingController();
  final _accountNumController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _idNumController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSavingSettings = false;
  bool _isSettingsExpanded = false;
  bool _isThresholdChartExpanded = true;
  bool _showAllInChart = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceController.dispose();
    _freeStampsController.dispose();
    _graceDaysController.dispose();
    _bankNameController.dispose();
    _accountTypeController.dispose();
    _accountNumController.dispose();
    _accountHolderController.dispose();
    _idNumController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initSettingsControllers(SubscriptionSettings settings) {
    if (_priceController.text.isEmpty) {
      _priceController.text = settings.monthlyPrice.toStringAsFixed(2);
      _freeStampsController.text = settings.freeTierMaxStamps.toString();
      _graceDaysController.text = settings.gracePeriodDays.toString();
      _bankNameController.text = settings.bankName;
      _accountTypeController.text = settings.accountType;
      _accountNumController.text = settings.accountNumber;
      _accountHolderController.text = settings.accountHolder;
      _idNumController.text = settings.identificationNumber;
      _emailController.text = settings.notificationEmail;
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      final newSettings = SubscriptionSettings(
        monthlyPrice: double.tryParse(_priceController.text.trim()) ?? 9.99,
        freeTierMaxStamps: int.tryParse(_freeStampsController.text.trim()) ?? 50,
        gracePeriodDays: int.tryParse(_graceDaysController.text.trim()) ?? 7,
        bankName: _bankNameController.text.trim(),
        accountType: _accountTypeController.text.trim(),
        accountNumber: _accountNumController.text.trim(),
        accountHolder: _accountHolderController.text.trim(),
        identificationNumber: _idNumController.text.trim(),
        notificationEmail: _emailController.text.trim(),
      );

      await ref.read(subscriptionRepositoryProvider).updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Configuración de suscripciones actualizada con éxito!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        setState(() => _isSettingsExpanded = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  Future<void> _approveReceipt(Hueca hueca) async {
    final user = ref.read(currentUserProvider).value;
    final adminId = user?.uid ?? 'admin';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Aprobar comprobante?'),
        content: Text(
          'Se activará la suscripción para "${hueca.name}" por 30 días. Si estaba suspendida, volverá a aparecer en el mapa y búsquedas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white),
            child: const Text('Aprobar Pago'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(subscriptionRepositoryProvider).approvePayment(
          huecaId: hueca.id,
          adminId: adminId,
        );
        ref.invalidate(huecasProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Suscripción aprobada para ${hueca.name}!'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _rejectReceipt(Hueca hueca) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar comprobante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Indica el motivo de rechazo para ${hueca.name}:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Ej. Monto incompleto, imagen borrosa...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Confirmar Rechazo'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final reason = reasonController.text.trim().isEmpty
          ? 'Comprobante no válido o ilegible'
          : reasonController.text.trim();

      try {
        await ref.read(subscriptionRepositoryProvider).rejectPayment(
          huecaId: hueca.id,
          reason: reason,
        );
        ref.invalidate(huecasProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comprobante rechazado para ${hueca.name}.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: const Text('No se pudo cargar la imagen'),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(subscriptionSettingsProvider);
    final huecasAsync = ref.watch(huecasProvider);
    final subRepo = ref.watch(subscriptionRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final underReviewCount = huecasAsync.value?.where((h) => h.subscription['status'] == 'under_review').length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: settingsAsync.when(
        data: (settings) {
          _initSettingsControllers(settings);

          return NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
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
                                'Suscripciones y Pagos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Actualizar',
                              icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                              onPressed: () {
                                ref.invalidate(subscriptionSettingsProvider);
                                ref.invalidate(huecasProvider);
                              },
                            ),
                          ],
                        ),
                      ),

                      // Gráfica de Huecas Próximas al Cobro Mensual
                      _buildProximityToChargeCard(huecasAsync.value ?? [], settings, isDark),

                      // Panel Colapsable de Configuración de Suscripción
                      _buildSettingsPanel(context, settings, isDark),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: const Color(0xFFFBBF24),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFFFBBF24),
                      unselectedLabelColor: Colors.white70,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pending_actions, size: 16),
                              const SizedBox(width: 6),
                              const Text('Por Validar'),
                              if (underReviewCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                  child: Text('$underReviewCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 16),
                              SizedBox(width: 6),
                              Text('Al Día'),
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber, size: 16),
                              SizedBox(width: 6),
                              Text('En Gracia / Corte'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                ),
              ];
            },
            body: huecasAsync.when(
              data: (huecas) {
                final pendingHuecas = <Hueca>[];
                final activeHuecas = <Hueca>[];
                final graceOrSuspendedHuecas = <Hueca>[];

                for (final h in huecas) {
                  final info = subRepo.evaluateHuecaSubscription(hueca: h, settings: settings);
                  if (info.state == HuecaSubscriptionState.underReview) {
                    pendingHuecas.add(h);
                  } else if (info.state == HuecaSubscriptionState.active) {
                    activeHuecas.add(h);
                  } else if (info.state == HuecaSubscriptionState.gracePeriod || info.state == HuecaSubscriptionState.suspended) {
                    graceOrSuspendedHuecas.add(h);
                  }
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Pendientes de revisión
                    _buildPendingTab(pendingHuecas, isDark),

                    // Tab 2: Al día / Activas
                    _buildActiveTab(activeHuecas, isDark),

                    // Tab 3: En gracia o suspendidas
                    _buildGraceOrSuspendedTab(graceOrSuspendedHuecas, isDark),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error cargando huecas: $e')),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSettingsPanel(BuildContext context, SubscriptionSettings settings, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.settings, color: AppTheme.primary),
            title: const Text(
              'Tarifas y Datos Bancarios',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '\$${settings.monthlyPrice.toStringAsFixed(2)}/mes • Meta: ${settings.freeTierMaxStamps} sellos • Gracia: ${settings.gracePeriodDays} días',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppTheme.textMedium),
            ),
            trailing: IconButton(
              icon: Icon(_isSettingsExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isSettingsExpanded = !_isSettingsExpanded),
            ),
          ),
          if (_isSettingsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Precio Mensual (\$)',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _freeStampsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Meta Sellos Gratis',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _graceDaysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Días de Gracia',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bankNameController,
                          decoration: const InputDecoration(labelText: 'Banco', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _accountTypeController,
                          decoration: const InputDecoration(labelText: 'Tipo de Cuenta', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _accountNumController,
                          decoration: const InputDecoration(labelText: 'Número de Cuenta', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _accountHolderController,
                          decoration: const InputDecoration(labelText: 'Titular', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _idNumController,
                          decoration: const InputDecoration(labelText: 'Cédula / RUC', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Correo Pagos', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingSettings ? null : _saveSettings,
                      icon: const Icon(Icons.save),
                      label: Text(_isSavingSettings ? 'Guardando...' : 'Guardar Ajustes de Suscripción'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingTab(List<Hueca> huecas, bool isDark) {
    if (huecas.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.done_all_rounded, size: 54, color: Colors.green.shade400),
              const SizedBox(height: 12),
              const Text('No hay comprobantes pendientes de validar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Todas las transferencias están al día', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: huecas.length,
      itemBuilder: (ctx, idx) {
        final h = huecas[idx];
        final lastReceipt = h.subscription['lastReceipt'] is Map ? h.subscription['lastReceipt'] : {};
        final imageUrl = lastReceipt['imageUrl']?.toString() ?? '';
        final refNum = lastReceipt['referenceNumber']?.toString() ?? '';
        final amount = (lastReceipt['amount'] as num?)?.toDouble() ?? 9.99;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        h.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (refNum.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Ref: $refNum', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 12),
                if (imageUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showFullImage(imageUrl),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40)),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Ver grande', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectReceipt(h),
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                        label: const Text('Rechazar', style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveReceipt(h),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Aprobar Pago'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTab(List<Hueca> huecas, bool isDark) {
    if (huecas.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_outlined, size: 54, color: Colors.blueGrey.shade300),
              const SizedBox(height: 12),
              const Text('No hay huecas con suscripción activa actualmente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: huecas.length,
      itemBuilder: (ctx, idx) {
        final h = huecas[idx];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFDCFCE7),
            child: Icon(Icons.verified, color: AppTheme.accentGreen),
          ),
          title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Sector: ${h.sector} • Sellos: ${h.metrics['stampsGiven'] ?? 0}'),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }

  Widget _buildGraceOrSuspendedTab(List<Hueca> huecas, bool isDark) {
    if (huecas.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 54, color: Colors.green.shade400),
              const SizedBox(height: 12),
              const Text('No hay huecas en periodo de corte o suspendidas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: huecas.length,
      itemBuilder: (ctx, idx) {
        final h = huecas[idx];
        final isSuspended = h.subscription['status'] == 'suspended' || !h.isActive;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSuspended ? Colors.red.shade100 : Colors.amber.shade100,
              child: Icon(
                isSuspended ? Icons.block : Icons.access_time_filled,
                color: isSuspended ? Colors.red : Colors.amber.shade900,
              ),
            ),
            title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              isSuspended
                  ? 'SUSPENDIDA (Oculta en la app)'
                  : 'EN GRACIA (Alcanzó los ${h.metrics['stampsGiven'] ?? 0} sellos)',
              style: TextStyle(
                color: isSuspended ? Colors.red : Colors.amber.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProximityToChargeCard(List<Hueca> huecas, SubscriptionSettings settings, bool isDark) {
    final maxFree = settings.freeTierMaxStamps > 0 ? settings.freeTierMaxStamps : 50;

    // Ordenar todas las huecas según sellos otorgados (de mayor a menor)
    final sortedHuecas = List<Hueca>.from(huecas)
      ..sort((a, b) {
        final aStamps = (a.metrics['stampsGiven'] as num?)?.toInt() ?? 0;
        final bStamps = (b.metrics['stampsGiven'] as num?)?.toInt() ?? 0;
        return bStamps.compareTo(aStamps);
      });

    final nearThreshold = (maxFree * 0.7).floor();
    final nearCount = sortedHuecas.where((h) {
      final s = (h.metrics['stampsGiven'] as num?)?.toInt() ?? 0;
      return s >= nearThreshold && s < maxFree;
    }).length;

    final reachedCount = sortedHuecas.where((h) {
      final s = (h.metrics['stampsGiven'] as num?)?.toInt() ?? 0;
      return s >= maxFree;
    }).length;

    final earlyCount = sortedHuecas.length - nearCount - reachedCount;
    final displayHuecas = _showAllInChart ? sortedHuecas : sortedHuecas.take(5).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
          // Encabezado del Card con botón de expandir/colapsar
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _isThresholdChartExpanded = !_isThresholdChartExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Color(0xFFFBBF24), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Gráfica: Próximos a Cobro',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.trending_up, color: Colors.orange, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Meta: $maxFree sellos • Cobro mensual: \$${settings.monthlyPrice.toStringAsFixed(2)}/mes',
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isThresholdChartExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF0F172A),
                    ),
                    onPressed: () => setState(() => _isThresholdChartExpanded = !_isThresholdChartExpanded),
                  ),
                ],
              ),
            ),
          ),

          if (_isThresholdChartExpanded) ...[
            const Divider(height: 1),

            // Píldoras de métricas resumen
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricPill(
                      icon: Icons.warning_amber_rounded,
                      label: 'Cerca a Cobro',
                      value: '$nearCount',
                      color: Colors.amber.shade900,
                      bgColor: Colors.amber.shade50,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricPill(
                      icon: Icons.check_circle_outline,
                      label: 'Meta Alcanzada',
                      value: '$reachedCount',
                      color: Colors.deepOrange.shade700,
                      bgColor: Colors.orange.shade50,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricPill(
                      icon: Icons.rocket_launch_outlined,
                      label: 'En Prueba',
                      value: '$earlyCount',
                      color: Colors.teal.shade700,
                      bgColor: Colors.teal.shade50,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de barras gráficas
            if (sortedHuecas.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No hay huecas registradas aún.',
                    style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final hueca in displayHuecas) ...[
                              _buildHuecaProgressBar(hueca, maxFree, settings.monthlyPrice),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (sortedHuecas.length > 5) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton.icon(
                          icon: Icon(_showAllInChart ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                          label: Text(
                            _showAllInChart ? 'Ver solo las 5 principales' : 'Ver todas (${sortedHuecas.length} huecas)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => setState(() => _showAllInChart = !_showAllInChart),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHuecaProgressBar(Hueca hueca, int maxFree, double price) {
    final stamps = (hueca.metrics['stampsGiven'] as num?)?.toInt() ?? 0;
    final ratio = (stamps / maxFree).clamp(0.0, 1.0);
    final percent = (ratio * 100).toInt();
    final remaining = maxFree - stamps;

    final isVeryClose = stamps >= (maxFree * 0.7).floor() && remaining > 0;
    final hasReached = stamps >= maxFree;

    Color statusColor;
    LinearGradient barGradient;

    if (hasReached) {
      statusColor = Colors.red.shade700;
      barGradient = const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFDC2626)]);
    } else if (isVeryClose) {
      statusColor = Colors.amber.shade900;
      barGradient = const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFEA580C)]);
    } else if (ratio >= 0.3) {
      statusColor = Colors.blue.shade700;
      barGradient = const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]);
    } else {
      statusColor = Colors.teal.shade700;
      barGradient = const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF0D9488)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${hueca.name} • ${hueca.sector}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$stamps/$maxFree ($percent%)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Barra horizontal gráfica
        Stack(
          children: [
            Container(
              height: 9,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: ratio == 0 ? 0.02 : ratio,
              child: Container(
                height: 9,
                decoration: BoxDecoration(
                  gradient: barGradient,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: ratio > 0.05
                      ? [
                          BoxShadow(
                            color: barGradient.colors.last.withValues(alpha: 0.25),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        if (hasReached)
          Text(
            '🚨 Meta alcanzada ($stamps sellos). Sujeto a cobro mensual de \$${price.toStringAsFixed(2)}.',
            style: TextStyle(color: Colors.red.shade700, fontSize: 10.5, fontWeight: FontWeight.bold),
          )
        else if (isVeryClose)
          Text(
            '⚠️ ¡A solo $remaining ${remaining == 1 ? "sello" : "sellos"} de pasar a cobro mensual (\$${price.toStringAsFixed(2)}/mes)!',
            style: TextStyle(color: Colors.amber.shade900, fontSize: 10.5, fontWeight: FontWeight.bold),
          )
        else
          Text(
            'Faltan $remaining sellos para completar los $maxFree gratuitos de prueba.',
            style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 10.5),
          ),
      ],
    );
  }
}


class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar, {required this.backgroundColor});

  final TabBar _tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate._tabBar != _tabBar || oldDelegate.backgroundColor != backgroundColor;
  }
}
