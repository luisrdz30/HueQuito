import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y Soporte Quiteño')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Preguntas Frecuentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 16),
          const ExpansionTile(title: Text('¿Cómo consigo más cromos?'), children: [Padding(padding: EdgeInsets.all(16), child: Text('Explorando tu sector y escaneando los códigos QR escondidos en las huecas.'))]),
          const ExpansionTile(title: Text('¿Cómo funciona el pasaporte?'), children: [Padding(padding: EdgeInsets.all(16), child: Text('Cada vez que visitas una hueca, puedes pedir un sello digital.'))]),
          const SizedBox(height: 32),
          const Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 16),
          const Text('Si tienes algún problema con la app, escríbenos a soporte@huequito.app', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
