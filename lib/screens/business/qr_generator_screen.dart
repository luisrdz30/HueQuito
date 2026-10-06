import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';

class BusinessQrScreen extends ConsumerWidget {
  const BusinessQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Código QR', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Text('Código QR de la Hueca'),
      ),
    );
  }
}
