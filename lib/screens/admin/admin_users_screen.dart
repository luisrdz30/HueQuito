import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/widgets/delete_user_dialog.dart';

class UserBusinessAssignment {
  final bool isAssigned;
  final bool isOwner;
  final bool isBranch;
  final Hueca? hueca;
  final HuecaBranch? branch;

  const UserBusinessAssignment({
    required this.isAssigned,
    required this.isOwner,
    required this.isBranch,
    this.hueca,
    this.branch,
  });

  static UserBusinessAssignment resolve(UserModel user, List<Hueca> huecas) {
    if (user.role != 'business') {
      return const UserBusinessAssignment(isAssigned: false, isOwner: false, isBranch: false);
    }

    final normalizedEmail = user.email.trim().toLowerCase();

    // 1. Verificar si está registrado como managerEmail de alguna sucursal en cualquier hueca
    if (normalizedEmail.isNotEmpty) {
      for (final h in huecas) {
        for (final b in h.branches) {
          if (b.managerEmail != null && b.managerEmail!.trim().toLowerCase() == normalizedEmail) {
            return UserBusinessAssignment(
              isAssigned: true,
              isOwner: false,
              isBranch: true,
              hueca: h,
              branch: b,
            );
          }
        }
      }
    }

    // 2. Si tiene managedHuecaId y managedBranchId explícito en su UserModel
    if (user.managedHuecaId != null && user.managedHuecaId!.isNotEmpty) {
      final matches = huecas.where((h) => h.id == user.managedHuecaId);
      if (matches.isNotEmpty) {
        final h = matches.first;
        if (user.managedBranchId != null && user.managedBranchId!.isNotEmpty) {
          final bMatches = h.branches.where((b) => b.id == user.managedBranchId);
          if (bMatches.isNotEmpty) {
            return UserBusinessAssignment(
              isAssigned: true,
              isOwner: false,
              isBranch: true,
              hueca: h,
              branch: bMatches.first,
            );
          }
        }
        return UserBusinessAssignment(
          isAssigned: true,
          isOwner: true,
          isBranch: false,
          hueca: h,
        );
      }
    }

    // 3. Dueño general de hueca por ownerId
    final ownerMatches = huecas.where((h) => h.ownerId == user.uid);
    if (ownerMatches.isNotEmpty) {
      return UserBusinessAssignment(
        isAssigned: true,
        isOwner: true,
        isBranch: false,
        hueca: ownerMatches.first,
      );
    }

    return const UserBusinessAssignment(isAssigned: false, isOwner: false, isBranch: false);
  }
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'assigned', 'branches', 'unassigned', 'admin'

  Future<void> _showCreateBusinessAccountDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String assignmentType = 'none'; // 'none', 'owner', 'branch'
    String? selectedHuecaId;
    String? selectedBranchId;
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;

