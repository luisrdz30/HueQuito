import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ayuda y Soporte Quiteño')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text('Preguntas Frecuentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          SizedBox(height: 16),
          ExpansionTile(title: Text('¿Cómo consigo más cromos?'), children: [Padding(padding: EdgeInsets.all(16), child: Text('Explorando tu sector y escaneando los códigos QR escondidos en las huecas.'))]),
          ExpansionTile(title: Text('¿Cómo funciona el pasaporte?'), children: [Padding(padding: EdgeInsets.all(16), child: Text('Cada vez que visitas una hueca, puedes pedir un sello digital.'))]),
          SizedBox(height: 32),
          Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          SizedBox(height: 16),
          Text('Si tienes algún problema con la app, escríbenos a soporte@huequito.app', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
