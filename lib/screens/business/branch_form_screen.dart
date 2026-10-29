import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/screens/business/location_picker_screen.dart';
import 'package:hue_quito/services/geocoding_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BranchFormScreen extends ConsumerStatefulWidget {
  final Hueca hueca;
  final HuecaBranch? existingBranch;
  final bool isOwner;

  const BranchFormScreen({
    super.key,
    required this.hueca,
    this.existingBranch,
    required this.isOwner,
  });

  @override
  ConsumerState<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends ConsumerState<BranchFormScreen> {
  final List<String> _sectors = [
    'Centro Histórico',
    'La Mariscal',
    'Floresta',
    'Norte',
    'Sur',
    'Cumbayá',
    'Tumbaco',
    'Valle de los Chillos',
    'Calderón',
    'Conocoto',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  late String _selectedSector;
  late GeoPoint _selectedLocation;
  bool _isSaving = false;

  bool get _isEditing => widget.existingBranch != null;

  @override
  void initState() {
    super.initState();
    final branch = widget.existingBranch;
    _nameCtrl = TextEditingController(text: branch?.name ?? '');
    _addressCtrl = TextEditingController(text: branch?.address ?? '');
    _phoneCtrl = TextEditingController(text: branch?.phone ?? '');
    _emailCtrl = TextEditingController(text: branch?.managerEmail ?? '');

    _selectedSector = (branch != null && _sectors.contains(branch.sector))
        ? branch.sector
        : _sectors[0];

    _selectedLocation = branch?.location ?? const GeoPoint(-0.1807, -78.4678); // Quito default
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: LatLng(_selectedLocation.latitude, _selectedLocation.longitude),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = GeoPoint(result.location.latitude, result.location.longitude);
        if (result.address.isNotEmpty) {
          _addressCtrl.text = result.address;
        }
        if (result.sector != null && _sectors.contains(result.sector)) {
          _selectedSector = result.sector!;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dirección actualizada: ${result.address}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del local (ej. Sucursal Sur)')),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la dirección exacta del local')),
      );
      return;
    }

    final String oldEmail = widget.existingBranch?.managerEmail?.trim().toLowerCase() ?? '';
    final bool isAssigningNewEmail = email.isNotEmpty && email != oldEmail;

    // Si se asigna un nuevo encargado, mostrar confirmación clara de envío de invitación
    if (widget.isOwner && isAssigningNewEmail) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Confirmar Invitación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se enviará un correo a $email para que confirme la creación de su cuenta y defina su contraseña como encargado de "$name".',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        oldEmail.isNotEmpty
                            ? 'El encargado anterior ($oldEmail) perderá de inmediato el acceso a este local.'
                            : 'El encargado tendrá acceso exclusivo para gestionar este local.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Confirmar y Enviar'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    setState(() => _isSaving = true);
    String? emailErrorMsg;

    try {
      List<HuecaBranch> currentBranches = List.from(widget.hueca.allBranches);
      String savedBranchId = widget.existingBranch?.id ?? '';

      if (_isEditing) {
        final index = currentBranches.indexWhere((b) => b.id == widget.existingBranch!.id);
        if (index != -1) {
          currentBranches[index] = HuecaBranch(
            id: widget.existingBranch!.id,
            name: name,
            address: address,
            sector: _selectedSector,
            location: _selectedLocation,
            phone: phone,
            schedule: widget.existingBranch!.schedule,
            managerEmail: email.isEmpty ? null : email,
            // Conservar el cromo secreto de la sucursal al editarla
            secretSticker: widget.existingBranch!.secretSticker,
          );
        }
      } else {
        final newId = 'branch_${DateTime.now().millisecondsSinceEpoch}';
        savedBranchId = newId;
        currentBranches.add(
          HuecaBranch(
            id: newId,
            name: name,
            address: address,
            sector: _selectedSector,
            location: _selectedLocation,
            phone: phone,
            schedule: widget.hueca.schedule,
            managerEmail: email.isEmpty ? null : email,
          ),
        );
      }

      final branchesData = currentBranches.map((b) => b.toMap()).toList();

      if (Firebase.apps.isNotEmpty) {
        final docRef = FirebaseFirestore.instance.collection('huecas').doc(widget.hueca.id);

        await docRef.update({
          'branches': branchesData,
          'address': currentBranches.first.address,
          'sector': currentBranches.first.sector,
          'phone': currentBranches.first.phone,
          'location': currentBranches.first.location,
        });

        // 1. Si el correo cambió o fue eliminado, anular la invitación del encargado anterior.
        // Su rol vuelve a 'user' automáticamente en su próximo inicio de sesión
        // (las reglas de seguridad no permiten que un negocio edite perfiles ajenos).
        if (oldEmail.isNotEmpty && oldEmail != email) {
          try {
            await FirebaseFirestore.instance.collection('branch_invitations').doc(oldEmail).delete();
          } catch (_) {}
        }

        // 2. Si se asignó un nuevo encargado: crear cuenta en Auth si no existe, enviar correo y registrar invitación
        if (isAssigningNewEmail) {
          try {
            // Intentar crear la cuenta en Firebase Auth con una app secundaria temporal si aún no existe
            final tempAppName = 'SecondaryAuth_${DateTime.now().millisecondsSinceEpoch}';
            FirebaseApp? tempApp;
            try {
              tempApp = await Firebase.initializeApp(
                name: tempAppName,
                options: Firebase.app().options,
              );
              final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
              final tempPass = 'HueQuito_${DateTime.now().millisecondsSinceEpoch}!';
              await tempAuth.createUserWithEmailAndPassword(
                email: email,
                password: tempPass,
              );
              debugPrint('Usuario creado exitosamente en Auth para encargado: $email');
            } catch (createErr) {
              debugPrint('El usuario ya existía en Auth o detalle: $createErr');
            } finally {
              if (tempApp != null) {
                await tempApp.delete();
              }
            }

            // Configurar idioma español y enviar correo de restablecimiento / definición de contraseña de Firebase
            await FirebaseAuth.instance.setLanguageCode('es');
            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
            debugPrint('Correo de restablecimiento enviado a $email');
          } catch (e) {
            debugPrint('Error enviando correo de restablecimiento: $e');
            emailErrorMsg = e.toString();
          }

          try {
            // El encargado obtiene el rol 'business' al iniciar sesión, validado con esta invitación
            await FirebaseFirestore.instance.collection('branch_invitations').doc(email).set({
              'email': email,
              'huecaId': widget.hueca.id,
              'huecaName': widget.hueca.name,
              'branchId': savedBranchId,
              'branchName': name,
              'status': 'invited',
              'invitedAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('Error actualizando Firestore de invitación: $e');
          }
        }
      }

      ref.invalidate(allHuecasStreamProvider);
      ref.invalidate(huecasProvider);
      ref.invalidate(myHuecaProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        String message = _isEditing ? 'Local actualizado con éxito' : '¡Nuevo local agregado!';
        if (isAssigningNewEmail) {
          if (emailErrorMsg == null) {
            message = 'Invitación enviada a $email. Revisa la bandeja de entrada o la carpeta de Spam.';
          } else {
            message = 'Local guardado. Nota sobre correo: $emailErrorMsg';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: emailErrorMsg == null ? Colors.green : Colors.orange[850],
            duration: const Duration(seconds: 6),
          ),
        );
        Navigator.pop(context); // Go back to branches list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isAdmin = currentUser?.role == 'admin';

    return Scaffold(
      backgroundColor: isAdmin ? const Color(0xFFF8FAFC) : null,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Local' : 'Nuevo Local',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: isAdmin ? const Color(0xFF0F172A) : Colors.transparent,
        elevation: 0,
        foregroundColor: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface,
        iconTheme: IconThemeData(color: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isAdmin ? Colors.white : Theme.of(context).colorScheme.onSurface),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Hint
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.store, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'Modifica los datos de este local y su ubicación en el mapa.'
                          : 'Completa la información para agregar un nuevo punto de atención.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nombre
            const Text('Nombre del Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'Ej. Sucursal Sur / Local Cumbayá',
                prefixIcon: const Icon(Icons.badge_outlined),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Sector
            const Text('Sector en Quito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedSector,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.explore_outlined),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSector = val);
              },
            ),
            const SizedBox(height: 20),

            // Dirección Escrita
            const Text('Dirección Escrita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                hintText: 'Ej. Av. Rodrigo de Chávez y 5 de Junio',
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN INTERACTIVA DE MAPA
            const Text('Punto en el Mapa (GPS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.pin_drop, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ubicación exacta fijada',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text(
                        'Abrir Mapa para Mover el Pin',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openMapPicker,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Teléfono
            const Text('Teléfono de Contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Ej. 0991234567 o 022345678',
                prefixIcon: const Icon(Icons.phone_outlined),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Correo del Encargado (solo dueño)
            if (widget.isOwner) ...[
              const Divider(height: 32),
              const Text('Encargado de este Local (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              const Text(
                'Si asignas un correo, esa persona podrá iniciar sesión como negocio para administrar este local.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'empleado@gmail.com',
                  prefixIcon: const Icon(Icons.person_add_outlined),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Al guardar el local, se enviará automáticamente un correo a esta dirección para que configure su contraseña e ingrese a administrar esta sucursal.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),

            // BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'Guardando...' : (_isEditing ? 'Guardar Cambios' : 'Registrar Local'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdmin ? const Color(0xFF0F172A) : AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSaving ? null : _save,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