    final huecas = ref.read(allHuecasStreamProvider).value ?? [];
    if (huecas.isNotEmpty) {
      selectedHuecaId = huecas.first.id;
      if (huecas.first.branches.isNotEmpty) {
        selectedBranchId = huecas.first.branches.first.id;
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final currentSelectedHueca = huecas.where((h) => h.id == selectedHuecaId).toList();
            final currentBranches = currentSelectedHueca.isNotEmpty ? currentSelectedHueca.first.branches : <HuecaBranch>[];

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_business, color: Color(0xFF0F172A), size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crear Cuenta de Negocio',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rol: Negocio • Asignación a Hueca o Sucursal',
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
                        const Text('Nombre del Dueño o Representante *', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Ej. Don Carlos Mendoza',
                            hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF0F172A), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                        ),
                        const SizedBox(height: 12),

                        const Text('Correo Electrónico *', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'dueño@hueca.com',
                            hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0F172A), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa el correo';
                            if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0F172A).withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.mark_email_read_outlined, color: Color(0xFF0F172A), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Definición de contraseña por correo',
                                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'No se requiere contraseña manual. Se enviará automáticamente un correo electrónico a la dirección ingresada para que el propio dueño o encargado defina su contraseña de acceso.',
                                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 11, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text('Asignar a Hueca (Solo 1 hueca):', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: assignmentType,
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'none', child: Text('Sin asignar por ahora')),
                            DropdownMenuItem(value: 'owner', child: Text('Dueño General de Hueca (Matriz)')),
                            DropdownMenuItem(value: 'branch', child: Text('Encargado de Sucursal / Local')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                assignmentType = val;
                                if (assignmentType != 'none' && selectedHuecaId == null && huecas.isNotEmpty) {
                                  selectedHuecaId = huecas.first.id;
                                  selectedBranchId = huecas.first.branches.isNotEmpty ? huecas.first.branches.first.id : null;
                                }
                              });
                            }
                          },
                        ),

                        if (assignmentType == 'owner') ...[
                          const SizedBox(height: 10),
                          const Text('Seleccionar Hueca:', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: selectedHuecaId,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: huecas.map((h) {
                              final hasOwner = h.ownerId.isNotEmpty;
                              return DropdownMenuItem(
                                value: h.id,
                                child: Text(
                                  hasOwner ? '${h.name} (Tiene dueño)' : h.name,
                                  style: TextStyle(
                                    color: hasOwner ? Colors.orange.shade800 : const Color(0xFF0F172A),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedHuecaId = val),
                          ),
                        ] else if (assignmentType == 'branch') ...[
                          const SizedBox(height: 10),
                          const Text('Hueca Matriz:', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: selectedHuecaId,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: huecas.map((h) {
                              return DropdownMenuItem(
                                value: h.id,
                                child: Text(h.name, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedHuecaId = val;
                                if (val != null) {
                                  final match = huecas.where((h) => h.id == val).toList();
                                  if (match.isNotEmpty && match.first.branches.isNotEmpty) {
                                    selectedBranchId = match.first.branches.first.id;
                                  } else {
                                    selectedBranchId = null;
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          const Text('Sucursal / Local asignado:', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          if (currentBranches.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Esta hueca no tiene sucursales registradas.', style: TextStyle(color: Colors.red, fontSize: 11)),
                            )
                          else
                            DropdownButtonFormField<String?>(
                              isExpanded: true,
                              value: currentBranches.any((b) => b.id == selectedBranchId)
                                  ? selectedBranchId
                                  : currentBranches.first.id,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: currentBranches.map((b) {
                                final hasMgr = b.managerEmail != null && b.managerEmail!.isNotEmpty;
                                return DropdownMenuItem(
                                  value: b.id,
                                  child: Text(
                                    hasMgr ? '${b.name} (Ocupada: ${b.managerEmail})' : b.name,
                                    style: TextStyle(
                                      color: hasMgr ? Colors.orange.shade800 : const Color(0xFF0F172A),
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setDialogState(() => selectedBranchId = val),
                            ),
                        ],

                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Cada cuenta de negocio solo puede estar asignada a 1 hueca.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isCreating ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setDialogState(() => isCreating = true);

                    try {
                      final created = await ref.read(userRepositoryProvider).createBusinessAccount(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        assignedHuecaId: (assignmentType != 'none') ? selectedHuecaId : null,
                        assignedBranchId: (assignmentType == 'branch') ? selectedBranchId : null,
                      );

                      ref.invalidate(allUsersStreamProvider);
                      ref.invalidate(allHuecasStreamProvider);
                      ref.invalidate(huecasProvider);

                      if (mounted) {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (succCtx) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Cuenta Creada', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Se creó exitosamente la cuenta para "${created.name}" y se envió el correo con el enlace para definir su contraseña a:\n\n${emailCtrl.text.trim()}',
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: const Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Aviso para correos institucionales (@puce.edu.ec, etc.):\n\nEl remitente es noreply@huequito-b091a.firebaseapp.com. En Outlook debe revisar la carpeta de "Correo no deseado / SPAM" o la pestaña "Otros", ya que las universidades suelen clasificar correos automáticos ahí.',
                                          style: TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => Navigator.pop(succCtx),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isCreating = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al crear cuenta: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: isCreating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Crear Cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndResendPasswordReset(UserModel user) async {
    final cleanEmail = user.email.trim();
    if (cleanEmail.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text(
              'Reenviar Contraseña',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se enviará un correo con un enlace oficial de Firebase para que el usuario pueda crear o restablecer su contraseña:\n\n$cleanEmail',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0F766E), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Útil si el enlace anterior expiró o si el usuario no completó su contraseña a tiempo.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.blueGrey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Enviar Enlace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _resendPasswordResetEmail(cleanEmail);
    }
  }

  Future<void> _resendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return;

    try {
      await FirebaseAuth.instance.setLanguageCode('es');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_read, color: Colors.teal),
                SizedBox(width: 8),
                Text('Correo Enviado', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se envió un enlace para configurar contraseña a:\n\n$cleanEmail',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Importante: Si es un correo institucional (ej. @puce.edu.ec) o corporativo, debe revisar la carpeta de SPAM / Correo no deseado o la pestaña "Otros" de Outlook.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar correo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDeleteUser(UserModel user, UserBusinessAssignment assignment) async {
    await showDeleteUserConfirmationDialog(
      context: context,
      ref: ref,
      user: user,
      assignment: assignment,
    );
  }

  Future<void> _showChangeRoleDialog(UserModel user) async {
    String selectedRole = user.role;
    final huecas = ref.read(allHuecasStreamProvider).value ?? [];

    final initialAssignment = UserBusinessAssignment.resolve(user, huecas);
    String assignmentType = initialAssignment.isBranch
        ? 'branch'
        : (initialAssignment.isOwner ? 'owner' : 'none');
    String? selectedHuecaId = initialAssignment.hueca?.id;
    String? selectedBranchId = initialAssignment.branch?.id;

    if (selectedHuecaId == null && huecas.isNotEmpty) {
      selectedHuecaId = huecas.first.id;
      if (huecas.first.branches.isNotEmpty) {
        selectedBranchId = huecas.first.branches.first.id;
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final currentSelectedHueca = huecas.where((h) => h.id == selectedHuecaId).toList();
            final currentBranches = currentSelectedHueca.isNotEmpty ? currentSelectedHueca.first.branches : <HuecaBranch>[];

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.manage_accounts, color: Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gestionar Rol: ${user.name}',
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    const Text('Seleccionar Rol:', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedRole,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('Cliente Regular (user)')),
                        DropdownMenuItem(value: 'business', child: Text('Dueño de Negocio (business)')),
                        DropdownMenuItem(value: 'admin', child: Text('Superadministrador (admin)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedRole = val;
                          });
                        }
                      },
                    ),
                    if (selectedRole == 'business') ...[
                      const SizedBox(height: 14),
                      const Text('Tipo de Asignación:', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: assignmentType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('Sin Asignación (Desvincular)')),
                          DropdownMenuItem(value: 'owner', child: Text('Dueño General de Hueca (Matriz)')),
                          DropdownMenuItem(value: 'branch', child: Text('Encargado de Sucursal / Local')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              assignmentType = val;
                              if (assignmentType != 'none' && selectedHuecaId == null && huecas.isNotEmpty) {
                                selectedHuecaId = huecas.first.id;
                                selectedBranchId = huecas.first.branches.isNotEmpty ? huecas.first.branches.first.id : null;
                              }
                            });
                          }
                        },
                      ),
                      if (assignmentType == 'owner') ...[
                        const SizedBox(height: 12),
                        const Text('Hueca Administrada:', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: selectedHuecaId,
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: huecas.map((h) {
                            final isCurrent = h.id == selectedHuecaId && initialAssignment.isOwner;
                            final isOwnedByOther = h.ownerId.isNotEmpty && h.ownerId != user.uid;
                            String label = h.name;
                            if (isCurrent) {
                              label += ' (Actual)';
                            } else if (isOwnedByOther) {
                              label += ' (Reasignará dueño)';
                            }
                            return DropdownMenuItem(
                              value: h.id,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.green.shade800
                                      : (isOwnedByOther ? Colors.orange.shade800 : const Color(0xFF0F172A)),
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedHuecaId = val),
                        ),
                      ] else if (assignmentType == 'branch') ...[
                        const SizedBox(height: 12),
                        const Text('Hueca a la que pertenece:', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: selectedHuecaId,
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: huecas.map((h) {
                            final count = h.branches.length;
                            return DropdownMenuItem(
                              value: h.id,
                              child: Text('${h.name} ($count sucursales)', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedHuecaId = val;
                              if (val != null) {
                                final match = huecas.where((h) => h.id == val).toList();
                                if (match.isNotEmpty && match.first.branches.isNotEmpty) {
                                  selectedBranchId = match.first.branches.first.id;
                                } else {
                                  selectedBranchId = null;
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        const Text('Sucursal / Local asignado:', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        if (currentBranches.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Esta hueca no tiene sucursales registradas.', style: TextStyle(color: Colors.red, fontSize: 11)),
                          )
                        else
                          DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: currentBranches.any((b) => b.id == selectedBranchId)
                                ? selectedBranchId
                                : currentBranches.first.id,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: currentBranches.map((b) {
                              final hasMgr = b.managerEmail != null && b.managerEmail!.isNotEmpty;
                              final isMe = hasMgr && b.managerEmail!.toLowerCase() == user.email.toLowerCase();
                              String label = b.name;
                              if (isMe) {
                                label += ' (Actual)';
                              } else if (hasMgr) {
                                label += ' (Encargado: ${b.managerEmail})';
                              }
                              return DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isMe ? Colors.green.shade800 : (hasMgr ? Colors.orange.shade800 : const Color(0xFF0F172A)),
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setDialogState(() => selectedBranchId = val),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'ℹ️ Regla: Solo puede asignarse a 1 hueca o sucursal a la vez.',
                        style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const Divider(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.mark_email_read_outlined, size: 18, color: Colors.teal),
                            label: const Text('Reenviar enlace de contraseña al correo', style: TextStyle(color: Colors.teal, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.teal),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmAndResendPasswordReset(user);
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          label: const Text('Eliminar cuenta de este usuario...', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            backgroundColor: const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleDeleteUser(user, initialAssignment);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(userRepositoryProvider).updateUserRoleByAdmin(user.uid, selectedRole);

                      if (selectedRole == 'business') {
                        if (assignmentType == 'owner' && selectedHuecaId != null) {
                          await ref.read(userRepositoryProvider).assignHuecaToBusinessUser(user.uid, selectedHuecaId);
                        } else if (assignmentType == 'branch' && selectedHuecaId != null && selectedBranchId != null) {
                          await ref.read(userRepositoryProvider).assignBranchToBusinessUser(
                            uid: user.uid,
                            email: user.email,
                            huecaId: selectedHuecaId!,
                            branchId: selectedBranchId!,
                          );
                        } else {
                          await ref.read(userRepositoryProvider).unassignBusinessUser(user.uid, user.email);
                        }
                      }

                      ref.invalidate(allUsersStreamProvider);
                      ref.invalidate(allHuecasStreamProvider);
                      ref.invalidate(huecasProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Rol y asignación de "${user.name}" actualizados'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al cambiar rol: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
            ),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, correo, hueca o sucursal...',
                    hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.blueGrey),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Con Hueca / Local', 'assigned'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sucursales', 'branches'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sin Asignar', 'unassigned'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Admins', 'admin'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Crear Cuenta de Negocio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    onPressed: _showCreateBusinessAccountDialog,
                  ),
                ),
              ],
            ),
          ),

          // Lista de Cuentas de Negocio y Administradores
          Expanded(
            child: usersAsync.when(
              data: (usersList) {
                final huecas = ref.watch(allHuecasStreamProvider).value ?? [];

                final filtered = usersList.where((u) {
                  // FILTRO ESTRICTO: Excluir usuarios comunes / clientes normales ("gente x de la app")
                  if (u.role != 'business' && u.role != 'admin') return false;

                  final assignment = UserBusinessAssignment.resolve(u, huecas);

                  if (_searchQuery.isNotEmpty) {
                    final matchName = u.name.toLowerCase().contains(_searchQuery);
                    final matchEmail = u.email.toLowerCase().contains(_searchQuery);
                    final matchUid = u.uid.toLowerCase().contains(_searchQuery);
                    final matchHueca = assignment.hueca != null && assignment.hueca!.name.toLowerCase().contains(_searchQuery);
                    final matchBranch = assignment.branch != null && assignment.branch!.name.toLowerCase().contains(_searchQuery);
                    if (!matchName && !matchEmail && !matchUid && !matchHueca && !matchBranch) return false;
                  }

                  if (_roleFilter == 'admin' && u.role != 'admin') return false;
                  if (_roleFilter == 'assigned' && !assignment.isAssigned) return false;
                  if (_roleFilter == 'branches' && !assignment.isBranch) return false;
                  if (_roleFilter == 'unassigned') {
                    if (u.role != 'business' || assignment.isAssigned) return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront_outlined, size: 54, color: Colors.blueGrey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron cuentas de negocio',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty || _roleFilter != 'all'
                                ? 'Prueba ajustando los filtros o el término de búsqueda.'
                                : 'Crea una cuenta para un dueño o encargado con el botón "Crear Cuenta de Negocio".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    final assignment = UserBusinessAssignment.resolve(user, huecas);
                    return _buildUserCard(user, assignment);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              error: (err, _) => Center(
                child: Text('Error cargando cuentas: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.amber, size: 20),
        label: const Text('Nueva Cuenta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        onPressed: _showCreateBusinessAccountDialog,
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return InkWell(
      onTap: () => setState(() => _roleFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.amber : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, UserBusinessAssignment assignment) {
    Color roleColor;
    String roleLabel;

    if (user.role == 'admin') {
      roleColor = Colors.purple.shade700;
      roleLabel = 'ADMIN';
    } else {
      roleColor = assignment.isBranch ? Colors.teal.shade700 : Colors.deepOrange;
      roleLabel = 'NEGOCIO';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withValues(alpha: 0.12),
                backgroundImage: user.profilePicUrl.isNotEmpty ? NetworkImage(user.profilePicUrl) : null,
                child: user.profilePicUrl.isEmpty
                    ? Icon(
                        user.role == 'admin'
                            ? Icons.shield
                            : (assignment.isBranch ? Icons.store : Icons.storefront),
                        color: roleColor,
                        size: 22,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.role == 'business') ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: assignment.isAssigned
                              ? (assignment.isBranch ? Colors.teal.shade50 : Colors.amber.shade50)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: assignment.isAssigned
                                ? (assignment.isBranch ? Colors.teal.shade200 : Colors.amber.shade200)
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              assignment.isAssigned
                                  ? (assignment.isBranch ? Icons.store : Icons.storefront)
                                  : Icons.warning_amber_rounded,
                              size: 13,
                              color: assignment.isAssigned
                                  ? (assignment.isBranch ? Colors.teal.shade900 : Colors.amber.shade900)
                                  : Colors.red.shade800,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                assignment.isBranch
                                    ? 'Sucursal: ${assignment.branch?.name} (${assignment.hueca?.name})'
                                    : (assignment.isOwner
                                        ? 'Hueca: ${assignment.hueca?.name}'
                                        : 'Sin hueca ni local asignado (Solo 1)'),
                                style: TextStyle(
                                  color: assignment.isAssigned
                                      ? (assignment.isBranch ? Colors.teal.shade900 : Colors.amber.shade900)
                                      : Colors.red.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (user.role == 'admin') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified_user, size: 13, color: Colors.purple.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Superadministrador del Sistema',
                              style: TextStyle(color: Colors.purple.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Asignar Hueca / Sucursal / Rol',
                child: InkWell(
                  onTap: () => _showChangeRoleDialog(user),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Icon(Icons.edit_note, color: Color(0xFF0F172A), size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Eliminar cuenta de usuario',
                child: InkWell(
                  onTap: () => _handleDeleteUser(user, assignment),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 20),
                  ),
                ),
              ),
            ],
          ),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmAndResendPasswordReset(user),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 16, color: Color(0xFF0F766E)),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Reenviar enlace de contraseña',
                          style: TextStyle(
                            color: Color(0xFF0F766E),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
