import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';

class BusinessMenuScreen extends ConsumerWidget {
  const BusinessMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Menú', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.primary, size: 48),
            SizedBox(height: 16),
            Text('Aquí subiremos las fotos para la IA'),
          ],
        ),
      ),
    );
  }
}
