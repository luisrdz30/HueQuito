import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';

Future<void> showDeleteHuecaConfirmationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Hueca hueca,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _DeleteHuecaDialogContent(
      hueca: hueca,
      ref: ref,
    ),
  );
}

class _DeleteHuecaDialogContent extends StatefulWidget {
  final Hueca hueca;
  final WidgetRef ref;

  const _DeleteHuecaDialogContent({
    required this.hueca,
    required this.ref,
  });

  @override
  State<_DeleteHuecaDialogContent> createState() =>
      _DeleteHuecaDialogContentState();
}

class _DeleteHuecaDialogContentState extends State<_DeleteHuecaDialogContent> {
  final TextEditingController _confirmationController =
      TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _isConfirmationValid =>
      _confirmationController.text.trim().toUpperCase() == 'ELIMINAR';

  Future<void> _handleDelete() async {
    if (!_isConfirmationValid || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.ref
          .read(huecaRepositoryProvider)
          .deleteHueca(widget.hueca.id);

      // Invalidate all providers so the app reflects that the hueca no longer exists
      widget.ref.invalidate(huecasProvider);
      widget.ref.invalidate(myHuecaProvider);
      widget.ref.invalidate(currentUserProvider);
      widget.ref.invalidate(isOwnerProvider);
      widget.ref.invalidate(currentManagedBranchProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La hueca "${widget.hueca.name}" y toda su información fueron eliminadas permanentemente.',
            ),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 4),
          ),
        );

        // Redirect to consumer home
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al eliminar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
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
                  'Eliminar Hueca',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.red,
                  ),
                ),
                Text(
                  widget.hueca.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción es definitiva e irreversible. Se borrará toda la información del negocio en los servidores.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Se eliminará por completo:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildDeleteItem(Icons.storefront_outlined, 'Perfil, dirección, ubicación y horarios'),
            _buildDeleteItem(Icons.restaurant_menu_outlined, 'Menú completo y todos los platos'),
            _buildDeleteItem(Icons.hub_outlined, 'Todas las sucursales vinculadas'),
            _buildDeleteItem(Icons.qr_code_2_rounded, 'Tarjetas de fidelización, sellos y cromos'),
            _buildDeleteItem(Icons.campaign_outlined, 'Avisos y notificaciones de la hueca'),
            _buildDeleteItem(Icons.rate_review_outlined, 'Historial de sellos y todas las reseñas'),
            const SizedBox(height: 16),
            Text(
              'Para confirmar que estás seguro, escribe "ELIMINAR" abajo:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmationController,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ELIMINAR',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 8),
                    Text(
                      'Borrando toda la información de la hueca...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
            disabledForegroundColor: Colors.white54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: (_isConfirmationValid && !_isLoading) ? _handleDelete : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever, size: 18),
              SizedBox(width: 6),
              Text('Eliminar Todo'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
