import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/screens/admin/admin_users_screen.dart';

Future<void> showDeleteUserConfirmationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required UserModel user,
  required UserBusinessAssignment assignment,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _DeleteUserDialogContent(
      user: user,
      assignment: assignment,
      ref: ref,
    ),
  );
}

class _DeleteUserDialogContent extends StatefulWidget {
  final UserModel user;
  final UserBusinessAssignment assignment;
  final WidgetRef ref;

  const _DeleteUserDialogContent({
    required this.user,
    required this.assignment,
    required this.ref,
  });

  @override
  State<_DeleteUserDialogContent> createState() => _DeleteUserDialogContentState();
}

class _DeleteUserDialogContentState extends State<_DeleteUserDialogContent> {
  final TextEditingController _confirmationController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _isSelfUser {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance.currentUser?.uid == widget.user.uid;
      }
    } catch (_) {}
    return false;
  }

  bool get _isConfirmationValid =>
      _confirmationController.text.trim().toUpperCase() == 'ELIMINAR';

  Future<void> _handleDelete() async {
    if (_isSelfUser || !_isConfirmationValid || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.ref
          .read(userRepositoryProvider)
          .deleteUser(widget.user.uid, email: widget.user.email);

      // Invalidar proveedores para refrescar listas inmediatamente
      widget.ref.invalidate(allUsersStreamProvider);
      widget.ref.invalidate(allHuecasStreamProvider);
      widget.ref.invalidate(huecasProvider);
      widget.ref.invalidate(myHuecaProvider);
      widget.ref.invalidate(currentUserProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Cerrar modal

        final huecaName = widget.assignment.hueca?.name;
        final message = huecaName != null
            ? 'Usuario "${widget.user.name}" eliminado. La hueca "$huecaName" continúa registrada y quedó libre sin administrador.'
            : 'Usuario "${widget.user.name}" eliminado exitosamente.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al eliminar usuario: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hueca = widget.assignment.hueca;
    final branch = widget.assignment.branch;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eliminar Cuenta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.red,
                  ),
                ),
                Text(
                  widget.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Correo del usuario
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.user.email.isNotEmpty ? widget.user.email : 'Sin correo registrado',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Protección de la Hueca (REGLA CRUCIAL)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.teal.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'La Hueca NO será eliminada',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hueca != null
                              ? 'La hueca "${hueca.name}" ${branch != null ? '(${branch.name})' : ''} permanecerá intacta en la plataforma con sus fotos, platos, sellos y reseñas. Solo quedará libre (sin administrador) para asignarla después.'
                              : 'Si este usuario tenía un negocio vinculado, la hueca continuará intacta y pasará a estado "Sin Administrador" para que puedas reasignarla.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade900,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_isSelfUser) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No puedes eliminar tu propia cuenta de administrador mientras tienes la sesión activa.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Efectos de esta acción:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              _buildBulletItem(Icons.person_off_outlined, 'Se borra permanentemente el perfil del usuario'),
              _buildBulletItem(Icons.link_off_outlined, 'Se desvincula de cualquier hueca o sucursal'),
              _buildBulletItem(Icons.lock_reset, 'Se revocan todos los accesos al panel de control'),

              const SizedBox(height: 16),
              Text(
                'Escribe "ELIMINAR" abajo para confirmar:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmationController,
                autofocus: false,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'ELIMINAR',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
          ),
        ),
        ElevatedButton(
          onPressed: (_isConfirmationValid && !_isSelfUser && !_isLoading)
              ? _handleDelete
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            disabledForegroundColor: Colors.grey[500],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Eliminar Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildBulletItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
