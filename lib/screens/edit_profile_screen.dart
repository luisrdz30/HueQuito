import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/utils/auth_utils.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/auth_provider.dart' hide currentUserProvider;

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        _nameController.text = user.name;
        _emailController.text = user.email;
      }
    });
  }


  Future<void> _pickAndUploadImage() async {
    if (!AuthUtils.checkAuthAndPrompt(context)) return;
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';

    try {
      final file = await ImagePickerHelper.showImageSourceDialog(
        context: context,
        title: isEn ? 'Profile Photo' : 'Foto de Perfil',
        subtitle: isEn ? 'Choose how you would like to upload your profile photo' : 'Elige cómo prefieres subir tu foto de perfil',
        lang: lang,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final refStorage = FirebaseStorage.instance.ref().child('user_profiles').child('${user.uid}.jpg');
      
      await refStorage.putFile(file);
      final downloadUrl = await refStorage.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profilePicUrl': downloadUrl,
      });

      ref.invalidate(currentUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Profile photo updated' : 'Foto de perfil actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Error updating photo: $e' : 'Error al actualizar foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!AuthUtils.checkAuthAndPrompt(context)) return;
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
        });
        ref.invalidate(currentUserProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEn ? 'Profile updated successfully' : 'Perfil actualizado')),
          );
        }
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _resetPassword() async {
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Password reset email sent.' : 'Correo de recuperación enviado.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteAccount() async {
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEn ? 'Delete Account' : 'Eliminar cuenta'),
        content: Text(
          isEn
              ? 'Are you sure you want to permanently delete your account? This action cannot be undone and will delete all your progress.'
              : '¿Estás seguro de que deseas eliminar tu cuenta de forma permanente? Esta acción no se puede deshacer y borrará todo tu progreso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isEn ? 'Cancel' : 'Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: Text(isEn ? 'Delete' : 'Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      ref.invalidate(currentUserProvider);
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Error: $e. Please log in again and retry.' : 'Error: $e. Inicia sesión nuevamente e intenta de nuevo.')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider).value;
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Edit Profile' : 'Editar Perfil', style: TextStyle(color: AppTheme.primary)),
        iconTheme: IconThemeData(color: AppTheme.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _isLoading ? null : _pickAndUploadImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(userAsync?.profilePicUrl ?? 'https://ui-avatars.com/api/?name=Invitado&background=random'),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: isEn ? 'Name' : 'Nombre',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: isEn ? 'Email (Non-editable)' : 'Correo (No modificable)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(isEn ? 'Save Changes' : 'Guardar Cambios'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: AppTheme.primary),
              title: Text(isEn ? 'Reset Password' : 'Restablecer Contraseña'),
              onTap: _resetPassword,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(isEn ? 'Delete Account' : 'Eliminar Cuenta', style: const TextStyle(color: Colors.red)),
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}
