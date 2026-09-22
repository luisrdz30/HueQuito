import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y Privacidad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Términos y Condiciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            const Text('Bienvenido a Hue-Quito. Al usar nuestra aplicación, aceptas compartir tu ubicación de manera anónima para sugerencias de restaurantes y funciones del pasaporte gastronómico.'),
            const SizedBox(height: 32),
            const Text('Política de Privacidad Patrimonial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            const Text('Nos tomamos muy en serio tu privacidad. Tus datos de preferencias gastronómicas no se comparten con terceros, salvo con las huecas participantes de forma anonimizada.'),
            const SizedBox(height: 100),
            Center(child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Aceptar y Volver')))
          ]
        )
      )
    );
  }
}
