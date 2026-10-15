import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/widgets/delete_hueca_dialog.dart';

class AdminHuecasScreen extends ConsumerStatefulWidget {
  const AdminHuecasScreen({super.key});

  @override
  ConsumerState<AdminHuecasScreen> createState() => _AdminHuecasScreenState();
}

class _AdminHuecasScreenState extends ConsumerState<AdminHuecasScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'inactive', 'unassigned'

  Future<void> _toggleHuecaStatus(Hueca hueca, bool newValue) async {
    try {
      await ref.read(huecaRepositoryProvider).toggleHuecaActive(hueca.id, newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? '✅ Hueca "${hueca.name}" activada' : '⏸️ Hueca "${hueca.name}" pausada'),
            duration: const Duration(seconds: 2),
            backgroundColor: newValue ? Colors.green : Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAssignOwnerDialog(Hueca hueca) async {
    final usersAsync = await ref.read(userRepositoryProvider).getAllUsers();
    final allHuecas = ref.read(allHuecasStreamProvider).value ?? [];
    if (!mounted) return;

    String selectedUid = hueca.ownerId;
    String filterText = '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final filteredUsers = usersAsync.where((u) {
              if (u.role != 'business' && u.role != 'admin') return false;
              if (filterText.isEmpty) return true;
              return u.name.toLowerCase().contains(filterText.toLowerCase()) ||
                     u.email.toLowerCase().contains(filterText.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFF0F172A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Asignar Dueño a "${hueca.name}"',
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario por nombre o correo...',
                        hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          filterText = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Regla: Solo 1 hueca por cuenta de negocio.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredUsers.length + 1, // +1 for "Sin Dueño" option
                        itemBuilder: (itemCtx, index) {
                          if (index == 0) {
                            final isUnassigned = selectedUid.isEmpty;
                            return ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              tileColor: isUnassigned ? Colors.red.withValues(alpha: 0.08) : null,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.red.shade100,
                                child: const Icon(Icons.person_off, color: Colors.red, size: 18),
                              ),
                              title: const Text(
                                'Sin Dueño (Desvincular)',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: const Text(
                                'Dejar esta hueca sin cuenta asignada',
                                style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                              ),
                              trailing: isUnassigned
                                  ? const Icon(Icons.check_circle, color: Colors.red, size: 20)
                                  : null,
                              onTap: () {
                                setDialogState(() {
                                  selectedUid = '';
                                });
                              },
                            );
                          }

                          final user = filteredUsers[index - 1];
                          final isSelected = selectedUid == user.uid;

                          // Revisar si ya administra otra hueca
                          final otherHueca = allHuecas.where((h) => h.ownerId == user.uid && h.id != hueca.id).firstOrNull;
                          final isCurrentOwner = user.uid == hueca.ownerId;

                          String subtitleText = '${user.email} (${user.role})';
                          Color subtitleColor = Colors.blueGrey.shade600;
                          if (isCurrentOwner) {
                            subtitleText = '${user.email} • Dueño actual de esta hueca';
                            subtitleColor = Colors.green.shade800;
                          } else if (otherHueca != null) {
                            subtitleText = '${user.email} • Dueño de "${otherHueca.name}" (Se transferirá)';
                            subtitleColor = Colors.orange.shade800;
                          }

                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            tileColor: isSelected ? const Color(0xFF0F172A).withValues(alpha: 0.08) : null,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF0F172A),
                              backgroundImage: user.profilePicUrl.isNotEmpty
                                  ? NetworkImage(user.profilePicUrl)
                                  : null,
                              child: user.profilePicUrl.isEmpty
                                  ? Text(user.name.isNotEmpty ? user.name[0] : 'U', style: const TextStyle(color: Colors.white))
                                  : null,
                            ),
                            title: Text(
                              user.name,
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: (isCurrentOwner || otherHueca != null) ? FontWeight.w600 : FontWeight.normal),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFF0F172A), size: 20)
                                : null,
                            onTap: () {
                              setDialogState(() {
                                selectedUid = user.uid;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade700)),
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
                      await ref.read(huecaRepositoryProvider).assignHuecaOwner(hueca.id, selectedUid);
                      ref.invalidate(allHuecasStreamProvider);
                      ref.invalidate(allUsersStreamProvider);
                      ref.invalidate(huecasProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(selectedUid.isNotEmpty
                                ? '✅ Dueño asignado exitosamente (1 hueca por cuenta)'
                                : '✅ Dueño desvinculado de la hueca'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al asignar: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar Asignación', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleDelete(Hueca hueca) async {
    await showDeleteHuecaConfirmationDialog(
      context: context,
      ref: ref,
      hueca: hueca,
    );
    ref.invalidate(allHuecasStreamProvider);
    ref.invalidate(huecasProvider);
  }

  @override
  Widget build(BuildContext context) {
    final huecasAsync = ref.watch(allHuecasStreamProvider);

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
                    hintText: 'Buscar por nombre, sector o plato...',
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
                      _buildFilterChip('Todas', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Activas', 'active'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pausadas', 'inactive'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sin Dueño', 'unassigned'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Listado de Huecas
          Expanded(
            child: huecasAsync.when(
              data: (huecasList) {
                // Filtrado
                final filtered = huecasList.where((h) {
                  // Filtro por texto
                  if (_searchQuery.isNotEmpty) {
                    final matchName = h.name.toLowerCase().contains(_searchQuery);
                    final matchSector = h.sector.toLowerCase().contains(_searchQuery);
                    final matchDish = (h.mainDish['name']?.toString() ?? '').toLowerCase().contains(_searchQuery);
                    if (!matchName && !matchSector && !matchDish) return false;
                  }

                  // Filtro por estado
                  if (_filterStatus == 'active' && !h.isActive) return false;
                  if (_filterStatus == 'inactive' && h.isActive) return false;
                  if (_filterStatus == 'unassigned' && h.ownerId.isNotEmpty) return false;

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_outlined, size: 54, color: Colors.blueGrey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No se encontraron huecas',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prueba cambiando los filtros o añade una nueva hueca.',
                          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final hueca = filtered[index];
                    return _buildHuecaCard(hueca);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              error: (err, _) => Center(
                child: Text('Error cargando huecas: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A), // Botón oscuro
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Colors.amber, fontWeight: FontWeight.bold),
        label: const Text('Nueva Hueca', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/admin/huecas/new'),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterStatus = value),
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFF0F172A) : Colors.transparent),
      ),
    );
  }

  Widget _buildHuecaCard(Hueca hueca) {
    final hasOwner = hueca.ownerId.isNotEmpty;
    final branchesCount = hueca.branches.isNotEmpty ? hueca.branches.length : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hueca.isActive ? const Color(0xFFE2E8F0) : Colors.redAccent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen de la hueca
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: const Color(0xFFF1F5F9),
                    child: hueca.images.isNotEmpty
                        ? Image.network(
                            hueca.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: Color(0xFF0F172A)),
                          )
                        : const Icon(Icons.restaurant, color: Color(0xFF0F172A), size: 30),
                  ),
                ),
                const SizedBox(width: 14),
                // Datos principales
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hueca.name,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Switch(
                            value: hueca.isActive,
                            activeColor: Colors.green.shade600,
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.grey.shade200,
                            onChanged: (val) => _toggleHuecaStatus(hueca, val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              hueca.sector,
                              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${hueca.rating} (${hueca.reviewCount})',
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasOwner ? Colors.blue.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hasOwner ? 'Dueño Asignado' : 'Sin Dueño',
                              style: TextStyle(
                                color: hasOwner ? Colors.blue.shade700 : Colors.orange.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$branchesCount sucursal${branchesCount > 1 ? 'es' : ''}',
                            style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 18),
            // Barra de acciones diferenciadas
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0FDFA),
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF99F6E4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.store_outlined, size: 15, color: Color(0xFF0F766E)),
                    label: Text('Locales ($branchesCount)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    onPressed: () => context.push('/admin/huecas/branches', extra: hueca),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF1D4ED8),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.person_add_alt_1, size: 15, color: Color(0xFF1D4ED8)),
                    label: const Text('Dueño', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    onPressed: () => _showAssignOwnerDialog(hueca),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    onPressed: () => context.push('/admin/huecas/edit', extra: hueca),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                    label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    onPressed: () => _handleDelete(hueca),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
