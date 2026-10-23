import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/screens/hueca_request_screen.dart';

class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Quito Help & Support' : 'Ayuda y Soporte Quiteño'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: isEn ? 'Back' : 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner destacado: ¿Tienes una hueca?
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Own a food spot?\nJoin HueQuito!'
                            : '¿Tienes una hueca?\n¡Sé parte de HueQuito!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isEn
                      ? 'Apply with your traditional local spot, recipes, and signature dishes. Our team will review the details to activate your official business account on the platform.'
                      : 'Postula tu local tradicional con tu sazón y platos estrella. Nuestro equipo revisará los datos para habilitar tu cuenta oficial de negocio en la plataforma.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.assignment_outlined, size: 20),
                    label: Text(
                      isEn ? 'Fill Registration Form' : 'Llenar Formulario de Registro',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HuecaRequestScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            isEn ? 'Frequently Asked Questions' : 'Preguntas Frecuentes',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),

          ExpansionTile(
            title: Text(isEn ? 'How do I collect more stickers?' : '¿Cómo consigo más cromos?'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isEn
                      ? 'By exploring your sector and scanning the hidden QR codes placed inside the huecas.'
                      : 'Explorando tu sector y escaneando los códigos QR escondidos en las huecas.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(isEn ? 'How does the passport work?' : '¿Cómo funciona el pasaporte?'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isEn
                      ? 'Every time you visit a participating hueca and enjoy a meal, you can ask for a digital stamp on your card.'
                      : 'Cada vez que visitas una hueca participante, puedes pedir un sello digital en tu cartilla.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(isEn ? 'How do I register my own hueca or business?' : '¿Cómo registro mi propia hueca o negocio?'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'If you are the owner of a traditional food stall, eatery, or restaurant in Quito, you can apply by filling out the registration form with your business name, address, phone, specialty, and a photo.'
                          : 'Si eres dueño de un restaurante, local o carretilla de comida tradicional en Quito, puedes postularte llenando el formulario de registro con el nombre del local, dirección, teléfono, especialidad y foto.',
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_forward, color: AppTheme.primary),
                      label: Text(
                        isEn ? 'Go to registration form' : 'Ir al formulario de registro',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HuecaRequestScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          Text(
            isEn ? 'Contact' : 'Contacto',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text(
            isEn
                ? 'If you have any issues or questions with the app, write to us at soporte@huequito.app'
                : 'Si tienes algún problema con la app, escríbenos a soporte@huequito.app',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
