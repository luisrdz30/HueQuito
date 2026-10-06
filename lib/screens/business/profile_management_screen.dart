import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/auth_provider.dart' hide currentUserProvider;
import 'package:hue_quito/providers/data_provider.dart';

class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil del Local', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return Center(child: Text('No has iniciado sesión'));
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(user.profilePicUrl),
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Text(
                  user.name,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  user.email,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              SizedBox(height: 32),
              ListTile(
                leading: Icon(Icons.edit, color: AppTheme.primary),
                title: Text('Editar información de la Hueca'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppTheme.primary),
                title: Text('Galería de Fotos'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.language, color: AppTheme.primary),
                title: Text('Revisar traducciones (IA)'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                onTap: () {},
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
