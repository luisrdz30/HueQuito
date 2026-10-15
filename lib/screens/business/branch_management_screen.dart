import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/screens/business/branch_form_screen.dart';

class BranchManagementScreen extends ConsumerStatefulWidget {
  final String huecaId;
  final Hueca? initialHueca;
  final bool isAdminMode;

  const BranchManagementScreen({
    super.key,
    required this.huecaId,
    this.initialHueca,
    this.isAdminMode = false,
  });

  @override
  ConsumerState<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends ConsumerState<BranchManagementScreen> {
  Future<void> _deleteBranch(Hueca hueca, HuecaBranch branch) async {
    if (hueca.allBranches.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe existir al menos un local principal')),
      );
      return;
    }

    final hasManager = branch.managerEmail != null && branch.managerEmail!.trim().isNotEmpty;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Local'),
        content: Text(
          hasManager
              ? '¿Estás seguro de que deseas eliminar "${branch.name}"?\n\nTambién se revocará el acceso de administrador al encargado (${branch.managerEmail}).'
              : '¿Estás seguro de que deseas eliminar "${branch.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<HuecaBranch> currentBranches = List.from(hueca.allBranches);
      currentBranches.removeWhere((b) => b.id == branch.id);

      final branchesData = currentBranches.map((b) => b.toMap()).toList();

      if (Firebase.apps.isNotEmpty) {
        final docRef = FirebaseFirestore.instance.collection('huecas').doc(hueca.id);
        await docRef.update({
          'branches': branchesData,
          'address': currentBranches.first.address,
          'sector': currentBranches.first.sector,
          'phone': currentBranches.first.phone,
          'location': currentBranches.first.location,
        });

        // Revocar acceso de administrador al encargado si existía
        if (hasManager) {
          final emailToRevoke = branch.managerEmail!.trim().toLowerCase();
          try {
            final usersSnap = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: emailToRevoke)
                .get();
            for (var uDoc in usersSnap.docs) {
              await uDoc.reference.update({'role': 'user'});
            }
            await FirebaseFirestore.instance.collection('branch_invitations').doc(emailToRevoke).delete();
          } catch (_) {}
        }
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local eliminado')),
        );
        ref.invalidate(allHuecasStreamProvider);
        ref.invalidate(huecasProvider);
        ref.invalidate(myHuecaProvider);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<void> _navigateToForm(Hueca hueca, bool isOwner, {HuecaBranch? branch}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchFormScreen(
          hueca: hueca,
          existingBranch: branch,
          isOwner: isOwner,
        ),
      ),
    );
    ref.invalidate(allHuecasStreamProvider);
    ref.invalidate(huecasProvider);
    ref.invalidate(myHuecaProvider);
  }

  @override
  Widget build(BuildContext context) {
    final myHuecaAsync = ref.watch(myHuecaProvider);
    final allHuecas = ref.watch(allHuecasStreamProvider).value ?? [];
    final currentUser = ref.watch(currentUserProvider).value;
    final isOwnerAsync = ref.watch(isOwnerProvider);
    final managedBranchAsync = ref.watch(currentManagedBranchProvider);

    final isAdmin = widget.isAdminMode || (currentUser?.role == 'admin');

    // Resolver hueca específica si se proporcionó id o initialHueca
    Hueca? explicitHueca;
    if (widget.huecaId.isNotEmpty && allHuecas.isNotEmpty) {
      final matches = allHuecas.where((h) => h.id == widget.huecaId);
      if (matches.isNotEmpty) explicitHueca = matches.first;
    }
    if (explicitHueca == null && widget.huecaId.isNotEmpty) {
      final fallbackList = ref.watch(huecasProvider).value ?? [];
      final matches = fallbackList.where((h) => h.id == widget.huecaId);
      if (matches.isNotEmpty) explicitHueca = matches.first;
    }
    explicitHueca ??= widget.initialHueca;

    final hueca = explicitHueca ?? myHuecaAsync.value;
    final isOwner = isAdmin || (isOwnerAsync.value ?? true);
    final managedBranch = managedBranchAsync.value;

    return Scaffold(
      backgroundColor: isAdmin ? const Color(0xFFF8FAFC) : null,
      appBar: AppBar(
        title: Text(
          isAdmin
              ? (hueca != null ? 'Locales: ${hueca.name}' : 'Locales del Negocio')
              : (explicitHueca != null ? 'Locales: ${explicitHueca.name}' : 'Mis Locales / Sucursales'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: isAdmin ? const Color(0xFF0F172A) : Colors.transparent,
        elevation: 0,
        foregroundColor: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface,
        iconTheme: IconThemeData(color: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (isAdmin) {
              context.go('/admin/huecas');
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: hueca == null
          ? (myHuecaAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text('No se encontró el negocio')))
          : Builder(
              builder: (context) {
                final branches = hueca.allBranches;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_outlined, color: Colors.teal, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Administración Central de Locales',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Hueca: ${hueca.name} • ${branches.length} ${branches.length == 1 ? 'local registrado' : 'locales registrados'}',
                                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(isOwner ? Icons.admin_panel_settings : Icons.badge, color: AppTheme.primary, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOwner ? 'Dueño General (Acceso Total)' : 'Encargado de Sucursal',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isOwner
                                    ? 'Puedes agregar locales y fijar su ubicación en el mapa.'
                                    : 'Tienes permiso para gestionar tu local asignado: ${managedBranch?.name ?? ""}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Title and Add Button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Locales Registrados (${branches.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isAdmin ? const Color(0xFF0F172A) : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isOwner)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nuevo Local'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAdmin ? const Color(0xFF0F172A) : AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => _navigateToForm(hueca, isOwner),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Branches List
                Expanded(
                  child: ListView.builder(
                    itemCount: branches.length,
                    itemBuilder: (ctx, index) {
                      final branch = branches[index];
                      final isMatriz = index == 0;
                      final canEditThisBranch = isOwner || (managedBranch?.id == branch.id);

                      return Card(
                        color: isAdmin ? Colors.white : null,
                        elevation: isAdmin ? 0 : 1.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: isAdmin ? const BorderSide(color: Color(0xFFE2E8F0)) : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: canEditThisBranch ? () => _navigateToForm(hueca, isOwner, branch: branch) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isMatriz
                                            ? (isAdmin ? const Color(0xFF0F172A) : AppTheme.primary)
                                            : Colors.blueGrey.shade700,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMatriz ? 'Matriz' : 'Sucursal #${index + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        branch.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isAdmin ? const Color(0xFF0F172A) : null,
                                        ),
                                      ),
                                    ),
                                    if (canEditThisBranch)
                                      Tooltip(
                                        message: 'Editar local',
                                        child: InkWell(
                                          onTap: () => _navigateToForm(hueca, isOwner, branch: branch),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                            ),
                                            child: const Icon(Icons.edit, size: 17, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                      ),
                                    if (isOwner && !isMatriz) ...[
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Eliminar local',
                                        child: InkWell(
                                          onTap: () => _deleteBranch(hueca, branch),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFFECACA)),
                                            ),
                                            child: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFDC2626)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: isAdmin ? Colors.teal : Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${branch.address} (${branch.sector})',
                                        style: TextStyle(fontSize: 13, color: isAdmin ? Colors.blueGrey.shade800 : null),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.pin_drop, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      'GPS: ${branch.location.latitude.toStringAsFixed(4)}, ${branch.location.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                if (branch.phone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(branch.phone, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isAdmin ? const Color(0xFFF1F5F9) : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, size: 15, color: isAdmin ? Colors.blueGrey : Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          branch.managerEmail != null && branch.managerEmail!.isNotEmpty
                                              ? 'Encargado: ${branch.managerEmail}'
                                              : 'Sin correo de encargado asignado',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: branch.managerEmail != null && branch.managerEmail!.isNotEmpty
                                                ? (isAdmin ? const Color(0xFF0F172A) : Colors.black87)
                                                : Colors.blueGrey.shade400,
                                            fontWeight: branch.managerEmail != null && branch.managerEmail!.isNotEmpty
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
